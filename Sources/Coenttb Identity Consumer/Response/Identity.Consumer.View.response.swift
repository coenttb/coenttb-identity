//
//  File.swift
//  coenttb-web
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import Coenttb_Vapor
import Coenttb_Web
import Favicon
import Identity_Consumer

extension Identity.Consumer.View {
    public static func response(
        view: Identity.Consumer.View
    ) async throws -> any AsyncResponseEncodable {
        
        @Dependency(\.identity.consumer.client) var client
        @Dependency(\.identity.consumer.router) var router
        @Dependency(\.identity.consumer.canonicalHref) var canonicalHref
        @Dependency(\.identity.consumer.currentUserName) var currentUserName
        
        @Dependency(\.identity.consumer.navigation.home) var homeHref
        
        @Dependency(\.identity.consumer.branding.primaryColor) var primaryColor
        @Dependency(\.identity.consumer.branding.accentColor) var accentColor
        @Dependency(\.identity.consumer.branding.favicons) var favicons
        @Dependency(\.identity.consumer.branding.logo) var logo
                
        @Dependency(\.identity.consumer.redirect.createVerificationSuccess) var createVerificationSuccessRedirect
        @Dependency(\.identity.consumer.redirect.createProtected) var createProtectedRedirect
        @Dependency(\.identity.consumer.redirect.loginSuccess) var loginSuccessRedirect
        @Dependency(\.identity.consumer.redirect.loginProtected) var loginProtectedRedirect
        @Dependency(\.identity.consumer.redirect.logoutSuccess) var logoutSuccessRedirect
        @Dependency(\.identity.consumer.redirect.passwordResetSuccess) var passwordResetSuccessRedirect
        @Dependency(\.identity.consumer.redirect.emailChangeReauthorizationSuccess) var emailChangeReauthorizationSuccessRedirect
        @Dependency(\.identity.consumer.redirect.emailChangeConfirmSuccess) var emailChangeConfirmSuccessRedirect
        
        do {
            do {
                try await Identity.Consumer.View.protect(
                    view: view,
                    with: JWT.Token.Access.self,
                    createProtectedRedirect: createProtectedRedirect(),
                    loginProtectedRedirect: loginProtectedRedirect()
                )
            }
            catch {
                @Dependency(\.request) var request
                guard let request else { throw Abort.requestUnavailable }
                
                switch view {
                case .create:
                    return request.redirect(to: createProtectedRedirect().relativePath)
                    
                case .authenticate(.credentials):
                    return request.redirect(to: loginProtectedRedirect().relativePath)
                    
                case .emailChange(.request):
                    return accountDefaultContainer {
                        Identity.Consumer.View.Reauthorize(
                            currentUserName: "currentUserName",
                            primaryColor: primaryColor,
                            passwordResetHref: router.url(for: .view(.password(.reset(.request)))),
                            confirmFormAction: router.url(for: .api(.reauthorize(.init()))),
                            redirectOnSuccess: emailChangeReauthorizationSuccessRedirect()
                        )
                    }
                    
                default: break
                }
            }
        } catch {
            throw Abort(.unauthorized)
        }
        
        func accountDefaultContainer<Content: HTML>(
            @HTMLBuilder _ content: @escaping () -> Content
        ) -> Identity.Consumer.HTMLDocument<_HTMLTuple<HTMLInlineStyle<Identity.Consumer.View.Logo>, Content>> {
            Identity.Consumer.HTMLDocument(
                view: view,
                title: { _ in "" },
                description: { _ in "" },
                body: {
                    logo
                        .margin(top: .medium)
                    
                    content()
                }
            )
        }
        
        switch view {
        case let .create(create):
            switch create {
            case .request:
                return accountDefaultContainer {
                    Identity.Consumer.View.Create.Request(
                        primaryColor: primaryColor,
                        loginHref: router.url(for: .view(.login)),
                        accountCreateHref: router.url(for: .view(.create(.request))),
                        createFormAction: router.url(for: .api(.create(.request(.init()))))
                    )
                }
            case .verify:
                return accountDefaultContainer {
                    Identity.Consumer.View.Create.Verify(
                        verificationAction: router.url(for: .api(.create(.verify(.init())))),
                        redirectURL: createVerificationSuccessRedirect()
                    )
                }
            }
        case .delete:
            fatalError()
            
        case .authenticate(let authenticate):
            switch authenticate {
            case .credentials:
                return accountDefaultContainer {
                    Identity.Consumer.View.Authenticate.Login(
                        primaryColor: primaryColor,
                        passwordResetHref: router.url(for: .view(.password(.reset(.request)))),
                        accountCreateHref: router.url(for: .view(.create(.request))),
                        loginFormAction: router.url(for: .api(.authenticate(.credentials(.init())))),
                        loginSuccessRedirect: loginSuccessRedirect()
                    )
                }
            }
            
        case .logout:
            try? await client.logout()
            
            let response = Response.success(true)
            
            response.expire(cookies: .identity)
            
            let html = accountDefaultContainer {
                PageHeader(title: "Hope to see you soon!") {}
            }
            
            response.headers.contentType = .html
            
            let bytes: ContiguousArray<UInt8> = html.render()
            
            response.body = .init(data: Data(bytes))
            
            return response
            
        case let .password(password):
            switch password {
            case .reset(let reset):
                switch reset {
                case .request:
                    return accountDefaultContainer {
                        Identity.Consumer.View.Password.Reset.Request(
                            formActionURL: router.url(for: .api(.password(.reset(.request(.init()))))),
                            homeHref: homeHref(),
                            primaryColor: primaryColor
                        )
                    }
                    
                case .confirm(let confirm):
                    return accountDefaultContainer {
                        Identity.Consumer.View.Password.Reset.Confirm(
                            token: confirm.token,
                            passwordResetAction: router.url(for: .api(.password(.reset(.confirm(.init()))))),
                            homeHref: homeHref(),
                            redirect: passwordResetSuccessRedirect(),
                            primaryColor: primaryColor
                        )
                    }
                }
                
            case .change(let change):
                switch change {
                case .request:
                    return accountDefaultContainer {
                        Identity.Consumer.View.Password.Change.Request(
                            formActionURL: router.url(for: .api(.password(.change(.request(change: .init()))))),
                            redirectOnSuccess: router.url(for: .view(.login)),
                            primaryColor: primaryColor
                        )
                    }
                }
            }
            
        case .emailChange(let emailChange):
            switch emailChange {
            case .request:
                return accountDefaultContainer {
                    Identity.Consumer.View.EmailChange.Request(
                        formActionURL: router.url(for: .api(.emailChange(.request(.init())))),
                        homeHref: homeHref(),
                        primaryColor: primaryColor
                    )
                }
                
            case .confirm(let confirm):
                _ = try await client.emailChange.confirm(token: confirm.token)
                
                return accountDefaultContainer {
                    Identity.Consumer.View.EmailChange.Confirm(
                        redirect: emailChangeConfirmSuccessRedirect(),
                        primaryColor: primaryColor
                    )
                }
                
            case .reauthorization:
                return accountDefaultContainer {
                    Identity.Consumer.View.Reauthorize(
                        currentUserName: currentUserName() ?? "",
                        primaryColor: primaryColor,
                        passwordResetHref: router.url(for: .view(.password(.reset(.request)))),
                        confirmFormAction: router.url(for: .api(.reauthorize(.init()))),
                        redirectOnSuccess: homeHref()
                    )
                }
            }
        }
    }
}
