//
//  LogsListView.swift
//  BrewGuide
//
//  Logs tab root: displays list of brew logs.
//

import SwiftUI
import SwiftData

/// Root view for the Logs tab.
/// Displays all brew logs sorted by timestamp (most recent first).
struct LogsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BrewLog.timestamp, order: .reverse) private var logs: [BrewLog]
    
    var body: some View {
        List {
            if logs.isEmpty {
                ContentUnavailableView(
                    "No Brew Logs",
                    systemImage: "cup.and.saucer",
                    description: Text("Your brew history will appear here.")
                )
            } else {
                ForEach(logs) { log in
                    NavigationLink(value: LogsRoute.logDetail(id: log.id)) {
                        BrewLogRowView(log: log)
                    }
                }
            }
        }
        .navigationTitle("Logs")
    }
}

/// Row view for a single brew log entry.
struct BrewLogRowView: View {
    let log: BrewLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(log.recipeNameAtBrew)
                .font(.headline)
            
            HStack {
                Text(log.timestamp, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                
                Spacer()
                
                Text(String(repeating: "⭐️", count: log.rating))
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        LogsListView()
    }
    .modelContainer(PersistenceController.preview.container)
}
