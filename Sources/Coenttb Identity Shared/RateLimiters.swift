//
//  File.swift
//  coenttb-identity
//
//  Created by Coen ten Thije Boonkkamp on 07/02/2025.
//

import Coenttb_Server

public struct RateLimiters: Sendable {
    public let credentials = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: /*5*/ 1000),
            .hours(1, maxAttempts: /*20*/ 1000)
        ],
        metricsCallback: { key, result async in
            @Dependency(\.logger) var logger
            if !result.isAllowed {
                logger.warning("Rate limit exceeded for \(key)")
            }
        }
    )
    
    public let tokenAccess = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: /*60*/ 1000),
            .hours(1, maxAttempts: /*3000*/ 1000)
        ],
        metricsCallback: { key, result async in
            @Dependency(\.logger) var logger
            if !result.isAllowed {
                logger.warning("Token access rate limit exceeded for \(key)")
            }
        }
    )
    
    public let tokenRefresh = RateLimiter<String>(
        windows: [
            .minutes(1, maxAttempts: /*10*/ 1000),
            .hours(1, maxAttempts: /*100*/ 1000)
        ],
        metricsCallback: { key, result async in
            @Dependency(\.logger) var logger
            if !result.isAllowed {
                logger.warning("Token refresh rate limit exceeded for \(key)")
            }
        }
    )
}

extension RateLimiters: DependencyKey {
    public static let testValue: Self = testValue
    public static let liveValue: Self = .init()
}

extension RateLimiters {
    public var apiKey: RateLimiter<String> { tokenAccess }
    public var logout: RateLimiter<String> { tokenAccess }
    public var reauthorize: RateLimiter<String> { credentials }
    public var createRequest: RateLimiter<String> { credentials }
    public var createVerify: RateLimiter<String> { credentials }
    public var deleteRequest: RateLimiter<String> { tokenAccess }
    public var deleteConfirm: RateLimiter<String> { tokenAccess }
    public var deleteCancel: RateLimiter<String> { tokenAccess }
    public var emailChangeRequest: RateLimiter<String> { credentials }
    public var emailChangeConfirm: RateLimiter<String> { credentials }
    public var passwordResetRequest: RateLimiter<String> { tokenAccess }
    public var passwordResetConfirm: RateLimiter<String> { tokenAccess }
    public var passwordChangeRequest: RateLimiter<String> { credentials }
}
