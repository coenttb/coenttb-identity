import Coenttb_Identity_Shared
import Dependencies
@preconcurrency import Fluent
import Foundation
import JWT
import RateLimiter
@preconcurrency import Vapor

extension Identity.Provider {
    public struct ApiKeyAuthenticator: AsyncBearerAuthenticator {

        let issuer: String

        public init(
            issuer: String = ._coenttbIssuer
        ) {
            self.issuer = issuer
        }

        public func authenticate(
            bearer: BearerAuthorization,
            for request: Request
        ) async throws {
            await withDependencies {
                $0.request = request
            } operation: {
                do {
                    guard let apiKey = try await Database.ApiKey.query(on: request.db)
                        .filter(\.$key == bearer.token)
                        .filter(\.$isActive == true)
                        .with(\.$identity)
                        .first()
                    else { return }

                    guard Date() < apiKey.validUntil else {
                        apiKey.isActive = false
                        try await apiKey.save(on: request.db)
                        return
                    }

                    @Dependency(RateLimiters.self) var rateLimiter

                    guard let keyId = apiKey.id?.uuidString else { return }
                    let rateLimit = await rateLimiter.apiKey.checkLimit(keyId)

                    guard rateLimit.isAllowed else {
                        if let nextAllowed = rateLimit.nextAllowedAttempt {
                            request.headers.replaceOrAdd(
                                name: "X-RateLimit-Reset",
                                value: "\(Int(nextAllowed.timeIntervalSince1970))"
                            )
                        }
                        request.headers.replaceOrAdd(
                            name: "X-RateLimit-Remaining",
                            value: "\(rateLimit.remainingAttempts)"
                        )
                        request.headers.replaceOrAdd(
                            name: "Retry-After",
                            value: "\(Int((rateLimit.nextAllowedAttempt?.timeIntervalSince(Date()) ?? 60)))"
                        )
                        throw Abort(.tooManyRequests)
                    }
                    
                    let identity = apiKey.identity

                    let response: Identity.Authentication.Response = try await .init(identity)

                    request.headers.bearerAuthorization = .init(token: response.accessToken.value)

                    apiKey.lastUsedAt = Date()
                    try await apiKey.save(on: request.db)

                    request.headers.replaceOrAdd(
                        name: "X-RateLimit-Limit",
                        value: "\(apiKey.rateLimit)"
                    )
                    request.headers.replaceOrAdd(
                        name: "X-RateLimit-Remaining",
                        value: "\(rateLimit.remainingAttempts)"
                    )

                    request.auth.login(identity)

                    await rateLimiter.apiKey.recordSuccess(keyId)
                } catch {

                }
            }
        }
    }
}
