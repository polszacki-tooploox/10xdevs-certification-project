//
//  HoldToConfirmButton.swift
//  BrewGuide
//
//  A button that requires continuous press-and-hold to confirm destructive actions.
//

import SwiftUI

/// A button that requires holding for a specified duration to confirm an action.
/// Provides visual feedback during the hold and accessibility alternatives.
struct HoldToConfirmButton: View {
    let title: String
    let systemImage: String
    let holdDuration: Duration
    let role: ButtonRole?
    let onConfirmed: () -> Void
    
    @State private var isPressed = false
    @State private var holdProgress: Double = 0
    @State private var holdTask: Task<Void, Never>?
    
    @AccessibilityFocusState private var isVoiceOverFocused: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    
    init(
        title: String,
        systemImage: String,
        holdDuration: Duration = .seconds(1.5),
        role: ButtonRole? = .destructive,
        onConfirmed: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.holdDuration = holdDuration
        self.role = role
        self.onConfirmed = onConfirmed
    }
    
    var body: some View {
        if voiceOverEnabled {
            // VoiceOver mode: use standard button with confirmation dialog
            voiceOverButton
        } else {
            // Standard mode: hold-to-confirm interaction
            holdButton
        }
    }
    
    // MARK: - Hold Button (Standard Mode)
    
    private var holdButton: some View {
        Button(role: role) {
            // Button action is handled by long press gesture
        } label: {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                
                if isPressed {
                    Spacer()
                    CircularProgressView(progress: holdProgress)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.05)
                .onChanged { _ in
                    if !isPressed {
                        startHold()
                    }
                }
                .onEnded { _ in
                    // This won't trigger if we complete the hold
                    cancelHold()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // Keep tracking while pressed
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }
    
    // MARK: - VoiceOver Button (Accessibility Mode)
    
    @State private var showVoiceOverConfirmation = false
    
    private var voiceOverButton: some View {
        Button(role: role) {
            showVoiceOverConfirmation = true
        } label: {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityFocused($isVoiceOverFocused)
        .alert("Confirm \(title)", isPresented: $showVoiceOverConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(title, role: role) {
                onConfirmed()
            }
        } message: {
            Text("Are you sure you want to \(title.lowercased())?")
        }
    }
    
    // MARK: - Hold Logic
    
    private func startHold() {
        isPressed = true
        holdProgress = 0
        
        let durationSeconds = Double(holdDuration.components.seconds) + 
                             Double(holdDuration.components.attoseconds) / 1_000_000_000_000_000_000
        
        holdTask = Task { @MainActor in
            let startTime = Date()
            
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16)) // ~60 FPS
                
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / durationSeconds, 1.0)
                
                holdProgress = progress
                
                if progress >= 1.0 {
                    // Hold completed
                    completeHold()
                    break
                }
            }
        }
    }
    
    private func completeHold() {
        isPressed = false
        holdProgress = 0
        holdTask?.cancel()
        holdTask = nil
        
        onConfirmed()
    }
    
    private func cancelHold() {
        isPressed = false
        holdProgress = 0
        holdTask?.cancel()
        holdTask = nil
    }
}

// MARK: - Circular Progress View

private struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 0.016), value: progress)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 24) {
        HoldToConfirmButton(
            title: "Hold to Restart",
            systemImage: "arrow.counterclockwise"
        ) {
            print("Restart confirmed")
        }
        
        HoldToConfirmButton(
            title: "Hold to Delete",
            systemImage: "trash",
            holdDuration: .seconds(2)
        ) {
            print("Delete confirmed")
        }
    }
    .padding()
}
