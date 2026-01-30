//
//  LogsListView.swift
//  BrewGuide
//
//  Logs tab root: displays list of brew logs with delete confirmation.
//  Conforms to PRD US-021, US-022, US-023.
//

import SwiftUI
import SwiftData

/// Root view for the Logs tab.
/// Displays all brew logs sorted by timestamp (most recent first).
/// Supports navigation to detail and swipe-to-delete with confirmation.
struct LogsListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LogsListViewModel()
    
    var body: some View {
        LogsListScreen(
            logs: viewModel.logs,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            onTapLog: { id in
                // Navigation handled by NavigationLink in BrewLogRow
            },
            onRequestDelete: { id in
                viewModel.requestDelete(id: id)
            },
            onRetry: {
                Task {
                    await viewModel.reload(context: modelContext)
                }
            }
        )
        .task {
            await viewModel.load(context: modelContext)
        }
        .refreshable {
            await viewModel.reload(context: modelContext)
        }
        .confirmationDialog(
            "Delete this brew log?",
            isPresented: .init(
                get: { viewModel.pendingDelete != nil },
                set: { if !$0 { viewModel.cancelDelete() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmDelete(context: modelContext)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelDelete()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - LogsListScreen

/// Pure rendering component for the logs list.
/// Receives DTO list + UI state and emits user events.
struct LogsListScreen: View {
    let logs: [BrewLogSummaryDTO]
    let isLoading: Bool
    let errorMessage: String?
    let onTapLog: (UUID) -> Void
    let onRequestDelete: (UUID) -> Void
    let onRetry: () -> Void
    
    var body: some View {
        List {
            // Error banner (if present)
            if let errorMessage = errorMessage {
                ErrorBanner(message: errorMessage, onRetry: onRetry)
            }
            
            // Empty state
            if logs.isEmpty && !isLoading {
                ContentUnavailableView(
                    "No Brew Logs",
                    systemImage: "cup.and.saucer",
                    description: Text("Your brew history will appear here.")
                )
            } else {
                // Logs list
                ForEach(logs) { log in
                    BrewLogRow(log: log, onRequestDelete: onRequestDelete)
                }
            }
        }
        .navigationTitle("Logs")
        .overlay {
            if isLoading && logs.isEmpty {
                ProgressView()
            }
        }
    }
}

// MARK: - BrewLogRow

/// Row container providing navigation and swipe actions for a brew log.
struct BrewLogRow: View {
    let log: BrewLogSummaryDTO
    let onRequestDelete: (UUID) -> Void
    
    var body: some View {
        NavigationLink(value: LogsRoute.logDetail(id: log.id)) {
            BrewLogRowContent(log: log)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onRequestDelete(log.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - BrewLogRowContent

/// Visual content of a brew log row.
/// Kitchen-proof layout with large touch targets and Dynamic Type support.
struct BrewLogRowContent: View {
    let log: BrewLogSummaryDTO
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Recipe name (headline)
            Text(log.recipeNameAtBrew.isEmpty ? "(Unknown recipe)" : log.recipeNameAtBrew)
                .font(.headline)
            
            // Timestamp and rating row
            HStack(alignment: .center, spacing: 8) {
                // Timestamp
                Text(log.timestamp, format: .dateTime.month().day().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Taste tag pill (optional)
                if let tasteTag = log.tasteTag {
                    TasteTagPill(tasteTag: tasteTag)
                }
                
                Spacer()
                
                // Rating
                BrewLogRatingView(rating: log.rating)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ErrorBanner

/// Inline error banner with retry button.
private struct ErrorBanner: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.red)
                
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Retry", action: onRetry)
                .font(.caption)
                .buttonStyle(.bordered)
        }
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
        .listRowSeparator(.hidden)
    }
}

// MARK: - Preview

#Preview("With Logs") {
    NavigationStack {
        LogsListView()
    }
    .modelContainer(PersistenceController.preview.container)
    .environment(AppRootCoordinator())
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: BrewLog.self, Recipe.self, RecipeStep.self,
        configurations: config
    )
    
    return NavigationStack {
        LogsListView()
    }
    .modelContainer(container)
    .environment(AppRootCoordinator())
}

#Preview("LogsListScreen - With Logs") {
    let sampleLogs = [
        BrewLogSummaryDTO(
            id: UUID(),
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "V60 Starter",
            rating: 4,
            tasteTag: .tooSour,
            recipeId: UUID()
        ),
        BrewLogSummaryDTO(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-86400),
            method: .v60,
            recipeNameAtBrew: "Ethiopian Light Roast",
            rating: 5,
            tasteTag: nil,
            recipeId: UUID()
        ),
        BrewLogSummaryDTO(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-172800),
            method: .v60,
            recipeNameAtBrew: "Custom Recipe (Deleted)",
            rating: 3,
            tasteTag: .tooBitter,
            recipeId: nil
        )
    ]
    
    return NavigationStack {
        LogsListScreen(
            logs: sampleLogs,
            isLoading: false,
            errorMessage: nil,
            onTapLog: { _ in },
            onRequestDelete: { _ in },
            onRetry: {}
        )
    }
}

#Preview("LogsListScreen - Empty") {
    NavigationStack {
        LogsListScreen(
            logs: [],
            isLoading: false,
            errorMessage: nil,
            onTapLog: { _ in },
            onRequestDelete: { _ in },
            onRetry: {}
        )
    }
}

#Preview("LogsListScreen - Loading") {
    NavigationStack {
        LogsListScreen(
            logs: [],
            isLoading: true,
            errorMessage: nil,
            onTapLog: { _ in },
            onRequestDelete: { _ in },
            onRetry: {}
        )
    }
}

#Preview("LogsListScreen - Error") {
    NavigationStack {
        LogsListScreen(
            logs: [],
            isLoading: false,
            errorMessage: "Failed to load brew logs. Please try again.",
            onTapLog: { _ in },
            onRequestDelete: { _ in },
            onRetry: {}
        )
    }
}

#Preview("BrewLogRowContent") {
    List {
        BrewLogRowContent(log: BrewLogSummaryDTO(
            id: UUID(),
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "V60 Starter",
            rating: 4,
            tasteTag: .tooSour,
            recipeId: UUID()
        ))
        
        BrewLogRowContent(log: BrewLogSummaryDTO(
            id: UUID(),
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "Ethiopian Light Roast",
            rating: 5,
            tasteTag: nil,
            recipeId: UUID()
        ))
        
        BrewLogRowContent(log: BrewLogSummaryDTO(
            id: UUID(),
            timestamp: Date(),
            method: .v60,
            recipeNameAtBrew: "",
            rating: 3,
            tasteTag: .tooWeak,
            recipeId: nil
        ))
    }
}
