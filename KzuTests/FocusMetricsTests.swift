// FocusMetricsTests.swift
// KzuTests — Focus Quotient, streaks, and growth trend tests

import XCTest
@testable import Kzu

final class FocusMetricsTests: XCTestCase {

    // MARK: - Focus Quotient

    func testFocusQuotientAllCompleted() {
        let sessions = (0..<5).map { _ in
            FocusSession(
                wasCompleted: true,
                focusMinutes: 25,
                accuracy: 0.9,
                engagementScore: 0.85,
                rewardTier: .goldenKey,
                subject: .math,
                gradeLevel: 3
            )
        }

        let fq = FocusMetricsCalculator.focusQuotient(sessions: sessions)
        XCTAssertEqual(fq, 100.0, accuracy: 0.01)
    }

    func testFocusQuotientMixed() {
        let completed = (0..<3).map { _ in
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.8,
                        engagementScore: 0.7, rewardTier: .standard, subject: .literacy, gradeLevel: 1)
        }
        let reset = (0..<2).map { _ in
            FocusSession(wasCompleted: false, wasReset: true, focusMinutes: 10, accuracy: 0.5,
                        engagementScore: 0.4, rewardTier: .standard, subject: .literacy, gradeLevel: 1)
        }

        let fq = FocusMetricsCalculator.focusQuotient(sessions: completed + reset)
        XCTAssertEqual(fq, 60.0, accuracy: 0.01)  // 3/5 = 60%
    }

    func testFocusQuotientEmpty() {
        let fq = FocusMetricsCalculator.focusQuotient(sessions: [])
        XCTAssertEqual(fq, 0.0)
    }

    // MARK: - Average Accuracy

    func testAverageAccuracy() {
        let sessions = [
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.8,
                        engagementScore: 0.7, rewardTier: .standard, subject: .math, gradeLevel: 4),
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 1.0,
                        engagementScore: 0.9, rewardTier: .goldenKey, subject: .math, gradeLevel: 4),
        ]

        let avg = FocusMetricsCalculator.averageAccuracy(sessions: sessions)
        XCTAssertEqual(avg, 0.9, accuracy: 0.01)
    }

    // MARK: - Total Focus Time

    func testTotalFocusMinutes() {
        let sessions = [
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.9,
                        engagementScore: 0.8, rewardTier: .standard, subject: .literacy, gradeLevel: 2),
            FocusSession(wasCompleted: false, focusMinutes: 12, accuracy: 0.5,
                        engagementScore: 0.4, rewardTier: .standard, subject: .literacy, gradeLevel: 2),
        ]

        let total = FocusMetricsCalculator.totalFocusMinutes(sessions: sessions)
        XCTAssertEqual(total, 37.0, accuracy: 0.01)
    }

    // MARK: - Golden Key Rate

    func testGoldenKeyRate() {
        let sessions = [
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.95,
                        engagementScore: 0.9, rewardTier: .goldenKey, subject: .math, gradeLevel: 5),
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.6,
                        engagementScore: 0.5, rewardTier: .standard, subject: .math, gradeLevel: 5),
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.88,
                        engagementScore: 0.8, rewardTier: .goldenKey, subject: .math, gradeLevel: 5),
        ]

        let rate = FocusMetricsCalculator.goldenKeyRate(sessions: sessions)
        XCTAssertEqual(rate, 2.0 / 3.0, accuracy: 0.01)
    }

    // MARK: - Subject Breakdown

    func testSubjectBreakdown() {
        let sessions = [
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.9,
                        engagementScore: 0.8, rewardTier: .standard, subject: .math, gradeLevel: 3),
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.85,
                        engagementScore: 0.75, rewardTier: .standard, subject: .literacy, gradeLevel: 3),
            FocusSession(wasCompleted: true, focusMinutes: 25, accuracy: 0.92,
                        engagementScore: 0.85, rewardTier: .goldenKey, subject: .math, gradeLevel: 3),
        ]

        let breakdown = FocusMetricsCalculator.subjectBreakdown(sessions: sessions)
        XCTAssertEqual(breakdown["math"], 2)
        XCTAssertEqual(breakdown["literacy"], 1)
    }

    // MARK: - Session Score

    func testSessionScoreRewardTier() {
        let goldenScore = SessionScore(
            totalQuestions: 10,
            correctAnswers: 9,
            averageTimePerQuestion: 15,
            accuracy: 0.9,
            engagementScore: 0.85
        )
        XCTAssertEqual(goldenScore.rewardTier, .goldenKey)

        let standardScore = SessionScore(
            totalQuestions: 10,
            correctAnswers: 5,
            averageTimePerQuestion: 8,
            accuracy: 0.5,
            engagementScore: 0.5
        )
        XCTAssertEqual(standardScore.rewardTier, .standard)
    }
}
