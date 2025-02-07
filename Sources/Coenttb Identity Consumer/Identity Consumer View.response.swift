//
//  File.swift
//  coenttb-web
//
//  Created by Coen ten Thije Boonkkamp on 16/10/2024.
//

import Coenttb_Web
import Coenttb_Vapor
import Favicon
import Identity_Consumer

extension Identity.Consumer.View {
    public static func response(
        view: Identity.Consumer.View,
        currentUserName: () -> String?,
        logo: Identity.Consumer.View.Logo,
        hreflang:  @escaping (Identity.Consumer.View, Language) -> URL,
        primaryColor: HTMLColor,
        accentColor: HTMLColor,
        favicons: Favicons,
        canonicalHref: URL?,
        createProtectedRedirect: URL,
        loginProtectedRedirect: URL,
        homeHref: URL,
        verificationSuccessRedirect: URL,
        passwordResetSuccessRedirect: URL,
        emailChangeReauthorizationSuccessRedirect: URL,
        confirmEmailChangeSuccessRedirect: URL,
        termsOfUse: URL,
        privacyStatement: URL
    ) async throws -> any AsyncResponseEncodable {
        @Dependency(Identity.Consumer.Route.Router.self) var router
        
        return try await Self.response(
            view: view,
            logo: logo,
            canonicalHref: canonicalHref,
            favicons: favicons,
            hreflang: hreflang,
            termsOfUse: termsOfUse,
            privacyStatement: privacyStatement,
            primaryColor: primaryColor,
            accentColor: accentColor,
            homeHref: homeHref,
            createProtectedRedirect: createProtectedRedirect,
            loginProtectedRedirect: loginProtectedRedirect,
            loginHref: router.url(for: .view(.login)),
            accountCreateHref: router.url(for: .view(.create(.request))),
            createFormAction: router.url(for: .api(.create(.request(.init())))),
            verificationAction: router.url(for: .api(.create(.verify(.init())))),
            verificationSuccessRedirect: verificationSuccessRedirect,
            passwordResetHref: router.url(for: .view(.password(.reset(.request)))),
            loginFormAction: router.url(for: .api(.authenticate(.credentials(.init())))),
            passwordChangeRequestAction: router.url(for: .api(.password(.change(.request(change: .init()))))),
            passwordResetAction: router.url(for: .api(.password(.reset(.request(.init()))))),
            passwordResetConfirmAction: router.url(for: .api(.password(.reset(.confirm(.init()))))),
            passwordResetSuccessRedirect: passwordResetSuccessRedirect,
            currentUserName: currentUserName,
            emailChangeRequestAction: router.url(for: .api(.emailChange(.request(.init())))),
            emailChangeConfirmFormAction: router.url(for: .api(.emailChange(.confirm(.init())))),
            emailChangeReauthorizationSuccessRedirect: emailChangeReauthorizationSuccessRedirect,
            confirmEmailChangeSuccessRedirect: confirmEmailChangeSuccessRedirect
        )
    }
    
    private static func response(
        view: Identity.Consumer.View,
        logo: Identity.Consumer.View.Logo,
        canonicalHref: URL?,
        favicons: Favicons,
        hreflang:  @escaping (Identity.Consumer.View, Language) -> URL,
        termsOfUse: URL,
        privacyStatement: URL,
        primaryColor: HTMLColor,
        accentColor: HTMLColor,
        homeHref: URL,
        createProtectedRedirect: URL,
        loginProtectedRedirect: URL,
        loginHref: URL,
        accountCreateHref: URL,
        createFormAction: URL,
        verificationAction: URL,
        verificationSuccessRedirect: URL,
        passwordResetHref: URL,
        loginFormAction: URL,
        passwordChangeRequestAction: URL,
        passwordResetAction: URL,
        passwordResetConfirmAction: URL,
        passwordResetSuccessRedirect: URL,
        currentUserName: () -> String?,
        emailChangeRequestAction: URL,
        emailChangeConfirmFormAction: URL,
        emailChangeReauthorizationSuccessRedirect: URL,
        confirmEmailChangeSuccessRedirect: URL
    ) async throws -> any AsyncResponseEncodable {
        
        @Dependency(Identity.Consumer.Client.self) var client
        @Dependency(\.request) var request
        guard let request else { throw Abort.requestUnavailable }
        
        do {
            if let response = try Identity.Consumer.View.protect(
                view: view,
                with: JWT.Token.Access.self,
                createProtectedRedirect: createProtectedRedirect,
                loginProtectedRedirect: loginProtectedRedirect
            ) {
                return response
            }
        } catch {
            throw Abort(.unauthorized)
        }
        
        
        func accountDefaultContainer<Content: HTML>(
            @HTMLBuilder _ content: @escaping () -> Content
        ) -> Identity.Consumer.HTMLDocument<_HTMLTuple<HTMLInlineStyle<Identity.Consumer.View.Logo>, Content>> {
            
            let x = Identity.Consumer.HTMLDocument(
                view: view,
                title: { _ in "" },
                description: { _ in "" },
                primaryColor: primaryColor,
                accentColor: accentColor,
                favicons: { favicons },
                canonicalHref: canonicalHref,
                hreflang: hreflang,
                termsOfUse: termsOfUse,
                privacyStatement: privacyStatement,
                body: {
                    logo
                        .margin(top: .medium)
                    
                    content()
                }
            )
            
            return x
        }
        
        switch view {
        case let .create(create):
            switch create {
            case .request:
                return accountDefaultContainer {
                    Identity.Create.Request.View(
                        primaryColor: primaryColor,
                        loginHref: loginHref,
                        accountCreateHref: accountCreateHref,
                        createFormAction: createFormAction
                    )
                }
            case .verify:
                return accountDefaultContainer {
                    Identity.Create.Verify.View(
                        verificationAction: verificationAction,
                        redirectURL: verificationSuccessRedirect
                    )
                }
            }
        case .delete:
            try request.auth.require(JWT.Token.Access.self)
            fatalError()
            
        case .login:
            guard (try? request.auth.require(JWT.Token.Access.self)) == nil else {
                return request.redirect(to: homeHref.relativePath)
            }
            return accountDefaultContainer {
                Identity.Authentication.Credentials.View(
                    primaryColor: primaryColor,
                    passwordResetHref: passwordResetHref,
                    accountCreateHref: accountCreateHref,
                    loginFormAction: loginFormAction
                )
            }
            
        case .logout:
            try request.auth.require(JWT.Token.Access.self)
            return accountDefaultContainer {
                PageHeader(title: "Hope to see you soon!") {}
            }
            
        case let .password(password):
            switch password {
            case .reset(let reset):
                switch reset {
                case .request:
                    return accountDefaultContainer {
                        Identity.Consumer.View.Password.Reset.Request.View(
                            formActionURL: passwordResetAction,
                            homeHref: homeHref,
                            primaryColor: primaryColor
                        )
                    }
                    
                case .confirm(let confirm):
                    return accountDefaultContainer {
                        Identity.Consumer.View.Password.Reset.Confirm.View(
                            token: confirm.token,
                            passwordResetAction: passwordResetConfirmAction,
                            homeHref: homeHref,
                            redirect: passwordResetSuccessRedirect,
                            primaryColor: primaryColor
                        )
                    }
                }
                
            case .change(let change):
                switch change {
                case .request:
                    return accountDefaultContainer {
                        Identity.Consumer.View.Password.Change.Request.View(
                            formActionURL: passwordChangeRequestAction,
                            redirectOnSuccess: loginHref,
                            primaryColor: primaryColor
                        )
                    }
                }
            }
            
        case .emailChange(let emailChange):
            
            
            switch emailChange {
            case .request:
                try request.auth.require(JWT.Token.Access.self)
                
                guard
                    let currentUserName = currentUserName()
                else {
                    return request.redirect(to: loginHref.relativePath)
                }
                
                do {
                    try await client.emailChange.request(newEmail: nil)
                }
                catch let error as Identity.EmailChange.Request.Error {
                    switch error {
                    case .unauthorized:
                        return accountDefaultContainer {
                            Identity.Consumer.View.Reauthorization.View(
                                currentUserName: currentUserName,
                                primaryColor: primaryColor,
                                passwordResetHref: passwordResetHref,
                                confirmFormAction: emailChangeConfirmFormAction,
                                redirectOnSuccess: emailChangeReauthorizationSuccessRedirect
                            )
                        }
                    case .emailIsNil:
                        return accountDefaultContainer {
                            Identity.Consumer.View.EmailChange.Request.View(
                                formActionURL: emailChangeRequestAction,
                                homeHref: homeHref,
                                primaryColor: primaryColor
                            )
                        }
                    }
                }
                
                return accountDefaultContainer {
                    Identity.Consumer.View.EmailChange.Request.View(
                        formActionURL: emailChangeRequestAction,
                        homeHref: homeHref,
                        primaryColor: primaryColor
                    )
                }
                
            case .confirm(let confirm):
                
                try await client.emailChange.confirm(token: confirm.token)
                
                return accountDefaultContainer {
                    Identity.Consumer.View.EmailChange.Confirm.View(
                        redirect: confirmEmailChangeSuccessRedirect,
                        primaryColor: primaryColor
                    )
                }
            case .reauthorization:
                try request.auth.require(JWT.Token.Access.self)
                return accountDefaultContainer {
                    Identity.Consumer.View.Reauthorization.View(
                        currentUserName: "",
                        primaryColor: primaryColor,
                        passwordResetHref: passwordResetHref,
                        confirmFormAction: emailChangeConfirmFormAction,
                        redirectOnSuccess: emailChangeReauthorizationSuccessRedirect
                    )
                }
            }
            
        case .multifactorAuthentication(_):
            fatalError()
        }
        
    }
}

