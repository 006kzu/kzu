// FlowTimerView.swift
// Kzu — "Time Remaining in Flow" — the soul of the Pomodoro experience

import SwiftUI

// MARK: - Flow Timer View

/// The ever-present circular timer that emphasizes the Pomodoro cycle.
/// This is the "executive function" layer — the primary meta-lesson.
struct FlowTimerView: View {
    let timeRemaining: TimeInterval
    let totalDuration: TimeInterval
    let phaseLabel: String
    let isLearningPhase: Bool

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalDuration)
    }

    private var minutes: Int { Int(timeRemaining) / 60 }
    private var seconds: Int { Int(timeRemaining) % 60 }

    private var isLastMinute: Bool { timeRemaining <= 60 }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Flow ring
                FlowRing(progress: progress, lineWidth: 8)
                    .frame(width: 140, height: 140)

                // Inner content
                VStack(spacing: 2) {
                    // Phase label
                    Text(phaseLabel)
                        .font(KzuTypography.timerLabel)
                        .foregroundStyle(Color.kzuSoftNavy)
                        .tracking(1.5)
                        .textCase(.uppercase)

                    // Time display
                    Text(String(format: "%02d:%02d", minutes, seconds))
                        .font(KzuTypography.timerDisplay)
                        .foregroundStyle(
                            isLastMinute
                                ? Color.kzuGold
                                : Color.kzuDeepNavy
                        )
                        .monospacedDigit()
                        .contentTransition(.numericText())

                    // Contextual subtitle
                    Text(isLearningPhase ? "in your flow" : "rest & reflect")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.kzuSoftNavy.opacity(0.6))
                }
            }
            // Pulse on last minute
            .modifier(LastMinutePulse(isActive: isLastMinute))
        }
    }
}

// MARK: - Compact Timer (for embedding in content area)

struct CompactFlowTimer: View {
    let timeRemaining: TimeInterval
    let totalDuration: TimeInterval

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (timeRemaining / totalDuration)
    }

    private var minutes: Int { Int(timeRemaining) / 60 }
    private var seconds: Int { Int(timeRemaining) % 60 }

    var body: some View {
        HStack(spacing: 10) {
            // Mini ring
            ZStack {
                Circle()
                    .stroke(Color.kzuSurface, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.kzuFlowBlue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 28, height: 28)

            Text(String(format: "%02d:%02d", minutes, seconds))
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color.kzuDeepNavy)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.kzuCardBg)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

// MARK: - Last Minute Pulse

struct LastMinutePulse: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(Color.kzuGold.opacity(isPulsing ? 0.0 : 0.3), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .frame(width: 160, height: 160)
                    .opacity(isActive ? 1 : 0)
            )
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
    }
}
