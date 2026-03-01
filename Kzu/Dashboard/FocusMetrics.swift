// FocusMetrics.swift
// Kzu — SwiftData model for Focus Growth tracking

import Foundation
import SwiftData

// MARK: - Focus Session Record

@Model
final class FocusSession {
    var id: UUID
    var date: Date
    var wasCompleted: Bool
    var wasReset: Bool
    var resetCount: Int
    var focusMinutes: Double
    var accuracy: Double            // 0.0 to 1.0
    var engagementScore: Double     // 0.0 to 1.0
    var rewardTier: String          // "standard" or "goldenKey"
    var subject: String             // "literacy" or "math"
    var gradeLevel: Int

    init(
        wasCompleted: Bool,
        wasReset: Bool = false,
        resetCount: Int = 0,
        focusMinutes: Double,
        accuracy: Double,
        engagementScore: Double,
        rewardTier: RewardTier,
        subject: Subject,
        gradeLevel: Int
    ) {
        self.id = UUID()
        self.date = Date()
        self.wasCompleted = wasCompleted
        self.wasReset = wasReset
        self.resetCount = resetCount
        self.focusMinutes = focusMinutes
        self.accuracy = accuracy
        self.engagementScore = engagementScore
        self.rewardTier = rewardTier.rawValue
        self.subject = subject.rawValue
        self.gradeLevel = gradeLevel
    }
}

// MARK: - Focus Metrics Calculator

struct FocusMetricsCalculator {

    // MARK: - Focus Quotient

    /// FQ = (completed sessions / total sessions) × 100
    /// Core metric displayed on the Parental Dashboard
    static func focusQuotient(sessions: [FocusSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let completed = sessions.filter(\.wasCompleted).count
        return (Double(completed) / Double(sessions.count)) * 100
    }

    // MARK: - Focus Growth (trend over time)

    /// Calculates the 7-day rolling FQ trend to show improvement
    /// Returns array of (date, FQ) pairs for charting
    static func focusGrowthTrend(sessions: [FocusSession], days: Int = 7) -> [(date: Date, fq: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return nil
            }

            let daySessions = sessions.filter { session in
                calendar.isDate(session.date, inSameDayAs: date)
            }

            let fq = focusQuotient(sessions: daySessions)
            return (date: date, fq: fq)
        }
    }

    // MARK: - Streak

    /// Count of consecutive days with at least one completed session
    static func currentStreak(sessions: [FocusSession]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let dayCompleted = sessions.contains { session in
                calendar.isDate(session.date, inSameDayAs: checkDate) && session.wasCompleted
            }

            if dayCompleted {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Average Accuracy

    static func averageAccuracy(sessions: [FocusSession]) -> Double {
        let completed = sessions.filter(\.wasCompleted)
        guard !completed.isEmpty else { return 0 }
        return completed.map(\.accuracy).reduce(0, +) / Double(completed.count)
    }

    // MARK: - Total Focus Time

    static func totalFocusMinutes(sessions: [FocusSession]) -> Double {
        sessions.map(\.focusMinutes).reduce(0, +)
    }

    // MARK: - Golden Key Rate

    static func goldenKeyRate(sessions: [FocusSession]) -> Double {
        let completed = sessions.filter(\.wasCompleted)
        guard !completed.isEmpty else { return 0 }
        let golden = completed.filter { $0.rewardTier == RewardTier.goldenKey.rawValue }
        return Double(golden.count) / Double(completed.count)
    }

    // MARK: - Subject Breakdown

    static func subjectBreakdown(sessions: [FocusSession]) -> [String: Int] {
        Dictionary(grouping: sessions.filter(\.wasCompleted), by: \.subject)
            .mapValues(\.count)
    }
}
