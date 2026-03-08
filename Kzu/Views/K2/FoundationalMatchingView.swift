// FoundationalMatchingView.swift
// Kzu — Early Ed (K-2) matching exercise

import SwiftUI

struct FoundationalMatchingView: View {
    let lesson: Lesson
    let onSubmit: (Bool) -> Void

    // The set of pairs from JSON
    private var pairs: [MatchingPair] {
        lesson.content.matchingPairs ?? []
    }

    // Shuffled display state
    @State private var leftItems: [String] = []
    @State private var rightItems: [String] = []

    // Interaction state
    @State private var selectedLeft: String? = nil
    @State private var selectedRight: String? = nil
    
    // Matched items
    @State private var matchedLeft: Set<String> = []
    @State private var matchedRight: Set<String> = []

    // Feedback
    @State private var showFeedback = false
    @State private var isCorrect: Bool? = nil

    var body: some View {
        VStack(spacing: 32) {
            // Instruction
            if let instruction = lesson.content.instruction {
                Text(instruction)
                    .font(KzuTypography.foundationalCaption)
                    .foregroundStyle(Color.kzuSoftNavy)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Main prompt
            GlassCard {
                VStack(spacing: 20) {
                    Text(lesson.content.prompt)
                        .font(KzuTypography.foundationalTitle)
                        .foregroundStyle(Color.kzuDeepNavy)
                        .multilineTextAlignment(.center)
                }
            }

            // Matching Columns
            HStack(spacing: 40) {
                // Left Column
                VStack(spacing: 16) {
                    ForEach(leftItems, id: \.self) { item in
                        MatchingItemButton(
                            text: item,
                            isSelected: selectedLeft == item,
                            isMatched: matchedLeft.contains(item)
                        ) {
                            if !matchedLeft.contains(item) {
                                selectedLeft = item
                                checkMatch()
                            }
                        }
                    }
                }

                // Right Column
                VStack(spacing: 16) {
                    ForEach(rightItems, id: \.self) { item in
                        MatchingItemButton(
                            text: item,
                            isSelected: selectedRight == item,
                            isMatched: matchedRight.contains(item)
                        ) {
                            if !matchedRight.contains(item) {
                                selectedRight = item
                                checkMatch()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Feedback
            if showFeedback, let correct = isCorrect {
                feedbackView(correct: correct)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            setupGame()
        }
    }

    private func setupGame() {
        leftItems = pairs.map { $0.left }.shuffled()
        rightItems = pairs.map { $0.right }.shuffled()
    }

    private func checkMatch() {
        guard let left = selectedLeft, let right = selectedRight else {
            return
        }

        // Did they tap a valid matching pair?
        let isMatch = pairs.contains { $0.left == left && $0.right == right }

        if isMatch {
            matchedLeft.insert(left)
            matchedRight.insert(right)
            
            // Clear temporary selection
            selectedLeft = nil
            selectedRight = nil
            
            // Play success feedback
            isCorrect = true
            showFeedback = true
            sensoryFeedback()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showFeedback = false
                // Check if all matched
                if matchedLeft.count == pairs.count {
                    onSubmit(true)
                }
            }
        } else {
            // Incorrect match
            isCorrect = false
            showFeedback = true
            sensoryFeedbackError()
            
            // Clear selections after a brief pause so they can try again
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showFeedback = false
                selectedLeft = nil
                selectedRight = nil
            }
        }
    }

    private func feedbackView(correct: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: correct ? "star.fill" : "arrow.uturn.backward")
                .font(.system(size: 24))
                .foregroundStyle(correct ? Color.kzuGold : Color.kzuWarning)

            Text(correct ? "A Match!" : "Try again!")
                .font(KzuTypography.foundationalCaption)
                .foregroundStyle(Color.kzuDeepNavy)
        }
        .padding()
        .background(
            Capsule()
                .fill(correct ? Color.kzuGold.opacity(0.15) : Color.kzuWarning.opacity(0.15))
        )
    }
    
    private func sensoryFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func sensoryFeedbackError() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - Matching Item Button

struct MatchingItemButton: View {
    let text: String
    let isSelected: Bool
    let isMatched: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(isMatched ? Color.clear : Color.kzuDeepNavy)
                .frame(maxWidth: .infinity, minHeight: 80)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isMatched ? Color.clear : (isSelected ? Color.kzuFlowBlue.opacity(0.15) : Color.white))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.kzuFlowBlue : Color.clear, lineWidth: 3)
                )
                .shadow(color: isMatched ? .clear : Color.black.opacity(0.05), radius: 6, y: 3)
                .scaleEffect(isSelected ? 0.95 : 1.0)
                .opacity(isMatched ? 0.0 : 1.0)
                .animation(.spring(), value: isSelected)
                .animation(.easeInOut(duration: 0.3), value: isMatched)
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
    }
}
