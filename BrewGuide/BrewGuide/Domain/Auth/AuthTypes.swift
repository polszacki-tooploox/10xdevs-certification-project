//
//  AuthTypes.swift
//  BrewGuide
//
//  Authentication domain types for Sign in with Apple.
//

import Foundation

/// Represents an authenticated session.
struct AuthSession: Equatable, Sendable {
    let userId: String
    let isSignedIn: Bool
    
    static var signedOut: AuthSession {
        AuthSession(userId: "", isSignedIn: false)
    }
}

/// Authentication errors.
enum AuthError: LocalizedError, Equatable {
    case cancelled
    case notAvailable
    case failed(message: String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign-in was cancelled."
        case .notAvailable:
            return "Sign in with Apple is not available."
        case .failed(let message):
            return message
        }
    }
}

/// Protocol for authentication operations.
protocol AuthUseCaseProtocol: Sendable {
    @MainActor func signInWithApple() async -> Result<AuthSession, AuthError>
    @MainActor func signOut() async
    @MainActor func currentSession() -> AuthSession
}
