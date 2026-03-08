// SubjectPathView.swift
// Kzu — Lesson progression path for a subject

import SwiftUI
import SwiftData

// MARK: - Subject Path View

/// Shows the lesson progression path for a subject.
/// Displays a vertical scrolling path of lesson nodes with progress indicators.
struct SubjectPathView: View {
    let subject: Subject
    let studentGrade: Int
    @Bindable var contentEngine: ContentDeliveryEngine
    let shieldManager: ShieldManager
    @Bindable var appState: AppStateManager
    let onBack: () -> Void

    @Query(sort: \FocusSession.date, order: .reverse) private var sessions: [FocusSession]
    @State private var selectedLessonIndex: Int? = nil
    @State private var unit: CurriculumUnit? = nil
    @State private var isLoadingUnit = true

    private var completedLessonCount: Int {
        // Count completed sessions for this subject
        sessions.filter { $0.subject == subject.rawValue && $0.wasCompleted }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (back button + title)
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)

            // Path content
            ScrollView(showsIndicators: false) {
                if let unit = unit {
                    pathContent(unit: unit)
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                } else {
                    emptyState
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.kzuIvory, ignoresSafeAreaEdges: .all)
        .task {
            isLoadingUnit = true
            unit = await contentEngine.loadUnit(for: studentGrade, subject: subject)
            isLoadingUnit = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Dashboard")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Color.kzuSoftNavy)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: subject == .literacy ? "book.fill" : "function")
                    .foregroundStyle(subjectColor)
                Text(subject == .literacy ? "Literacy" : "Mathematics")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.kzuDeepNavy)
            }

            Spacer()
            // Balance spacing
            Color.clear.frame(width: 80)
        }
    }

    private var subjectColor: Color {
        subject == .literacy
            ? Color(red: 0.29, green: 0.56, blue: 0.85)
            : Color(red: 0.36, green: 0.72, blue: 0.48)
    }

    // MARK: - Path Content

    private func pathContent(unit: CurriculumUnit) -> some View {
        VStack(spacing: 0) {
            // Unit title
            GlassCard {
                VStack(spacing: 8) {
                    Text(unit.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.kzuDeepNavy)
                    Text(unit.description)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.kzuSoftNavy)
                        .multilineTextAlignment(.center)

                    // Progress
                    let progress = min(Double(completedLessonCount) / max(Double(unit.lessons.count), 1), 1.0)
                    HStack {
                        Text("Progress")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.kzuSoftNavy)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(subjectColor)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.kzuSurface)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(subjectColor)
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(.bottom, 24)

            // Lesson nodes
            ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { index, lesson in
                LessonPathNode(
                    index: index,
                    lesson: lesson,
                    isCompleted: index < completedLessonCount,
                    isCurrent: index == completedLessonCount,
                    isLocked: index > completedLessonCount,
                    color: subjectColor
                ) {
                    startLesson(at: index, in: unit)
                }

                // Connector line between nodes
                if index < unit.lessons.count - 1 {
                    PathConnector(
                        isCompleted: index < completedLessonCount,
                        color: subjectColor
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            if isLoadingUnit {
                ProgressView()
                    .tint(Color.kzuSoftNavy)
                    .scaleEffect(1.5)
                Text("Loading path...")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)
            } else {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.kzuSoftNavy.opacity(0.3))
                Text("No lessons available yet")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.kzuSoftNavy)
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Start Lesson

    private func startLesson(at index: Int, in unit: CurriculumUnit) {
        contentEngine.startSession(unit: unit)
        contentEngine.currentLessonIndex = index

        if appState.isSessionPaused {
            // Resume the paused session (timer picks up where it left off)
            appState.resumeSession()
        } else {
            // Fresh session
            try? shieldManager.applyShields()
            try? KzuActivitySchedule.startLearningBlock()
            appState.transitionTo(.learningBlock)
        }
    }
}

// MARK: - Lesson Path Node

struct LessonPathNode: View {
    let index: Int
    let lesson: Lesson
    let isCompleted: Bool
    let isCurrent: Bool
    let isLocked: Bool
    let color: Color
    let action: () -> Void

    private var lessonTypeLabel: String {
        switch lesson.type {
        case .phonicsDrill: return "Phonics"
        case .letterTracing: return "Tracing"
        case .numberSense: return "Number Sense"
        case .countingExercise: return "Counting"
        case .readingPassage: return "Reading"
        case .vocabularyBuilder: return "Vocabulary"
        case .mathProblem: return "Math"
        case .conceptualQuestion: return "Concept"
        case .matching: return "Matching"
        case .visualAssociation: return "Visual Task"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Node circle
                ZStack {
                    Circle()
                        .fill(nodeColor)
                        .frame(width: 48, height: 48)
                        .shadow(color: isCurrent ? color.opacity(0.3) : .clear, radius: 8)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                // Lesson info
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lesson \(index + 1)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(isLocked ? Color.kzuSoftNavy.opacity(0.4) : Color.kzuDeepNavy)

                    Text(lessonTypeLabel)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(isLocked ? Color.kzuSoftNavy.opacity(0.3) : Color.kzuSoftNavy)
                }

                Spacer()

                // Arrow for current
                if isCurrent {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isCurrent ? color.opacity(0.08) : Color.kzuCardBg)
                    .shadow(color: .black.opacity(isCurrent ? 0.06 : 0.03), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCurrent ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1.0)
    }

    private var nodeColor: Color {
        if isCompleted { return color }
        if isCurrent { return color }
        return Color.kzuSoftNavy.opacity(0.3)
    }
}

// MARK: - Path Connector

struct PathConnector: View {
    let isCompleted: Bool
    let color: Color

    var body: some View {
        HStack {
            Spacer().frame(width: 36)
            Rectangle()
                .fill(isCompleted ? color : Color.kzuSurface)
                .frame(width: 3, height: 24)
            Spacer()
        }
    }
}
