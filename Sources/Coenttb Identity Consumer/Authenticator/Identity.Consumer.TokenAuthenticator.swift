//
//  File.swift
//  coenttb-identity
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//

import Coenttb_Identity_Shared
import Coenttb_Vapor
import Identity_Consumer
import JWT

extension Identity.Consumer {
    public struct TokenAuthenticator: AsyncMiddleware {
        public init() {}
        
        @Dependency(\.identity.consumer.client) var client
        
        public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
            return await withDependencies {
                $0.request = request
            } operation: {
                do {
                    guard let identityAuthenticationResponse = try await client.login(
                        request: request,
                        accessToken: request.cookies.accessToken?.string,
                        refreshToken: \.cookies.accessToken?.string
                    )
                    else { return try await next.respond(to: request) }

                    let response = try await next.respond(to: request)
                    
                    return response
                        .withTokens(for: identityAuthenticationResponse)
                    
                }
                catch {
                    let response = Response(status: .unauthorized)
                    response.expire(cookies: .identity)
                    return response
                }
            }
        }
    }
}


