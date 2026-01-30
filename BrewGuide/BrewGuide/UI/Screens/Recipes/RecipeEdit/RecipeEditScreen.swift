//
//  RecipeEditScreen.swift
//  BrewGuide
//
//  Pure renderer for RecipeEditViewState.
//

import SwiftUI

struct RecipeEditScreen: View {
    let state: RecipeEditViewState
    let canSave: Bool
    let onEvent: (RecipeEditEvent) -> Void
    
    var body: some View {
        Group {
            if state.isLoading && state.draft == nil {
                RecipeEditLoadingStateView()
            } else if let message = state.loadErrorMessage {
                RecipeEditErrorStateView(
                    message: message,
                    onRetry: { onEvent(.retryTapped) }
                )
            } else if let draft = state.draft {
                RecipeEditLoadedStateView(
                    draft: draft,
                    validation: state.validation,
                    isSaving: state.isSaving,
                    canSave: canSave,
                    isDirty: state.isDirty,
                    onEvent: onEvent
                )
            } else {
                RecipeEditErrorStateView(
                    message: "Recipe Not Found",
                    onRetry: { onEvent(.retryTapped) }
                )
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct RecipeEditLoadingStateView: View {
    var body: some View {
        ProgressView("Loading…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecipeEditErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t Load Recipe", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecipeEditLoadedStateView: View {
    let draft: RecipeEditDraft
    let validation: RecipeEditValidationState
    let isSaving: Bool
    let canSave: Bool
    let isDirty: Bool
    let onEvent: (RecipeEditEvent) -> Void
    
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !validation.isValid {
                    RecipeEditValidationSummaryBanner(
                        issueCount: validation.issueCount,
                        isVisible: !validation.isValid,
                        isWaterMismatch: validation.waterMismatch != nil,
                        onJumpToFirstIssue: {
                            if let anchor = validation.firstAnchor {
                                proxy.scrollTo(anchor, anchor: .top)
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                RecipeEditDefaultsSection(
                    draft: draft,
                    fieldErrors: validation.fieldErrors,
                    emphasizeYield: validation.waterMismatch != nil,
                    isDisabled: isSaving,
                    onEvent: onEvent
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                
                Section {
                    RecipeEditStepsEditorSection(
                        steps: draft.steps,
                        stepErrors: validation.stepErrorMap,
                        stepInlineErrors: validation.stepInlineErrorMap,
                        waterMismatchOffendingStepIds: validation.waterMismatch?.offendingStepIds ?? Set(),
                        isDisabled: isSaving,
                        onEvent: onEvent
                    )
                } header: {
                    RecipeEditStepsHeaderRow(
                        isDisabled: isSaving,
                        hasSteps: !draft.steps.isEmpty,
                        stepsError: validation.fieldErrors.steps,
                        onAddStep: { onEvent(.addStepTapped) }
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                RecipeEditActionBar(
                    isSaving: isSaving,
                    canSave: canSave,
                    isDirty: isDirty,
                    onCancel: { onEvent(.cancelTapped) },
                    onSave: { onEvent(.saveTapped) }
                )
            }
            .environment(\.editMode, $editMode)
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
    }
}

private struct RecipeEditStepsHeaderRow: View {
    let isDisabled: Bool
    let hasSteps: Bool
    let stepsError: String?
    let onAddStep: () -> Void
    
    @Environment(\.editMode) private var editMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Steps")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Step", systemImage: "plus", action: onAddStep)
                    .buttonStyle(.bordered)
                    .disabled(isDisabled)
                
                if hasSteps {
                    EditButton()
                        .disabled(isDisabled)
                }
            }
            
            if let stepsError {
                RecipeEditInlineErrorText(message: stepsError)
            } else if editMode?.wrappedValue == .active {
                Text("Drag the handles to reorder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

