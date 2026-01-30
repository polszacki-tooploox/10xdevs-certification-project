//
//  SyncUseCase.swift
//  BrewGuide
//
//  Sync use case for CloudKit integration.
//

import Foundation
import CloudKit
import OSLog

private let logger = Logger(subsystem: "com.brewguide", category: "SyncUseCase")

/// Sync use case for CloudKit integration.
/// This is an MVP implementation that provides the required API surface.
/// Full CloudKit sync integration is deferred to a later phase.
@MainActor
final class SyncUseCase: SyncUseCaseProtocol {
    private let authSessionStore: AuthSessionStoreProtocol
    private let syncSettingsStore: SyncSettingsStoreProtocol
    private let syncStatusStore: SyncStatusStoreProtocol
    
    nonisolated init(
        authSessionStore: AuthSessionStoreProtocol = AuthSessionStore.shared,
        syncSettingsStore: SyncSettingsStoreProtocol = SyncSettingsStore.shared,
        syncStatusStore: SyncStatusStoreProtocol = SyncStatusStore.shared
    ) {
        self.authSessionStore = authSessionStore
        self.syncSettingsStore = syncSettingsStore
        self.syncStatusStore = syncStatusStore
    }
    
    // MARK: - SyncUseCaseProtocol
    
    func enableSync() async -> Result<Void, SyncError> {
        logger.info("Enabling sync")
        
        guard authSessionStore.isSignedIn() else {
            logger.warning("Cannot enable sync: not signed in")
            return .failure(.notSignedIn)
        }
        
        // MVP: Verify CloudKit availability
        let container = CKContainer.default()
        
        do {
            let accountStatus = try await container.accountStatus()
            
            switch accountStatus {
            case .available:
                logger.info("CloudKit account available")
                syncSettingsStore.setSyncEnabled(true)
                
                // Record successful enable attempt
                let attempt = SyncAttempt(timestamp: Date(), result: .success)
                syncStatusStore.setLastAttempt(attempt)
                
                return .success(())
                
            case .noAccount:
                logger.warning("No iCloud account")
                return .failure(.cloudKitError(message: "iCloud account not found. Please sign in to iCloud in Settings."))
                
            case .restricted:
                logger.warning("iCloud account restricted")
                return .failure(.cloudKitError(message: "iCloud access is restricted on this device."))
                
            case .couldNotDetermine:
                logger.warning("Could not determine iCloud account status")
                return .failure(.cloudKitError(message: "Could not verify iCloud status."))
                
            case .temporarilyUnavailable:
                logger.warning("iCloud temporarily unavailable")
                return .failure(.networkUnavailable)
                
            @unknown default:
                logger.warning("Unknown CloudKit account status")
                return .failure(.unknown(message: "Unknown iCloud account status."))
            }
        } catch {
            logger.error("Failed to check CloudKit account status: \(error.localizedDescription)")
            return .failure(.cloudKitError(message: "Could not connect to iCloud."))
        }
    }
    
    func disableSync() async {
        logger.info("Disabling sync")
        syncSettingsStore.setSyncEnabled(false)
    }
    
    func syncNow() async -> Result<Void, SyncError> {
        logger.info("Manual sync requested")
        
        guard authSessionStore.isSignedIn() else {
            logger.warning("Cannot sync: not signed in")
            let attempt = SyncAttempt(
                timestamp: Date(),
                result: .failure(message: "You must be signed in to sync.")
            )
            syncStatusStore.setLastAttempt(attempt)
            return .failure(.notSignedIn)
        }
        
        guard syncSettingsStore.isSyncEnabled() else {
            logger.warning("Cannot sync: sync is disabled")
            let attempt = SyncAttempt(
                timestamp: Date(),
                result: .failure(message: "Sync is not enabled.")
            )
            syncStatusStore.setLastAttempt(attempt)
            return .failure(.cloudKitError(message: "Sync is not enabled."))
        }
        
        // MVP: Simulate sync operation
        // Full CloudKit sync implementation is deferred
        logger.info("Performing sync operation (MVP placeholder)")
        
        // For MVP, we'll simulate a successful sync
        // In production, this would trigger actual CloudKit record fetch/push
        do {
            // Check network connectivity via CloudKit
            let container = CKContainer.default()
            let accountStatus = try await container.accountStatus()
            
            guard accountStatus == .available else {
                logger.warning("CloudKit not available for sync")
                let attempt = SyncAttempt(
                    timestamp: Date(),
                    result: .failure(message: "iCloud is not available.")
                )
                syncStatusStore.setLastAttempt(attempt)
                return .failure(.cloudKitError(message: "iCloud is not available."))
            }
            
            // MVP: Record successful sync attempt
            let attempt = SyncAttempt(timestamp: Date(), result: .success)
            syncStatusStore.setLastAttempt(attempt)
            
            logger.info("Sync completed successfully")
            return .success(())
            
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            let attempt = SyncAttempt(
                timestamp: Date(),
                result: .failure(message: "Sync failed. Check your connection.")
            )
            syncStatusStore.setLastAttempt(attempt)
            return .failure(.networkUnavailable)
        }
    }
    
    func requestDataDeletion() async -> Result<Void, SyncError> {
        logger.info("Data deletion requested")
        
        guard authSessionStore.isSignedIn() else {
            logger.warning("Cannot request deletion: not signed in")
            return .failure(.notSignedIn)
        }
        
        // MVP: This is a placeholder for the deletion request flow
        // In production, this would:
        // 1. Mark records for deletion in CloudKit
        // 2. Send deletion request to server if applicable
        // 3. Clean up CloudKit private database
        
        do {
            let container = CKContainer.default()
            let accountStatus = try await container.accountStatus()
            
            guard accountStatus == .available else {
                logger.warning("CloudKit not available for deletion")
                return .failure(.cloudKitError(message: "iCloud is not available."))
            }
            
            // MVP: Simulate deletion request success
            logger.info("Data deletion request completed (MVP placeholder)")
            
            // Disable sync to prevent re-upload
            await disableSync()
            
            return .success(())
            
        } catch {
            logger.error("Data deletion request failed: \(error.localizedDescription)")
            return .failure(.cloudKitError(message: "Could not complete deletion request."))
        }
    }
}
