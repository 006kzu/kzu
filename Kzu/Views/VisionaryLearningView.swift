// VisionaryLearningView.swift
// Kzu — Dark-mode wrapper for AI/Robotics Visionary lessons.
//
// When a student enters a Visionary subject, the UI shifts to a sleek,
// near-black "Future Tech" aesthetic with electric-cyan accents and an
// animated circuit-grid background. All lesson content is the same —
// only the visual skin changes.

import SwiftUI

// MARK: - Visionary Learning View

/// Wraps standard lesson content in the Visionary dark-mode shell.
/// Pass the same `contentEngine` and `appState` as `LearningBlockView` —
/// this view is injected at the routing layer in `LearningBlockView`.
struct VisionaryLearningView: View {
    @Bindable var appState: AppStateManager
    @Bindable var contentEngine: ContentDeliveryEngine
    let grade: Int
    let onExit: () -> Void

    @State private var circuitPulse = false
    @State private var glowPulse    = false
    @State private var themeBadgeVisible = false

    private var theme: VisionaryTheme {
        contentEngine.currentUnit?.visionaryTheme ?? .ai
    }

    var body: some View {
        ZStack {
            // ── Background ─────────────────────────────────────────────────
            Color.vizBg.ignoresSafeArea()

            // Animated circuit-grid
            CircuitGridBackground(pulse: circuitPulse)
                .ignoresSafeArea()

            // Ambient glow halo at top
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [Color.vizAccent.opacity(glowPulse ? 0.12 : 0.06), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 200)
                .offset(y: -100)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: glowPulse)

            // ── Main scrollable content ────────────────────────────────────
            VStack(spacing: 0) {
                // Header bar
                visionaryHeader

                // Lesson content — reuse existing engine views,
                // styled via the injected environment color overrides
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // TEKS standard badge (shows educational alignment to parents)
                        teksBadge
                            .padding(.top, 8)

                        // The main lesson card, re-skinned
                        lessonCard
                            .padding(.horizontal, 20)

                        Spacer(minLength: 60)
                    }
                }
            }
        }
        .onAppear {
            circuitPulse  = true
            glowPulse     = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.5)) { themeBadgeVisible = true }
            }
        }
        .statusBarHidden(false)
    }

    // MARK: - Header

    private var visionaryHeader: some View {
        HStack(spacing: 12) {
            // Back
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.vizAccent)
            }
            .padding(.leading, 20)

            // Theme badge
            HStack(spacing: 6) {
                Text(theme.label)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.vizAccent)
                    .scaleEffect(themeBadgeVisible ? 1.0 : 0.85)
                    .opacity(themeBadgeVisible ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.vizAccent.opacity(0.12))
                    .overlay(Capsule().stroke(Color.vizAccent.opacity(0.35), lineWidth: 1))
            )

            Spacer()

            // Timer indicator (compact)
            if appState.currentPhase == .learningBlock {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.vizAccent)
                        .frame(width: 6, height: 6)
                        .opacity(glowPulse ? 1 : 0.4)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: glowPulse)

                    Text(timerLabel)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.vizSubtext)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.vizBg.opacity(0.95))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.vizAccent.opacity(0.15)),
                    alignment: .bottom
                )
        )
    }

    // MARK: - TEKS Badge

    private var teksBadge: some View {
        let standard = contentEngine.currentUnit?.standard ?? "TEKS §126"
        let teksTitle = contentEngine.currentUnit?.teksStandardTitle ?? "Technology Applications"

        return HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.vizGold)

            VStack(alignment: .leading, spacing: 1) {
                Text(standard)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.vizGold)

                Text(teksTitle)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.vizSubtext)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.vizGold.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vizGold.opacity(0.20), lineWidth: 1))
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Lesson Card

    private var lessonCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let lesson = contentEngine.currentLesson {
                // Lesson prompt
                Text(lesson.content.prompt)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.vizText)
                    .fixedSize(horizontal: false, vertical: true)

                if let instruction = lesson.content.instruction {
                    Text(instruction)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.vizSubtext)
                }

                // Multiple choice options
                if let options = lesson.content.options {
                    VStack(spacing: 10) {
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            VisionaryOptionButton(
                                label: option,
                                index: index,
                                onSelect: {
                                    _ = contentEngine.submitAnswer(index)
                                }
                            )
                        }
                    }
                }

                // Reading passage
                if let title = lesson.content.passageTitle,
                   let text  = lesson.content.passageText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.vizAccent)

                        Text(text)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.vizText.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.vizSurface))
                }
            } else {
                Text("All units complete — great work, innovator! 🚀")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.vizAccent)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.vizSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.vizAccent.opacity(0.20), lineWidth: 1)
                )
        )
        .shadow(color: Color.vizAccent.opacity(0.08), radius: 20, y: 8)
    }

    // MARK: - Helpers

    private var timerLabel: String {
        let mins = Int(appState.timeRemaining) / 60
        let secs = Int(appState.timeRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Visionary Option Button

private struct VisionaryOptionButton: View {
    let label: String
    let index: Int
    let onSelect: () -> Void

    @State private var tapped = false

    private let letters = ["A", "B", "C", "D"]

    var body: some View {
        Button(action: {
            tapped = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { tapped = false }
            onSelect()
        }) {
            HStack(spacing: 14) {
                // Letter badge
                ZStack {
                    Circle()
                        .fill(Color.vizAccent.opacity(0.15))
                        .overlay(Circle().stroke(Color.vizAccent.opacity(0.40), lineWidth: 1))
                        .frame(width: 32, height: 32)

                    Text(index < letters.count ? letters[index] : "\(index)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.vizAccent)
                }

                Text(label)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.vizText)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(tapped ? Color.vizAccent.opacity(0.18) : Color.vizSurface.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(tapped ? Color.vizAccent.opacity(0.6) : Color.vizAccent.opacity(0.12), lineWidth: 1)
                    )
            )
            .scaleEffect(tapped ? 0.97 : 1.0)
            .animation(.spring(duration: 0.18), value: tapped)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Circuit Grid Background

/// Animated subtle circuit-line grid drawn with Canvas.
private struct CircuitGridBackground: View {
    let pulse: Bool

    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                drawCircuit(ctx: ctx, size: size, t: t)
            }
        }
        .opacity(0.18)
        .allowsHitTesting(false)
    }

    private func drawCircuit(ctx: GraphicsContext, size: CGSize, t: Double) {
        let cyan = Color.vizAccent
        let spacing: CGFloat = 44
        var c = ctx

        // Horizontal lines
        var y: CGFloat = 0
        while y < size.height {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            c.stroke(path, with: .color(cyan.opacity(0.4)), lineWidth: 0.5)
            y += spacing
        }

        // Vertical lines
        var x: CGFloat = 0
        while x < size.width {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            c.stroke(path, with: .color(cyan.opacity(0.4)), lineWidth: 0.5)
            x += spacing
        }

        // Animated node dots at intersections
        y = 0
        while y < size.height {
            x = 0
            while x < size.width {
                let wave = sin(t * 1.2 + x * 0.05 + y * 0.05)
                let alpha = (wave + 1) / 2 * 0.7
                var dot = Path()
                dot.addEllipse(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4))
                c.fill(dot, with: .color(cyan.opacity(alpha)))
                x += spacing
            }
            y += spacing
        }
    }
}
