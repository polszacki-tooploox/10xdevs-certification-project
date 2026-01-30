//
//  AuthUseCase.swift
//  BrewGuide
//
//  Authentication use case using Sign in with Apple.
//

import Foundation
import AuthenticationServices
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "AuthUseCase")

/// Authentication use case for Sign in with Apple.
@MainActor
final class AuthUseCase: NSObject, AuthUseCaseProtocol {
    private let sessionStore: AuthSessionStoreProtocol
    private var currentNonce: String?
    private var authContinuation: CheckedContinuation<Result<AuthSession, AuthError>, Never>?
    
    nonisolated init(sessionStore: AuthSessionStoreProtocol = AuthSessionStore.shared) {
        self.sessionStore = sessionStore
    }
    
    // MARK: - AuthUseCaseProtocol
    
    func signInWithApple() async -> Result<AuthSession, AuthError> {
        logger.info("Starting Sign in with Apple flow")
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        return await withCheckedContinuation { continuation in
            self.authContinuation = continuation
            authorizationController.performRequests()
        }
    }
    
    func signOut() async {
        logger.info("Signing out")
        sessionStore.clearSession()
    }
    
    func currentSession() -> AuthSession {
        if let userId = sessionStore.userId(), !userId.isEmpty {
            return AuthSession(userId: userId, isSignedIn: true)
        } else {
            return .signedOut
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthUseCase: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                logger.error("Invalid credential type received")
                authContinuation?.resume(returning: .failure(.failed(message: "Invalid credentials received.")))
                authContinuation = nil
                return
            }
            
            let userId = appleIDCredential.user
            logger.info("Sign in successful for user")
            
            sessionStore.setSession(userId: userId)
            
            let session = AuthSession(userId: userId, isSignedIn: true)
            authContinuation?.resume(returning: .success(session))
            authContinuation = nil
        }
    }
    
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            let authError = error as NSError
            
            if authError.code == ASAuthorizationError.canceled.rawValue {
                logger.info("Sign in was cancelled by user")
                authContinuation?.resume(returning: .failure(.cancelled))
            } else if authError.code == ASAuthorizationError.notHandled.rawValue {
                logger.warning("Sign in not handled")
                authContinuation?.resume(returning: .failure(.notAvailable))
            } else {
                logger.error("Sign in failed: \(error.localizedDescription)")
                authContinuation?.resume(returning: .failure(.failed(message: "Sign in failed. Please try again.")))
            }
            
            authContinuation = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthUseCase: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the first connected scene's window on main actor
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes
                .first { $0.activationState == .foregroundActive } as? UIWindowScene
            
            return scene?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
}
