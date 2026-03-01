// LearningBlockView.swift
// Kzu — Main 25-minute learning screen

import SwiftUI

// MARK: - Learning Block View

/// The primary view during a LEARNING_BLOCK. Hosts the FlowTimerView (always prominent)
/// and routes to the appropriate content view based on the student's grade band.
struct LearningBlockView: View {
    @Bindable var appState: AppStateManager
    @Bindable var contentEngine: ContentDeliveryEngine
    let grade: Int

    @State private var showResetAlert = false
    @State private var lastResetCount = 0

    var gradeBand: GradeBand {
        grade <= 2 ? .foundational : .exploration
    }

    var body: some View {
        ZStack {
            // Background
            Color.kzuIvory.ignoresSafeArea()

            VStack(spacing: 0) {
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
                    } else {
                        loadingView
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: contentEngine.currentLessonIndex)
                .animation(.easeInOut(duration: 0.4), value: contentEngine.isInExplorerMode)
            }
        }
        .onChange(of: appState.totalResets) { _, newValue in
            if newValue > lastResetCount {
                lastResetCount = newValue
                showResetAlert = true
            }
        }
        .onChange(of: contentEngine.shouldTransitionToExplorer) { _, shouldTransition in
            if shouldTransition {
                contentEngine.enterExplorerMode()
                appState.transitionToExplorerMode()
            }
        }
        .alert("Flow Interrupted", isPresented: $showResetAlert) {
            Button("Return to Flow") { }
        } message: {
            Text("You left your flow for too long. Your timer has been reset to 25:00. Stay focused — you've got this!")
        }
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
            FoundationalPathView(
                lesson: lesson,
                onAnswer: { index in
                    let result = contentEngine.submitAnswer(index)
                    return result.isCorrect
                }
            )
            .padding()

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

    // MARK: - Loading

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
}
