//
//  DataDeletionRequestView.swift
//  BrewGuide
//
//  Data deletion request flow for GDPR compliance.
//

import SwiftUI
import SwiftData

/// View for requesting complete data deletion.
/// Provides clear information and confirmation before deletion.
struct DataDeletionRequestView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var showSuccess = false
    
    private let requiredText = "DELETE"
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                    
                    Text("This action cannot be undone")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    Text("All your data will be permanently deleted:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint("All custom recipes")
                        bulletPoint("All brew logs and history")
                        bulletPoint("All preferences and settings")
                    }
                    .padding(.leading)
                }
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("To confirm, type DELETE below:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Type DELETE", text: $confirmationText)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
            }
            
            Section {
                Button {
                    Task {
                        await performDeletion()
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isDeleting {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Delete All My Data")
                                .font(.headline)
                        }
                        Spacer()
                    }
                }
                .disabled(!isConfirmationValid || isDeleting)
                .foregroundStyle(.red)
                .listRowBackground(isConfirmationValid ? Color.red.opacity(0.1) : Color.clear)
            }
        }
        .navigationTitle("Delete All Data")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Data Deleted", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("All your data has been permanently deleted.")
        }
    }
    
    // MARK: - Computed Properties
    
    private var isConfirmationValid: Bool {
        confirmationText == requiredText
    }
    
    // MARK: - Methods
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
        .font(.subheadline)
    }
    
    private func performDeletion() async {
        isDeleting = true
        
        // Delete all recipes
        let recipeDescriptor = FetchDescriptor<Recipe>()
        if let recipes = try? modelContext.fetch(recipeDescriptor) {
            for recipe in recipes where recipe.origin == .custom {
                modelContext.delete(recipe)
            }
        }
        
        // Delete all brew logs
        let logDescriptor = FetchDescriptor<BrewLog>()
        if let logs = try? modelContext.fetch(logDescriptor) {
            for log in logs {
                modelContext.delete(log)
            }
        }
        
        // Save context
        try? modelContext.save()
        
        // Clear preferences
        PreferencesStore.shared.resetAll()
        
        // Show success and dismiss
        await MainActor.run {
            isDeleting = false
            showSuccess = true
        }
    }
}

#Preview {
    NavigationStack {
        DataDeletionRequestView()
    }
    .modelContainer(PersistenceController.preview.container)
}
