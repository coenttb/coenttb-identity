//
//  File.swift
//  coenttb-identity
//
//  Created by Coen ten Thije Boonkkamp on 06/02/2025.
//


import Identity_Consumer
import Coenttb_Identity_Shared
import Coenttb_Vapor
import JWT

extension Identity.Consumer {
    public struct CredentialsAuthenticator: AsyncBasicAuthenticator {
        
        public init(){}
        
        public func authenticate(
            basic: BasicAuthorization,
            for request: Request
        ) async throws {
            @Dependency(Identity.Consumer.Client.self) var client
            let _ = try await client.authenticate.credentials(
                .init(
                    email: try .init(basic.username),
                    password: basic.password
                )
            )
        }
    }
}
