//
//  RecipeEditView.swift
//  BrewGuide
//
//  Entry view for editing a custom recipe.
//

import SwiftUI
import SwiftData

struct RecipeEditView: View {
    let recipeId: UUID
    
    private let makeRepository: @MainActor (ModelContext) -> RecipeRepository
    private let makeUseCase: @MainActor (RecipeRepository) -> RecipeUseCaseProtocol
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: RecipeEditViewModel?
    @State private var isDiscardDialogPresented = false
    
    init(
        recipeId: UUID,
        makeRepository: @MainActor @escaping (ModelContext) -> RecipeRepository = { RecipeRepository(context: $0) },
        makeUseCase: @MainActor @escaping (RecipeRepository) -> RecipeUseCaseProtocol = { RecipeUseCase(repository: $0) }
    ) {
        self.recipeId = recipeId
        self.makeRepository = makeRepository
        self.makeUseCase = makeUseCase
    }
    
    var body: some View {
        Group {
            if let viewModel {
                RecipeEditScreen(
                    state: viewModel.state,
                    canSave: viewModel.canSave,
                    onEvent: { event in
                        handleEvent(event, viewModel: viewModel)
                    }
                )
                .navigationTitle("Edit Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarBackButtonHidden(true)
                .alert(
                    "Couldn’t Save",
                    isPresented: Binding(
                        get: { viewModel.state.saveErrorMessage != nil },
                        set: { isPresented in
                            if !isPresented {
                                viewModel.clearSaveError()
                            }
                        }
                    )
                ) {
                    Button("OK") {
                        viewModel.clearSaveError()
                    }
                } message: {
                    Text(viewModel.state.saveErrorMessage ?? "")
                }
                .confirmationDialog(
                    "Discard changes?",
                    isPresented: $isDiscardDialogPresented
                ) {
                    Button("Discard Changes", role: .destructive) {
                        dismiss()
                    }
                    Button("Keep Editing", role: .cancel) {}
                } message: {
                    Text("You have unsaved edits. Discard them and go back?")
                }
                .onChange(of: viewModel.didSaveSuccessfully) { _, didSave in
                    if didSave {
                        dismiss()
                    }
                }
            } else {
                ProgressView("Loading…")
            }
        }
        .task {
            if viewModel == nil {
                let repository = makeRepository(modelContext)
                let useCase = makeUseCase(repository)
                let newViewModel = RecipeEditViewModel(recipeId: recipeId, useCase: useCase)
                viewModel = newViewModel
                await newViewModel.load()
            }
        }
    }
    
    private func handleEvent(_ event: RecipeEditEvent, viewModel: RecipeEditViewModel) {
        switch event {
        case .cancelTapped:
            if viewModel.state.isDirty {
                isDiscardDialogPresented = true
            } else {
                dismiss()
            }
            
        case .saveTapped:
            Task { await viewModel.saveTapped() }
            
        default:
            viewModel.handle(event)
        }
    }
}

#Preview {
    NavigationStack {
        RecipeEditView(recipeId: UUID())
    }
    .modelContainer(PersistenceController.preview.container)
}

