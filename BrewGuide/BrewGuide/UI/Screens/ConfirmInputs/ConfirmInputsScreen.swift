//
//  ConfirmInputsScreen.swift
//  BrewGuide
//
//  Pure rendering component for the Confirm Inputs screen.
//

import SwiftUI

/// Pure SwiftUI rendering component with no persistence knowledge.
/// Renders state and forwards events.
struct ConfirmInputsScreen: View {
    let state: ConfirmInputsViewState
    let onEvent: (ConfirmInputsEvent) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SelectedRecipeHeader(
                    recipeName: state.recipeName,
                    methodName: state.method.displayName,
                    isEnabled: state.canEdit,
                    onChangeRecipe: { onEvent(.changeRecipeTapped) }
                )
                
                InputsCard(state: state, onEvent: onEvent)
                
                WarningsSection(warnings: state.warnings)
                
                // Add bottom padding for the action bar
                Spacer()
                    .frame(height: 120)
            }
            .padding(.top)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar(
                isStartEnabled: state.canStartBrew,
                isBusy: state.isStartingBrew,
                brewabilityMessage: state.isRecipeBrewable ? nil : state.brewabilityMessage,
                onStart: { onEvent(.startBrewTapped) },
                onReset: { onEvent(.resetTapped) }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let mockState = ConfirmInputsViewState(
        isLoading: false,
        recipeName: "Hoffman V60 Method",
        method: .v60,
        isRecipeBrewable: true,
        brewabilityMessage: nil,
        doseGrams: 15.0,
        targetYieldGrams: 250.0,
        waterTemperatureCelsius: 94.0,
        grindLabel: .medium,
        grindTactileDescriptor: "Like table salt",
        ratio: 16.7,
        warnings: [
            .ratioTooHigh(ratio: 16.7, maxRecommended: 16.0)
        ],
        isStartingBrew: false,
        canStartBrew: true,
        canEdit: true
    )
    
    return NavigationStack {
        ConfirmInputsScreen(
            state: mockState,
            onEvent: { event in
                print("Event: \(event)")
            }
        )
        .navigationTitle("Brew")
        .navigationBarTitleDisplayMode(.inline)
    }
}
