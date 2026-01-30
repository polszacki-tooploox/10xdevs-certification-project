//
//  DataDeletionRequestViewState.swift
//  BrewGuide
//
//  View state models for DataDeletionRequestView.
//

import Foundation

// MARK: - Main State

/// View state for DataDeletionRequestView.
struct DataDeletionRequestViewState: Equatable {
    var isSignedIn: Bool
    var syncEnabled: Bool
    var confirmation: DataDeletionConfirmationState
    var isSubmitting: Bool
    var result: DataDeletionRequestResult?
}

// MARK: - Confirmation State

/// Confirmation state for data deletion.
enum DataDeletionConfirmationState: Equatable {
    case notConfirmed
    case confirmed
}

// MARK: - Request Result

/// Result of a data deletion request.
enum DataDeletionRequestResult: Equatable {
    case success(message: String)
    case failure(message: String)
}

// MARK: - Events

/// Events emitted from DataDeletionRequestScreen.
enum DataDeletionRequestEvent {
    case confirmChanged(Bool)
    case requestDeletionTapped
}
