// ContentDeliveryEngine.swift
// Kzu — Curriculum ingest, serve, and score engine

import Foundation
import Observation

// MARK: - Content Delivery Engine

@Observable
final class ContentDeliveryEngine {

    // MARK: State
    var currentUnit: CurriculumUnit?
    var currentLessonIndex: Int = 0
    var isInExplorerMode = false
    var sessionScore: SessionScore?

    // MARK: Internal tracking
    private var answers: [AnswerResult] = []
    private var lessonStartTime: Date = .now
    private var attemptCounts: [String: Int] = [:]
    
    // MARK: Internal services
    private let orchestrator = CurriculumOrchestrator()

    // MARK: - Load Curriculum

    /// Loads a curriculum unit for the given grade and subject from the CurriculumOrchestrator.
    func loadUnit(for grade: Int, subject: Subject) async -> CurriculumUnit? {
        // Use the centralized Orchestrator which knows about TEKS, EarlyEd, and Visionary
        if let unit = await orchestrator.fetchUnit(for: grade, subject: subject) {
            return unit
        }
        
        // Final fallback: bundled sample curriculum (if orchestrator fails completely)
        let gradeBand: String = grade <= 2 ? "foundational" : "exploration"
        return loadSampleCurriculum(subject: subject, gradeBand: gradeBand)
    }

    /// Loads the bundled sample curriculum as a fallback
    private func loadSampleCurriculum(subject: Subject, gradeBand: String) -> CurriculumUnit? {
        let filename = subject == .math ? "SampleMathCurriculum" : "SampleCurriculum"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(CurriculumUnit.self, from: data)
    }

    // MARK: - Start Session

    func startSession(unit: CurriculumUnit) {
        currentUnit = unit
        currentLessonIndex = 0
        isInExplorerMode = false
        answers = []
        attemptCounts = [:]
        sessionScore = nil
        lessonStartTime = .now
    }

    // MARK: - Current Lesson

    var currentLesson: Lesson? {
        guard let unit = currentUnit,
              currentLessonIndex < unit.lessons.count else {
            return nil
        }
        return unit.lessons[currentLessonIndex]
    }

    var hasMoreLessons: Bool {
        guard let unit = currentUnit else { return false }
        return currentLessonIndex < unit.lessons.count
    }

    var lessonsCompleted: Int { currentLessonIndex }

    var totalLessons: Int { currentUnit?.lessons.count ?? 0 }

    var lessonProgress: Double {
        guard totalLessons > 0 else { return 0 }
        return Double(lessonsCompleted) / Double(totalLessons)
    }

    // MARK: - Submit Answer

    /// Submits an answer for the current lesson and advances if correct.
    /// Returns the result including correctness and timing metrics.
    func submitAnswer(_ answerIndex: Int) -> AnswerResult {
        guard let lesson = currentLesson else {
            return AnswerResult(isCorrect: false, lessonId: "", timeSpent: 0, attemptNumber: 0)
        }

        let timeSpent = Date().timeIntervalSince(lessonStartTime)
        let attemptNumber = (attemptCounts[lesson.lessonId] ?? 0) + 1
        attemptCounts[lesson.lessonId] = attemptNumber

        let isCorrect: Bool
        if let correctIndex = lesson.content.correctIndex {
            isCorrect = answerIndex == correctIndex
        } else {
            isCorrect = true  // Non-graded content
        }

        let result = AnswerResult(
            isCorrect: isCorrect,
            lessonId: lesson.lessonId,
            timeSpent: timeSpent,
            attemptNumber: attemptNumber
        )

        answers.append(result)

        if isCorrect {
            advanceToNextLesson()
        }

        return result
    }

    /// Submits a custom interaction result directly computed by the UI (e.g. matching)
    func submitCustomResult(isCorrect: Bool) -> AnswerResult {
        guard let lesson = currentLesson else {
            return AnswerResult(isCorrect: false, lessonId: "", timeSpent: 0, attemptNumber: 0)
        }

        let timeSpent = Date().timeIntervalSince(lessonStartTime)
        let attemptNumber = (attemptCounts[lesson.lessonId] ?? 0) + 1
        attemptCounts[lesson.lessonId] = attemptNumber

        let result = AnswerResult(
            isCorrect: isCorrect,
            lessonId: lesson.lessonId,
            timeSpent: timeSpent,
            attemptNumber: attemptNumber
        )

        answers.append(result)

        if isCorrect {
            advanceToNextLesson()
        }

        return result
    }

    /// Submits a free-response answer
    func submitFreeResponse(_ response: String) -> AnswerResult {
        guard let lesson = currentLesson else {
            return AnswerResult(isCorrect: false, lessonId: "", timeSpent: 0, attemptNumber: 0)
        }

        let timeSpent = Date().timeIntervalSince(lessonStartTime)
        let attemptNumber = (attemptCounts[lesson.lessonId] ?? 0) + 1
        attemptCounts[lesson.lessonId] = attemptNumber

        let isCorrect: Bool
        if let expected = lesson.content.expectedAnswer {
            let normalizedResponse = response.lowercased().trimmingCharacters(in: .whitespaces)
            let normalizedExpected = expected.lowercased().trimmingCharacters(in: .whitespaces)
            let variations = lesson.content.acceptableVariations?.map {
                $0.lowercased().trimmingCharacters(in: .whitespaces)
            } ?? []

            isCorrect = normalizedResponse == normalizedExpected ||
                        variations.contains(normalizedResponse)
        } else {
            isCorrect = true
        }

        let result = AnswerResult(
            isCorrect: isCorrect,
            lessonId: lesson.lessonId,
            timeSpent: timeSpent,
            attemptNumber: attemptNumber
        )

        answers.append(result)

        if isCorrect {
            advanceToNextLesson()
        }

        return result
    }

    /// Submits a numeric answer (for math)
    func submitNumericAnswer(_ value: Double) -> AnswerResult {
        guard let lesson = currentLesson else {
            return AnswerResult(isCorrect: false, lessonId: "", timeSpent: 0, attemptNumber: 0)
        }

        let timeSpent = Date().timeIntervalSince(lessonStartTime)
        let attemptNumber = (attemptCounts[lesson.lessonId] ?? 0) + 1
        attemptCounts[lesson.lessonId] = attemptNumber

        let isCorrect: Bool
        if let expected = lesson.content.numericAnswer {
            let tolerance = lesson.content.tolerance ?? 0.01
            isCorrect = abs(value - expected) <= tolerance
        } else {
            isCorrect = true
        }

        let result = AnswerResult(
            isCorrect: isCorrect,
            lessonId: lesson.lessonId,
            timeSpent: timeSpent,
            attemptNumber: attemptNumber
        )

        answers.append(result)

        if isCorrect {
            advanceToNextLesson()
        }

        return result
    }

    // MARK: - Advance

    private func advanceToNextLesson() {
        currentLessonIndex += 1
        lessonStartTime = .now

        if !hasMoreLessons {
            calculateSessionScore()
        }
    }

    // MARK: - Explorer Mode

    /// Should transition to Explorer Mode when curriculum is complete
    /// but the learning block timer hasn't expired yet.
    var shouldTransitionToExplorer: Bool {
        guard let unit = currentUnit else { return false }
        return currentLessonIndex >= unit.lessons.count && !isInExplorerMode
    }

    var explorerContent: ExplorerContent? {
        currentUnit?.explorerContent
    }

    func enterExplorerMode() {
        isInExplorerMode = true
    }

    /// Resets the engine for the next lesson run within the same unit.
    func resetForNextLesson() {
        currentLessonIndex = 0
        isInExplorerMode = false
        answers = []
        attemptCounts = [:]
        sessionScore = nil
        lessonStartTime = .now
    }

    // MARK: - Scoring

    private func calculateSessionScore() {
        let correctAnswers = answers.filter { $0.isCorrect && $0.attemptNumber == 1 }
        let totalQuestions = currentUnit?.lessons.count ?? 0
        let firstAttemptAnswers = answers.filter { $0.attemptNumber == 1 }

        let accuracy = totalQuestions > 0
            ? Double(correctAnswers.count) / Double(totalQuestions)
            : 0

        let avgTime = firstAttemptAnswers.isEmpty
            ? 0
            : firstAttemptAnswers.map(\.timeSpent).reduce(0, +) / Double(firstAttemptAnswers.count)

        // Engagement: penalize both rushing (<5s) and excessive delay (>120s)
        let pacingScore: Double
        if avgTime < 5 {
            pacingScore = 0.3  // Likely guessing
        } else if avgTime > 120 {
            pacingScore = 0.5  // Distracted
        } else {
            pacingScore = 1.0  // Good pacing
        }

        let engagementScore = (accuracy * 0.7) + (pacingScore * 0.3)

        sessionScore = SessionScore(
            totalQuestions: totalQuestions,
            correctAnswers: correctAnswers.count,
            averageTimePerQuestion: avgTime,
            accuracy: accuracy,
            engagementScore: engagementScore
        )
    }

    // MARK: - Current Engagement (live, before session ends)

    var currentEngagement: Double {
        let firstAttemptCorrect = answers.filter { $0.isCorrect && $0.attemptNumber == 1 }
        guard !answers.isEmpty else { return 0 }

        let accuracy = Double(firstAttemptCorrect.count) / Double(currentLessonIndex > 0 ? currentLessonIndex : 1)
        return accuracy
    }

    var currentRewardTier: RewardTier {
        sessionScore?.rewardTier ?? (currentEngagement >= 0.75 ? .goldenKey : .standard)
    }
}
