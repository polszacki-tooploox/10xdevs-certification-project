//
//  AuthUseCaseTests.swift
//  BrewGuideTests
//
//  Unit tests for AuthUseCase following Test Plan scenarios AU-001 to AU-005.
//  Tests session management, sign out, and session restoration.
//
//  Note: Sign in flow with Apple requires integration testing on device.
//  These tests focus on testable session management logic.
//

import Testing
import Foundation
@testable import BrewGuide

/// Test suite for AuthUseCase session management.
/// Covers session operations from Test Plan section 4.4.
@Suite("AuthUseCase Tests")
@MainActor
struct AuthUseCaseTests {
    
    // MARK: - Test Helpers
    
    func makeUseCase(sessionStore: FakeAuthSessionStore) -> AuthUseCase {
        AuthUseCase(sessionStore: sessionStore)
    }
    
    // MARK: - AU-001: Successful sign-in (session storage)
    
    @Test("AU-001: Successful sign-in stores session and sets isSignedIn to true")
    func testSuccessfulSignInStoresSession() {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        // Simulate successful auth by setting session directly
        // (Full Apple auth flow requires device/integration test)
        let testUserId = "test-user-123"
        sessionStore.setSession(userId: testUserId)
        
        // Act
        let session = useCase.currentSession()
        
        // Assert
        #expect(session.isSignedIn == true)
        #expect(session.userId == testUserId)
        #expect(sessionStore.setSessionCalls.count == 1)
    }
    
    // MARK: - AU-002: Cancelled sign-in (handled in delegate, not testable here)
    
    // Note: AU-002 (cancelled sign-in) is handled in ASAuthorizationControllerDelegate
    // which requires integration testing with Apple's auth system.
    // The behavior is: no error shown, remain signed out.
    
    // MARK: - AU-003: Failed sign-in (handled in delegate, not testable here)
    
    // Note: AU-003 (failed sign-in) is handled in ASAuthorizationControllerDelegate
    // which requires integration testing with Apple's auth system.
    
    // MARK: - AU-004: Sign out
    
    @Test("AU-004: Sign out clears session")
    func testSignOutClearsSession() async {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        // Start with signed-in state
        sessionStore.setSession(userId: "test-user-123")
        #expect(sessionStore.isSignedIn() == true)
        
        // Act
        await useCase.signOut()
        
        // Assert
        #expect(sessionStore.clearSessionCalls == 1)
        
        let session = useCase.currentSession()
        #expect(session.isSignedIn == false)
        #expect(session.userId.isEmpty)
    }
    
    // MARK: - AU-005: Session check on launch
    
    @Test("AU-005: Session restored from store on launch shows signed in")
    func testSessionRestorationWhenSignedIn() {
        // Arrange: User was previously signed in (session in store)
        let sessionStore = FakeAuthSessionStore()
        sessionStore.setUserIdDirect("existing-user-456")
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        // Act: Check current session (simulates app launch)
        let session = useCase.currentSession()
        
        // Assert
        #expect(session.isSignedIn == true)
        #expect(session.userId == "existing-user-456")
    }
    
    @Test("AU-005b: Session check on launch shows signed out when no session exists")
    func testSessionRestorationWhenNotSignedIn() {
        // Arrange: No previous session
        let sessionStore = FakeAuthSessionStore()
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        // Act: Check current session (simulates app launch)
        let session = useCase.currentSession()
        
        // Assert
        #expect(session.isSignedIn == false)
        #expect(session.userId.isEmpty)
        #expect(session == .signedOut)
    }
    
    // MARK: - Session state transitions
    
    @Test("Sign out after successful sign in transitions to signed out")
    func testSignOutAfterSignIn() async {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        sessionStore.setSession(userId: "user-789")
        #expect(useCase.currentSession().isSignedIn == true)
        
        // Act
        await useCase.signOut()
        
        // Assert
        let session = useCase.currentSession()
        #expect(session.isSignedIn == false)
    }
    
    @Test("Multiple sign outs are idempotent")
    func testMultipleSignOutsAreIdempotent() async {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        sessionStore.setSession(userId: "user-123")
        
        // Act
        await useCase.signOut()
        await useCase.signOut() // Second sign out
        
        // Assert: Should complete without error
        #expect(sessionStore.clearSessionCalls == 2)
        #expect(useCase.currentSession().isSignedIn == false)
    }
    
    // MARK: - Empty user ID handling
    
    @Test("Empty user ID is treated as signed out")
    func testEmptyUserIdTreatedAsSignedOut() {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        sessionStore.setUserIdDirect("") // Empty user ID
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        // Act
        let session = useCase.currentSession()
        
        // Assert
        #expect(session.isSignedIn == false)
    }
    
    // MARK: - Session store interaction verification
    
    @Test("currentSession queries session store")
    func testCurrentSessionQueriesStore() {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        sessionStore.setUserIdDirect("test-user")
        let useCase = makeUseCase(sessionStore: sessionStore)
        
        sessionStore.resetCallTracking()
        
        // Act
        _ = useCase.currentSession()
        
        // Assert: Should have queried userId
        #expect(sessionStore.userIdCalls == 1)
    }
    
    // MARK: - AuthSession equality
    
    @Test("AuthSession signed out constant matches empty session")
    func testSignedOutConstant() {
        // Arrange
        let emptySession = AuthSession(userId: "", isSignedIn: false)
        
        // Act & Assert
        #expect(emptySession == .signedOut)
    }
    
    // MARK: - Concurrent sign out
    
    @Test("Sign out is thread-safe on MainActor")
    func testSignOutThreadSafety() async {
        // Arrange
        let sessionStore = FakeAuthSessionStore()
        let useCase = makeUseCase(sessionStore: sessionStore)
        sessionStore.setSession(userId: "user-concurrent")
        
        // Act: Multiple concurrent sign outs (all on MainActor)
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { @MainActor in
                    await useCase.signOut()
                }
            }
        }
        
        // Assert: All complete successfully
        #expect(useCase.currentSession().isSignedIn == false)
    }
}
