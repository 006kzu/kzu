// LearningBlockView.swift
// Kzu — Main 25-minute learning screen

import SwiftUI
import UIKit
import SwiftData

// MARK: - Learning Block View

/// The primary view during a LEARNING_BLOCK. Hosts the FlowTimerView (always prominent)
/// and routes to the appropriate content view based on the student's grade band.
struct LearningBlockView: View {
    @Bindable var appState: AppStateManager
    @Bindable var contentEngine: ContentDeliveryEngine
    let grade: Int
    let onExit: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]

    @State private var showResetAlert = false
    @State private var lastResetCount = 0
    @State private var inactivityManager = TouchInactivityManager()
    @State private var telemetry = SessionTelemetryEngine()

    var gradeBand: GradeBand {
        grade <= 2 ? .foundational : .exploration
    }

    var body: some View {
        // ── Visionary subject: hand off to the dark-mode shell ────────────
        if contentEngine.currentUnit?.subject == .visionary {
            VisionaryLearningView(
                appState: appState,
                contentEngine: contentEngine,
                grade: grade,
                onExit: onExit
            )
            .onAppear {
                inactivityManager.configure(appState: appState)
                inactivityManager.start()
                telemetry.startSession(gradeLevel: grade, subject: "visionary")
            }
            .onDisappear {
                inactivityManager.stop()
                finalizeTelemetry()
            }
        } else {
        ZStack {
            // Background
            Color.kzuIvory.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header with back button
                HStack {
                    Button {
                        onExit()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Color.kzuSoftNavy)
                    }
                    Spacer()

                    // DEV: Skip timer button
                    #if DEBUG
                    Button {
                        appState.devSkipTimer()
                    } label: {
                        Text("⏩ Skip")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red.opacity(0.7)))
                    }
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // MARK: Timer Header (always visible, prominent)
                FlowTimerView(
                    timeRemaining: appState.timeRemaining,
                    totalDuration: KzuConstants.learningBlockDuration,
                    phaseLabel: appState.phaseLabel,
                    isLearningPhase: true
                )
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Progress indicator
                if contentEngine.totalLessons > 0 {
                    lessonProgressBar
                        .padding(.horizontal, 32)
                        .padding(.bottom, 16)
                }

                Divider()
                    .background(Color.kzuSurface)

                // MARK: Content Area
                ScrollView {
                    if contentEngine.isInExplorerMode {
                        ExplorerModeView(content: contentEngine.explorerContent)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                    } else if let lesson = contentEngine.currentLesson {
                        contentView(for: lesson)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            .id(lesson.lessonId)
                    } else if contentEngine.currentUnit != nil && contentEngine.sessionScore != nil {
                        lessonCompleteView
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if contentEngine.currentUnit == nil {
                        independentStudyView
                    } else {
                        loadingView
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: contentEngine.currentLessonIndex)
                .animation(.easeInOut(duration: 0.4), value: contentEngine.isInExplorerMode)
                // Forward all scroll/drag gestures to the inactivity timer + telemetry
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            inactivityManager.resetTimer()
                            telemetry.recordTouch()
                        }
                )
            }
            // ── Blur the entire learning env during Flow Freeze ────────────
            .blur(radius: {
                if case .flowFreeze = inactivityManager.state { return 10 } else { return 0 }
            }())
            .animation(.easeInOut(duration: 0.6), value: {
                if case .flowFreeze = inactivityManager.state { return true } else { return false }
            }())
            .allowsHitTesting({
                if case .flowFreeze = inactivityManager.state { return false } else { return true }
            }())

            // ── Inactivity Overlays ────────────────────────────────────────
            switch inactivityManager.state {
            case .active, .ambientFade:
                EmptyView()

            case .focusCheck(let secs):
                FocusCheckOverlay(
                    secondsLeft: secs,
                    onInteraction: { inactivityManager.resetTimer() }
                )
                .zIndex(10)
                .transition(.opacity.animation(.easeInOut(duration: 0.5)))

            case .flowFreeze:
                FlowFreezeOverlay(onRecover: { inactivityManager.recover() })
                    .zIndex(20)
            }
        }

        .onChange(of: appState.totalResets) { _, newValue in
            if newValue > lastResetCount {
                lastResetCount = newValue
                showResetAlert = true
                inactivityManager.resetTimer()
            }
        }
        .alert("Flow Interrupted", isPresented: $showResetAlert) {
            Button("Return to Flow") { }
        } message: {
            Text("You left your flow for too long. Your timer has been reset to 25:00. Stay focused — you've got this!")
        }
        .onAppear {
            inactivityManager.configure(appState: appState)
            inactivityManager.start()
            // Start telemetry session
            let subject = contentEngine.currentUnit?.subject.rawValue ?? "unknown"
            telemetry.startSession(gradeLevel: grade, subject: subject)
        }
        .onChange(of: inactivityManager.state) { _, newState in
            // Forward inactivity state transitions to telemetry
            switch newState {
            case .ambientFade:
                telemetry.recordInactivityTrigger(.ambientFade)
            case .focusCheck:
                telemetry.recordInactivityTrigger(.focusCheck)
            case .flowFreeze:
                telemetry.recordInactivityTrigger(.flowFreeze)
            case .active:
                break
            }
        }
        .onDisappear {
            inactivityManager.stop()
            finalizeTelemetry()
        }
        } // end else (standard mode)
    }

    // MARK: - Telemetry Finalization

    /// Called on `onDisappear`. Computes the FQ, assembles a `FocusSession`,
    /// and inserts it into SwiftData for 7-day trend analysis.
    private func finalizeTelemetry() {
        let wasCompleted = appState.currentPhase == .gameHub  // moved to game hub = completed the block
        let priorFQs = FocusMetricsCalculator.priorFQs(sessions: sessions)

        guard let record = telemetry.finalize(wasCompleted: wasCompleted, priorSessions: priorFQs) else { return }

        let triggerCount = record.events.filter {
            if case .inactivityTrigger = $0 { return true }; return false
        }.count

        let sessionRecord = FocusSession(
            wasCompleted: wasCompleted,
            wasReset: appState.totalResets > 0,
            resetCount: appState.totalResets,
            focusMinutes: (record.endedAt?.timeIntervalSince(record.startedAt) ?? 0) / 60,
            accuracy: contentEngine.currentEngagement,
            engagementScore: record.focusQuotient,
            rewardTier: contentEngine.currentRewardTier,
            subject: contentEngine.currentUnit?.subject ?? .literacy,
            gradeLevel: grade,
            focusQuotient: record.focusQuotient,
            inactivityTriggerCount: triggerCount,
            telemetryJSON: record.jsonString ?? ""
        )

        modelContext.insert(sessionRecord)
        print("✅ FQ session saved: \(String(format: "%.0f", record.focusQuotient * 100))/100 — \(record.trendPhase.rawValue)")
    }

    // MARK: - Progress Bar

    private var lessonProgressBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Journey Progress")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)
                Spacer()
                Text("\(contentEngine.lessonsCompleted)/\(contentEngine.totalLessons)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.kzuDeepNavy)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.kzuSurface)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.kzuFlowBlue, .kzuGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * contentEngine.lessonProgress, height: 6)
                        .animation(.easeInOut(duration: 0.5), value: contentEngine.lessonProgress)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private func contentView(for lesson: Lesson) -> some View {
        switch gradeBand {
        case .foundational:
            if lesson.type == .matching {
                FoundationalMatchingView(
                    lesson: lesson,
                    onSubmit: { isCorrect in
                        let _ = contentEngine.submitCustomResult(isCorrect: isCorrect)
                    }
                )
                .padding()
            } else {
                FoundationalPathView(
                    lesson: lesson,
                    onAnswer: { index in
                        let result = contentEngine.submitAnswer(index)
                        return result.isCorrect
                    }
                )
                .padding()
            }

        case .exploration:
            ChapterJourneyView(
                lesson: lesson,
                onAnswer: { index in
                    let result = contentEngine.submitAnswer(index)
                    return result.isCorrect
                },
                onFreeResponse: { response in
                    let result = contentEngine.submitFreeResponse(response)
                    return result.isCorrect
                },
                onNumericAnswer: { value in
                    let result = contentEngine.submitNumericAnswer(value)
                    return result.isCorrect
                }
            )
            .padding()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(Color.kzuFlowBlue)
            Text("Preparing your journey...")
                .font(KzuTypography.journeyCaption)
                .foregroundStyle(Color.kzuSoftNavy)
        }
        .padding(.top, 60)
    }

    // MARK: - Independent Study View

    private var independentStudyView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.kzuSuccess)
            
            Text("Focus Session Active")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kzuDeepNavy)
            
            Text("Distracting apps are locked. You can study independently, or tap Back to choose a Kzu subject.")
                .font(KzuTypography.journeyCaption)
                .foregroundStyle(Color.kzuSoftNavy)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.top, 80)
    }

    // MARK: - Lesson Complete

    private var lessonCompleteView: some View {
        VStack(spacing: 28) {
            Spacer()

            // Celebration
            Image(systemName: "star.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.kzuGold)
                .shadow(color: Color.kzuGold.opacity(0.4), radius: 12)

            Text("Lesson Complete! 🎉")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.kzuDeepNavy)

            // Score card
            if let score = contentEngine.sessionScore {
                GlassCard {
                    VStack(spacing: 12) {
                        HStack {
                            scoreItem(label: "Accuracy", value: "\(Int(score.accuracy * 100))%", color: .kzuSuccess)
                            Spacer()
                            scoreItem(label: "Correct", value: "\(score.correctAnswers)/\(score.totalQuestions)", color: .kzuFlowBlue)
                            Spacer()
                            scoreItem(label: "Reward", value: score.rewardTier == .goldenKey ? "🔑 Gold" : "⭐ Standard", color: .kzuGold)
                        }
                    }
                }
                .padding(.horizontal, 20)

                Text(score.accuracy >= 0.8 ? "Outstanding work! 🌟" : "Keep practicing, you're improving!")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)
            }

            Spacer()

            // Next Lesson button
            NeoSkeuomorphicButton("Next Lesson", icon: "arrow.right.circle.fill") {
                contentEngine.resetForNextLesson()
            }
            .padding(.horizontal, 20)

            // Continue exploring as secondary option
            Button {
                contentEngine.enterExplorerMode()
                appState.transitionToExplorerMode()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                    Text("Continue Exploring Instead")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.kzuSoftNavy)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }

    private func scoreItem(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.kzuSoftNavy)
        }
    }
}
