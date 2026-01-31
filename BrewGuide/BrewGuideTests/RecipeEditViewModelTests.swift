//
//  RecipeEditViewModelTests.swift
//  BrewGuideTests
//

import Foundation
import Testing
@testable import BrewGuide

@MainActor
struct RecipeEditViewModelTests {
    
    @Test("Empty name produces .emptyName and anchors to name")
    func testEmptyNameValidation() async throws {
        let stepId = UUID()
        let useCase = FakeRecipeUseCase(
            detail: RecipeDetailDTO(
                recipe: RecipeSummaryDTO(
                    id: UUID(),
                    name: "Valid",
                    method: .v60,
                    isStarter: false,
                    origin: .custom,
                    isValid: true,
                    defaultDose: 15,
                    defaultTargetYield: 250,
                    defaultWaterTemperature: 94,
                    defaultGrindLabel: .medium
                ),
                grindTactileDescriptor: nil,
                steps: [
                    RecipeStepDTO(
                        stepId: stepId,
                        orderIndex: 0,
                        instructionText: "Bloom",
                        stepKind: .bloom,
                        durationSeconds: 30,
                        targetElapsedSeconds: 30,
                        timerDurationSeconds: nil,
                        waterAmountGrams: 50,
                        isCumulativeWaterTarget: true
                    )
                ]
            )
        )
        
        let viewModel = RecipeEditViewModel(recipeId: UUID(), useCase: useCase)
        await viewModel.load()
        
        viewModel.handle(.nameChanged(""))
        
        #expect(viewModel.state.validation.errors.contains(.emptyName))
        #expect(viewModel.state.validation.firstAnchor == .name)
        #expect(viewModel.state.validation.isValid == false)
    }
    
    @Test("Negative timer maps to the correct step in stepErrorMap")
    func testNegativeTimerMapsToStep() async throws {
        let stepId = UUID()
        let useCase = FakeRecipeUseCase(detail: makeDetail(stepId: stepId))
        let viewModel = RecipeEditViewModel(recipeId: UUID(), useCase: useCase)
        await viewModel.load()
        
        viewModel.handle(.stepTimerEnabledChanged(stepId: stepId, isEnabled: true))
        viewModel.handle(.stepTimerChanged(stepId: stepId, seconds: -1))
        
        let errorsForStep = viewModel.state.validation.stepErrorMap[stepId] ?? []
        #expect(errorsForStep.contains(.negativeTimer(stepIndex: 0)))
        #expect(viewModel.state.validation.firstAnchor == .step(id: stepId))
    }
    
    @Test("Water mismatch computes offending step IDs (max cumulative water)")
    func testWaterMismatchOffenders() async throws {
        let stepA = UUID()
        let stepB = UUID()
        
        let detail = RecipeDetailDTO(
            recipe: RecipeSummaryDTO(
                id: UUID(),
                name: "Water Mismatch",
                method: .v60,
                isStarter: false,
                origin: .custom,
                isValid: true,
                defaultDose: 15,
                defaultTargetYield: 250,
                defaultWaterTemperature: 94,
                defaultGrindLabel: .medium
            ),
            grindTactileDescriptor: nil,
            steps: [
                RecipeStepDTO(stepId: stepA, orderIndex: 0, instructionText: "Bloom", stepKind: .bloom, durationSeconds: 30, targetElapsedSeconds: 30, timerDurationSeconds: nil, waterAmountGrams: 50, isCumulativeWaterTarget: true),
                RecipeStepDTO(stepId: stepB, orderIndex: 1, instructionText: "Pour", stepKind: .pour, durationSeconds: 90, targetElapsedSeconds: 120, timerDurationSeconds: nil, waterAmountGrams: 200, isCumulativeWaterTarget: true)
            ]
        )
        
        let useCase = FakeRecipeUseCase(detail: detail)
        let viewModel = RecipeEditViewModel(recipeId: UUID(), useCase: useCase)
        await viewModel.load()
        
        // Yield is 250, max water is 200 => mismatch (diff 50)
        let mismatch = viewModel.state.validation.waterMismatch
        #expect(mismatch != nil)
        #expect(mismatch?.offendingStepIds == [stepB])
        #expect(viewModel.state.validation.errors.contains(where: {
            if case .waterTotalMismatch = $0 { return true }
            return false
        }))
    }
    
    @Test("Reorder updates contiguous orderIndex values")
    func testReorderNormalizesOrderIndex() async throws {
        let stepA = UUID()
        let stepB = UUID()
        let useCase = FakeRecipeUseCase(detail: makeDetailTwoSteps(stepA: stepA, stepB: stepB))
        let viewModel = RecipeEditViewModel(recipeId: UUID(), useCase: useCase)
        await viewModel.load()
        
        viewModel.handle(.moveSteps(from: IndexSet(integer: 0), to: 2))
        
        let steps = viewModel.state.draft?.steps ?? []
        #expect(steps.count == 2)
        #expect(steps[0].orderIndex == 0)
        #expect(steps[1].orderIndex == 1)
        #expect(steps[0].id == stepB)
        #expect(steps[1].id == stepA)
    }
    
    // MARK: - Test Helpers
    
    private func makeDetail(stepId: UUID) -> RecipeDetailDTO {
        RecipeDetailDTO(
            recipe: RecipeSummaryDTO(
                id: UUID(),
                name: "Test",
                method: .v60,
                isStarter: false,
                origin: .custom,
                isValid: true,
                defaultDose: 15,
                defaultTargetYield: 250,
                defaultWaterTemperature: 94,
                defaultGrindLabel: .medium
            ),
            grindTactileDescriptor: nil,
            steps: [
                RecipeStepDTO(
                    stepId: stepId,
                    orderIndex: 0,
                    instructionText: "Step",
                    stepKind: .pour,
                    durationSeconds: 60,
                    targetElapsedSeconds: 60,
                    timerDurationSeconds: nil,
                    waterAmountGrams: 250,
                    isCumulativeWaterTarget: true
                )
            ]
        )
    }
    
    private func makeDetailTwoSteps(stepA: UUID, stepB: UUID) -> RecipeDetailDTO {
        RecipeDetailDTO(
            recipe: RecipeSummaryDTO(
                id: UUID(),
                name: "Two Steps",
                method: .v60,
                isStarter: false,
                origin: .custom,
                isValid: true,
                defaultDose: 15,
                defaultTargetYield: 250,
                defaultWaterTemperature: 94,
                defaultGrindLabel: .medium
            ),
            grindTactileDescriptor: nil,
            steps: [
                RecipeStepDTO(stepId: stepA, orderIndex: 0, instructionText: "A", stepKind: .bloom, durationSeconds: 30, targetElapsedSeconds: 30, timerDurationSeconds: nil, waterAmountGrams: 50, isCumulativeWaterTarget: true),
                RecipeStepDTO(stepId: stepB, orderIndex: 1, instructionText: "B", stepKind: .pour, durationSeconds: 90, targetElapsedSeconds: 120, timerDurationSeconds: nil, waterAmountGrams: 250, isCumulativeWaterTarget: true)
            ]
        )
    }
}

@MainActor
private struct FakeRecipeUseCase: RecipeUseCaseProtocol, @unchecked Sendable {
    private let detail: RecipeDetailDTO
    
    init(detail: RecipeDetailDTO) {
        self.detail = detail
    }
    
    func fetchRecipeDetail(id: UUID) throws -> RecipeDetailDTO {
        detail
    }
    
    func updateCustomRecipe(_ request: UpdateRecipeRequest) throws -> Result<Void, RecipeValidationErrors> {
        .success(())
    }
}

