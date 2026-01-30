//
//  DataDeletionRequestViewModel.swift
//  BrewGuide
//
//  View model for DataDeletionRequestView.
//

import Foundation
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "DataDeletionRequestViewModel")

/// View model for the data deletion request screen.
/// Gates deletion behind sign-in and explicit confirmation.
@MainActor
@Observable
final class DataDeletionRequestViewModel {
    // MARK: - State
    
    var ui: DataDeletionRequestViewState
    
    // MARK: - Dependencies
    
    private let syncUseCase: SyncUseCaseProtocol
    private let syncSettingsStore: SyncSettingsStoreProtocol
    private let authSessionStore: AuthSessionStoreProtocol
    
    // MARK: - Initialization
    
    init(
        syncUseCase: SyncUseCaseProtocol = SyncUseCase(),
        syncSettingsStore: SyncSettingsStoreProtocol = SyncSettingsStore.shared,
        authSessionStore: AuthSessionStoreProtocol = AuthSessionStore.shared
    ) {
        self.syncUseCase = syncUseCase
        self.syncSettingsStore = syncSettingsStore
        self.authSessionStore = authSessionStore
        
        // Initialize state
        self.ui = DataDeletionRequestViewState(
            isSignedIn: authSessionStore.isSignedIn(),
            syncEnabled: syncSettingsStore.isSyncEnabled(),
            confirmation: .notConfirmed,
            isSubmitting: false,
            result: nil
        )
    }
    
    // MARK: - Public Methods
    
    func onAppear() async {
        logger.debug("Data deletion request view appeared")
        refreshFromStores()
    }
    
    func setConfirmed(_ confirmed: Bool) {
        logger.debug("Confirmation changed: \(confirmed)")
        ui.confirmation = confirmed ? .confirmed : .notConfirmed
    }
    
    func requestDeletion() async {
        guard ui.isSignedIn else {
            logger.warning("Cannot request deletion: not signed in")
            ui.result = .failure(message: "You must be signed in to request data deletion.")
            return
        }
        
        guard ui.confirmation == .confirmed else {
            logger.warning("Cannot request deletion: not confirmed")
            ui.result = .failure(message: "Please confirm to proceed.")
            return
        }
        
        guard !ui.isSubmitting else {
            logger.debug("Deletion request already in progress")
            return
        }
        
        logger.info("Requesting data deletion")
        ui.isSubmitting = true
        ui.result = nil
        
        let result = await syncUseCase.requestDataDeletion()
        
        ui.isSubmitting = false
        
        switch result {
        case .success:
            logger.info("Data deletion request successful")
            ui.result = .success(
                message: "Request sent. Sync has been turned off to prevent re-upload. Your local data remains on this device and you can continue using the app."
            )
            refreshFromStores()
            
        case .failure(let error):
            logger.error("Data deletion request failed: \(error.localizedDescription)")
            ui.result = .failure(message: error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func refreshFromStores() {
        ui.isSignedIn = authSessionStore.isSignedIn()
        ui.syncEnabled = syncSettingsStore.isSyncEnabled()
        
        logger.debug("State refreshed: signedIn=\(self.ui.isSignedIn), syncEnabled=\(self.ui.syncEnabled)")
    }
}
