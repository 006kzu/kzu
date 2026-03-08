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

    // ── FQ Telemetry (added for Focus Quotient engine) ──────────────────────
    /// Weighted Focus Quotient [0.0, 1.0]; display ×100 to parents.
    var focusQuotient: Double
    /// Raw count of inactivity triggers (ambientFade/focusCheck/flowFreeze) in session.
    var inactivityTriggerCount: Int
    /// Full `SessionTelemetry` serialised as compact JSON — local only, never transmitted.
    var telemetryJSON: String

    init(
        wasCompleted: Bool,
        wasReset: Bool = false,
        resetCount: Int = 0,
        focusMinutes: Double,
        accuracy: Double,
        engagementScore: Double,
        rewardTier: RewardTier,
        subject: Subject,
        gradeLevel: Int,
        focusQuotient: Double = 0,
        inactivityTriggerCount: Int = 0,
        telemetryJSON: String = ""
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
        self.focusQuotient = focusQuotient
        self.inactivityTriggerCount = inactivityTriggerCount
        self.telemetryJSON = telemetryJSON
    }
}

// MARK: - Focus Metrics Calculator

struct FocusMetricsCalculator {

    // MARK: - Focus Quotient

    /// FQ (0–100 for parent display) = average of per-session focusQuotient × 100.
    /// Falls back to completion-rate if no rich telemetry exists yet.
    static func focusQuotient(sessions: [FocusSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        let sessionsWithFQ = sessions.filter { $0.focusQuotient > 0 }
        if !sessionsWithFQ.isEmpty {
            let avg = sessionsWithFQ.map(\.focusQuotient).reduce(0, +) / Double(sessionsWithFQ.count)
            return avg * 100   // 0–100 for parent display
        }
        // Backwards-compat fallback for sessions pre-telemetry
        let completed = sessions.filter(\.wasCompleted).count
        return (Double(completed) / Double(sessions.count)) * 100
    }

    // MARK: - Focus Growth (trend over time)

    /// 7-day rolling FQ trend using per-session focusQuotient for richer charting.
    static func focusGrowthTrend(sessions: [FocusSession], days: Int = 7) -> [(date: Date, fq: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return nil
            }
            let daySessions = sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
            let fq = focusQuotient(sessions: daySessions)
            return (date: date, fq: fq)
        }
    }

    /// Returns the raw [0,1] FQ values for the past N days — used by `SessionTelemetryEngine.analyzeTrend()`.
    static func priorFQs(sessions: [FocusSession], days: Int = 7) -> [Double] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return sessions
            .filter { $0.date >= cutoff && $0.focusQuotient > 0 }
            .map(\.focusQuotient)
    }

    /// Derives a `TrendPhase` from stored sessions for display on the dashboard.
    static func trendPhase(sessions: [FocusSession]) -> TrendPhase {
        guard let latest = sessions.sorted(by: { $0.date > $1.date }).first,
              latest.focusQuotient > 0 else { return .insufficient }
        let prior = priorFQs(sessions: sessions.filter { $0.id != latest.id })
        guard prior.count >= 3 else { return .insufficient }
        let baseline = prior.reduce(0, +) / Double(prior.count)
        let delta = latest.focusQuotient - baseline
        switch delta {
        case let d where d >  0.05: return .upwardGrowth
        case let d where d < -0.05: return .fatigue
        default:                    return .steadyState
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
