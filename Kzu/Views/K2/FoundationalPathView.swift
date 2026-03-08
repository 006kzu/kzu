// FoundationalPathView.swift
// Kzu — K-2 "Digital Montessori" tactile lesson views

import SwiftUI

// MARK: - Foundational Path View

/// Large, tactile UI elements for K-2 students.
/// "Digital Montessori" aesthetic: wooden textures, soft shadows, haptic feedback.
struct FoundationalPathView: View {
    let lesson: Lesson
    let onAnswer: (Int) -> Bool

    @State private var selectedIndex: Int? = nil
    @State private var isCorrect: Bool? = nil
    @State private var showFeedback = false
    @State private var bounceOption: Int? = nil

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
                    // Visual media for lesson
                    if let mediaAsset = lesson.content.mediaAsset ?? lesson.content.targetObject {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.kzuFlowBlue.opacity(0.1),
                                            Color.kzuGold.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(minHeight: 120)

                            mediaContent(for: mediaAsset)
                        }
                    }

                    Text(lesson.content.prompt)
                        .font(KzuTypography.foundationalTitle)
                        .foregroundStyle(Color.kzuDeepNavy)
                        .multilineTextAlignment(.center)
                }
            }

            // Answer options — large, tactile buttons
            if let options = lesson.content.options {
                VStack(spacing: 16) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        FoundationalOptionButton(
                            text: option,
                            index: index,
                            isSelected: selectedIndex == index,
                            isCorrect: selectedIndex == index ? isCorrect : nil,
                            isBouncing: bounceOption == index
                        ) {
                            handleAnswer(index)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            // Feedback
            if showFeedback, let correct = isCorrect {
                feedbackView(correct: correct)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showFeedback)
    }

    // MARK: - Handle Answer

    private func handleAnswer(_ index: Int) {
        selectedIndex = index
        let correct = onAnswer(index)
        isCorrect = correct
        showFeedback = true

        if correct {
            bounceOption = index
            // Auto-dismiss after delight
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showFeedback = false
                selectedIndex = nil
                isCorrect = nil
                bounceOption = nil
            }
        } else {
            // Shake and allow retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showFeedback = false
                selectedIndex = nil
                isCorrect = nil
            }
        }
    }

    // MARK: - Feedback

    private func feedbackView(correct: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: correct ? "star.fill" : "arrow.uturn.backward")
                .font(.system(size: 24))
                .foregroundStyle(correct ? Color.kzuGold : Color.kzuWarning)

            Text(correct ? "Wonderful!" : "Try again — you're learning!")
                .font(KzuTypography.foundationalCaption)
                .foregroundStyle(Color.kzuDeepNavy)
        }
        .padding()
        .background(
            Capsule()
                .fill(correct ? Color.kzuGold.opacity(0.15) : Color.kzuWarning.opacity(0.15))
        )
    }

    // MARK: - Media Content

    @ViewBuilder
    private func mediaContent(for assetName: String) -> some View {
        if assetName.hasPrefix("counting_") {
            // e.g. "counting_apples_4" → show 4 apple emojis
            countingVisual(for: assetName)
        } else if assetName.hasPrefix("letter_") {
            // e.g. "letter_a_animation" → show large letter
            let parts = assetName.split(separator: "_")
            let letter = parts.count >= 2 ? String(parts[1]).uppercased() : "?"
            Text(letter)
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kzuDeepNavy)
        } else if assetName.hasPrefix("number_line") {
            // Number line visual
            HStack(spacing: 8) {
                ForEach(1...10, id: \.self) { n in
                    Text("\(n)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.kzuFlowBlue.opacity(n == 8 ? 0.3 : 0.1))
                        )
                }
            }
            .padding(.vertical, 12)
        } else {
            Text("📚")
                .font(.system(size: 56))
        }
    }

    private func countingVisual(for assetName: String) -> some View {
        // Parse "counting_apples_4" → emoji: 🍎, count: 4
        let parts = assetName.split(separator: "_")
        let count = parts.last.flatMap { Int($0) } ?? 3
        let itemName = parts.count >= 3 ? String(parts[1]) : "objects"

        let emoji: String = {
            switch itemName {
            case "apples": return "🍎"
            case "stars": return "⭐"
            case "hearts": return "❤️"
            case "fish": return "🐟"
            case "balls": return "⚽"
            case "flowers": return "🌸"
            case "birds": return "🐦"
            case "cats": return "🐱"
            case "dogs": return "🐶"
            default: return "🔵"
            }
        }()

        return VStack(spacing: 8) {
            // Show emoji grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(count, 5)), spacing: 12) {
                ForEach(0..<count, id: \.self) { _ in
                    Text(emoji)
                        .font(.system(size: 44))
                }
            }
            .padding()
        }
    }
}

// MARK: - Foundational Option Button

struct FoundationalOptionButton: View {
    let text: String
    let index: Int
    let isSelected: Bool
    let isCorrect: Bool?
    let isBouncing: Bool
    let action: () -> Void

    // Warm, Montessori-inspired colors
    private var buttonColor: Color {
        if let correct = isCorrect {
            return correct ? Color.kzuSuccess : Color.kzuError
        }
        let colors: [Color] = [
            Color(red: 0.65, green: 0.45, blue: 0.32),  // Warm wood
            Color(red: 0.42, green: 0.55, blue: 0.48),  // Sage green
            Color(red: 0.55, green: 0.42, blue: 0.58),  // Soft purple
        ]
        return colors[index % colors.count]
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(KzuTypography.foundationalBody)
                .foregroundStyle(Color.kzuIvory)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    ZStack {
                        // Shadow base (Montessori tactile depth)
                        RoundedRectangle(cornerRadius: 20)
                            .fill(buttonColor.opacity(0.5))
                            .offset(y: isSelected ? 1 : 5)

                        // Button face
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [buttonColor, buttonColor.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .offset(y: isSelected ? 3 : 0)

                        // Top highlight
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.3), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .offset(y: isSelected ? 3 : 0)
                    }
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isBouncing ? 1.08 : (isSelected ? 0.97 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)
        .sensoryFeedback(.impact(weight: .heavy), trigger: isSelected)
    }
}
