//
//  SettingsViewModel.swift
//  BrewGuide
//
//  View model for SettingsView.
//  Orchestrates auth and sync operations.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "SettingsViewModel")

/// View model for the Settings screen.
/// Manages authentication, sync state, and user actions.
@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - State
    
    var ui: SettingsViewState
    
    // MARK: - Dependencies
    
    private let authUseCase: AuthUseCaseProtocol
    private let syncUseCase: SyncUseCaseProtocol
    private let syncSettingsStore: SyncSettingsStoreProtocol
    private let authSessionStore: AuthSessionStoreProtocol
    private let syncStatusStore: SyncStatusStoreProtocol
    
    // MARK: - Initialization
    
    init(
        authUseCase: AuthUseCaseProtocol = AuthUseCase(),
        syncUseCase: SyncUseCaseProtocol = SyncUseCase(),
        syncSettingsStore: SyncSettingsStoreProtocol = SyncSettingsStore.shared,
        authSessionStore: AuthSessionStoreProtocol = AuthSessionStore.shared,
        syncStatusStore: SyncStatusStoreProtocol = SyncStatusStore.shared
    ) {
        self.authUseCase = authUseCase
        self.syncUseCase = syncUseCase
        self.syncSettingsStore = syncSettingsStore
        self.authSessionStore = authSessionStore
        self.syncStatusStore = syncStatusStore
        
        // Initialize state
        self.ui = SettingsViewState(
            isSignedIn: authSessionStore.isSignedIn(),
            syncEnabled: syncSettingsStore.isSyncEnabled(),
            syncStatus: Self.mapSyncStatus(
                isSignedIn: authSessionStore.isSignedIn(),
                syncEnabled: syncSettingsStore.isSyncEnabled(),
                lastAttempt: syncStatusStore.lastAttempt()
            ),
            isPerformingAuth: false,
            isSyncInProgress: false,
            inlineMessage: nil
        )
    }
    
    // MARK: - Public Methods
    
    func onAppear() async {
        logger.debug("Settings view appeared, refreshing state")
        refreshFromStores()
    }
    
    func signIn() async {
        guard !ui.isPerformingAuth else {
            logger.debug("Sign-in already in progress")
            return
        }
        
        logger.info("Starting sign-in flow")
        ui.isPerformingAuth = true
        ui.inlineMessage = nil
        
        let result = await authUseCase.signInWithApple()
        
        ui.isPerformingAuth = false
        
        switch result {
        case .success:
            logger.info("Sign-in successful")
            refreshFromStores()
            
        case .failure(.cancelled):
            logger.info("Sign-in cancelled by user")
            // No error message for cancellation
            
        case .failure(let error):
            logger.error("Sign-in failed: \(error.localizedDescription)")
            ui.inlineMessage = InlineMessage(
                kind: .error,
                text: error.localizedDescription
            )
        }
    }
    
    func signOut() async {
        guard !ui.isPerformingAuth && !ui.isSyncInProgress else {
            logger.debug("Cannot sign out: operation in progress")
            return
        }
        
        logger.info("Signing out")
        ui.isPerformingAuth = true
        ui.inlineMessage = nil
        
        await authUseCase.signOut()
        
        // Disable sync when signing out
        if ui.syncEnabled {
            await syncUseCase.disableSync()
        }
        
        ui.isPerformingAuth = false
        refreshFromStores()
    }
    
    func setSyncEnabled(_ enabled: Bool) async {
        guard ui.isSignedIn else {
            logger.warning("Cannot change sync: not signed in")
            ui.inlineMessage = InlineMessage(
                kind: .warning,
                text: "You must sign in to enable sync."
            )
            return
        }
        
        guard !ui.isSyncInProgress else {
            logger.debug("Sync operation in progress")
            return
        }
        
        logger.info("Setting sync enabled: \(enabled)")
        ui.isSyncInProgress = true
        ui.inlineMessage = nil
        
        if enabled {
            let result = await syncUseCase.enableSync()
            
            switch result {
            case .success:
                logger.info("Sync enabled successfully")
                refreshFromStores()
                
                // Optionally trigger initial sync
                await retrySync()
                
            case .failure(let error):
                logger.error("Failed to enable sync: \(error.localizedDescription)")
                ui.inlineMessage = InlineMessage(
                    kind: .error,
                    text: error.localizedDescription
                )
            }
        } else {
            await syncUseCase.disableSync()
            logger.info("Sync disabled")
            refreshFromStores()
        }
        
        ui.isSyncInProgress = false
    }
    
    func retrySync() async {
        guard ui.isSignedIn else {
            logger.warning("Cannot retry sync: not signed in")
            ui.inlineMessage = InlineMessage(
                kind: .warning,
                text: "You must sign in to sync."
            )
            return
        }
        
        guard ui.syncEnabled else {
            logger.warning("Cannot retry sync: sync not enabled")
            ui.inlineMessage = InlineMessage(
                kind: .warning,
                text: "Enable sync to retry."
            )
            return
        }
        
        guard !ui.isSyncInProgress else {
            logger.debug("Sync already in progress")
            return
        }
        
        logger.info("Retrying sync")
        ui.isSyncInProgress = true
        ui.inlineMessage = nil
        
        let result = await syncUseCase.syncNow()
        
        ui.isSyncInProgress = false
        refreshFromStores()
        
        switch result {
        case .success:
            logger.info("Sync completed successfully")
            ui.inlineMessage = InlineMessage(
                kind: .info,
                text: "Sync completed successfully."
            )
            
        case .failure(let error):
            logger.error("Sync failed: \(error.localizedDescription)")
            ui.inlineMessage = InlineMessage(
                kind: .error,
                text: error.localizedDescription
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func refreshFromStores() {
        let isSignedIn = authSessionStore.isSignedIn()
        let syncEnabled = syncSettingsStore.isSyncEnabled()
        let lastAttempt = syncStatusStore.lastAttempt()
        
        ui.isSignedIn = isSignedIn
        ui.syncEnabled = syncEnabled
        ui.syncStatus = Self.mapSyncStatus(
            isSignedIn: isSignedIn,
            syncEnabled: syncEnabled,
            lastAttempt: lastAttempt
        )
        
        logger.debug("State refreshed: signedIn=\(isSignedIn), syncEnabled=\(syncEnabled)")
    }
    
    private static func mapSyncStatus(
        isSignedIn: Bool,
        syncEnabled: Bool,
        lastAttempt: SyncAttempt?
    ) -> SyncStatusDisplay {
        let mode: SyncModeDisplay = (isSignedIn && syncEnabled) ? .syncEnabled : .localOnly
        
        let attemptDisplay = lastAttempt.map { attempt in
            SyncAttemptDisplay(
                timestamp: attempt.timestamp,
                result: {
                    switch attempt.result {
                    case .success:
                        return .success
                    case .failure:
                        return .failure
                    }
                }()
            )
        }
        
        let failureMessage: String? = {
            guard case .failure(let message) = lastAttempt?.result else {
                return nil
            }
            return message
        }()
        
        return SyncStatusDisplay(
            mode: mode,
            lastAttempt: attemptDisplay,
            lastFailureMessage: failureMessage
        )
    }
}
