// SessionTelemetryEngine.swift
// Kzu — Focus Quotient Telemetry Engine
//
// Collects timestamped events during a learning session and computes
// the "Focus Quotient" (FQ) — a 0.0-1.0 score representing how deeply
// a student was engaged. Designed for local-only storage (privacy-first).
//
// ── JSON Schema ─────────────────────────────────────────────────────────────
// {
//   "sessionId":   "UUID string",
//   "startedAt":   "ISO 8601 timestamp",
//   "endedAt":     "ISO 8601 timestamp",
//   "gradeLevel":  4,
//   "subject":     "literacy",
//   "events": [
//     { "type": "touch",             "at": "ISO 8601" },
//     { "type": "correctAnswer",     "lessonId": "l1", "responseTime": 12.4, "at": "..." },
//     { "type": "incorrectAnswer",   "lessonId": "l2", "responseTime": 34.1, "at": "..." },
//     { "type": "inactivityTrigger", "state": "ambientFade",  "at": "..." },
//     { "type": "inactivityTrigger", "state": "focusCheck",   "at": "..." },
//     { "type": "inactivityTrigger", "state": "flowFreeze",   "at": "..." }
//   ],
//   "focusQuotient": 0.82,
//   "trendPhase":    "upwardGrowth"
// }
// ────────────────────────────────────────────────────────────────────────────

import Foundation

// MARK: - FQ Event

/// A single timestamped interaction event logged during a session.
enum FQEvent: Codable {
    case touch(at: Date)
    case correctAnswer(lessonId: String, responseTime: TimeInterval, at: Date)
    case incorrectAnswer(lessonId: String, responseTime: TimeInterval, at: Date)
    case inactivityTrigger(state: InactivityStateLabel, at: Date)

    // ── Codable conformance ─────────────────────────────────────────────────

    private enum CodingKeys: String, CodingKey {
        case type, lessonId, responseTime, state, at
    }

    enum EventType: String, Codable {
        case touch, correctAnswer, incorrectAnswer, inactivityTrigger
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .touch(let at):
            try c.encode(EventType.touch, forKey: .type)
            try c.encode(at, forKey: .at)
        case .correctAnswer(let lid, let rt, let at):
            try c.encode(EventType.correctAnswer, forKey: .type)
            try c.encode(lid, forKey: .lessonId)
            try c.encode(rt,  forKey: .responseTime)
            try c.encode(at,  forKey: .at)
        case .incorrectAnswer(let lid, let rt, let at):
            try c.encode(EventType.incorrectAnswer, forKey: .type)
            try c.encode(lid, forKey: .lessonId)
            try c.encode(rt,  forKey: .responseTime)
            try c.encode(at,  forKey: .at)
        case .inactivityTrigger(let state, let at):
            try c.encode(EventType.inactivityTrigger, forKey: .type)
            try c.encode(state, forKey: .state)
            try c.encode(at,    forKey: .at)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(EventType.self, forKey: .type)
        let at   = try c.decode(Date.self, forKey: .at)
        switch type {
        case .touch:
            self = .touch(at: at)
        case .correctAnswer:
            let lid = try c.decode(String.self, forKey: .lessonId)
            let rt  = try c.decode(TimeInterval.self, forKey: .responseTime)
            self = .correctAnswer(lessonId: lid, responseTime: rt, at: at)
        case .incorrectAnswer:
            let lid = try c.decode(String.self, forKey: .lessonId)
            let rt  = try c.decode(TimeInterval.self, forKey: .responseTime)
            self = .incorrectAnswer(lessonId: lid, responseTime: rt, at: at)
        case .inactivityTrigger:
            let state = try c.decode(InactivityStateLabel.self, forKey: .state)
            self = .inactivityTrigger(state: state, at: at)
        }
    }
}

// MARK: - Inactivity State Label (Codable mirror of InactivityState enum)

enum InactivityStateLabel: String, Codable {
    case ambientFade, focusCheck, flowFreeze
}

// MARK: - Trend Phase

enum TrendPhase: String, Codable {
    case upwardGrowth   // FQ > baseline + 5%
    case steadyState    // within ±5% of baseline
    case fatigue        // FQ < baseline - 5%
    case insufficient   // fewer than 3 sessions in the 7-day window
}

// MARK: - Session Telemetry (the serialisable record)

struct SessionTelemetry: Codable {
    let sessionId:      UUID
    let startedAt:      Date
    var endedAt:        Date?
    let gradeLevel:     Int
    let subject:        String
    var events:         [FQEvent]
    var focusQuotient:  Double    // 0.0 – 1.0 (display as 0–100)
    var trendPhase:     TrendPhase

    init(gradeLevel: Int, subject: String) {
        self.sessionId     = UUID()
        self.startedAt     = Date()
        self.gradeLevel    = gradeLevel
        self.subject       = subject
        self.events        = []
        self.focusQuotient = 0
        self.trendPhase    = .insufficient
    }

    /// JSON string representation for local SwiftData storage.
    var jsonString: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting    = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }
}

// MARK: - Session Telemetry Engine

/// Lightweight, thread-safe (main-actor) recorder attached to LearningBlockView.
/// Records events in-memory; call `finalize()` at session end to compute FQ and persist.
@MainActor
final class SessionTelemetryEngine {

    // MARK: Public accessors
    private(set) var telemetry: SessionTelemetry?

    // ── FQ weights ──────────────────────────────────────────────────────────
    private static let wAccuracy    = 0.40
    private static let wEngagement  = 0.25
    private static let wResilience  = 0.25
    private static let wIntegrity   = 0.10

    // Baseline: 8 touches-per-minute = fully engaged reader/learner
    private static let engagementBaseline = 8.0
    // 3+ inactivity triggers in a session → resilience score 0
    private static let maxTriggers = 3.0

    // MARK: - Lifecycle

    func startSession(gradeLevel: Int, subject: String) {
        telemetry = SessionTelemetry(gradeLevel: gradeLevel, subject: subject)
    }

    // MARK: - Event Recording

    func recordTouch() {
        telemetry?.events.append(.touch(at: Date()))
    }

    func recordAnswer(lessonId: String, isCorrect: Bool, responseTime: TimeInterval) {
        let event: FQEvent = isCorrect
            ? .correctAnswer(lessonId: lessonId, responseTime: responseTime, at: Date())
            : .incorrectAnswer(lessonId: lessonId, responseTime: responseTime, at: Date())
        telemetry?.events.append(event)
    }

    func recordInactivityTrigger(_ label: InactivityStateLabel) {
        telemetry?.events.append(.inactivityTrigger(state: label, at: Date()))
    }

    // MARK: - Finalize (compute FQ + return for persistence)

    /// Call when the session ends. Returns the completed telemetry record
    /// with a computed FQ and trend phase populated. The caller is responsible
    /// for persisting to SwiftData.
    ///
    /// - Parameters:
    ///   - wasCompleted: Whether the user finished the full 25-minute block
    ///   - priorSessions: 7-day history for trend analysis
    func finalize(wasCompleted: Bool, priorSessions: [Double]) -> SessionTelemetry? {
        guard var t = telemetry else { return nil }
        t.endedAt = Date()

        let fq = calculateFQ(events: t.events,
                             duration: t.endedAt!.timeIntervalSince(t.startedAt),
                             wasCompleted: wasCompleted)
        t.focusQuotient = fq
        t.trendPhase    = analyzeTrend(currentFQ: fq, priorFQs: priorSessions)

        telemetry = t
        return t
    }

    // MARK: - FQ Algorithm

    /// Weighted Focus Quotient calculation.
    ///
    /// FQ = 0.40·accuracy + 0.25·engagement + 0.25·resilience + 0.10·integrity
    ///
    /// All components are [0, 1]; result is clamped to [0, 1].
    func calculateFQ(events: [FQEvent],
                     duration: TimeInterval,
                     wasCompleted: Bool) -> Double {

        // ── 1. Accuracy (40%) ───────────────────────────────────────────────
        let correct   = events.filter { if case .correctAnswer   = $0 { return true }; return false }.count
        let incorrect = events.filter { if case .incorrectAnswer = $0 { return true }; return false }.count
        let totalAnswers = correct + incorrect
        let accuracy = totalAnswers > 0
            ? Double(correct) / Double(totalAnswers)
            : 0.5   // neutral — no answers yet (pure explorer mode etc.)

        // ── 2. Touch Engagement (25%) ───────────────────────────────────────
        // Count raw touches and normalise by session duration in minutes.
        let touchCount = events.filter { if case .touch = $0 { return true }; return false }.count
        let minutes    = max(duration / 60, 0.5)   // avoid division by zero
        let tpm        = Double(touchCount) / minutes
        let engagement = min(1.0, tpm / Self.engagementBaseline)

        // ── 3. Inactivity Resilience (25%) ──────────────────────────────────
        let triggers   = events.filter { if case .inactivityTrigger = $0 { return true }; return false }.count
        let resilience = max(0.0, 1.0 - Double(triggers) / Self.maxTriggers)

        // ── 4. Session Integrity (10%) ───────────────────────────────────────
        let integrity: Double = wasCompleted ? 1.0 : 0.0

        // ── Weighted sum ─────────────────────────────────────────────────────
        let raw = Self.wAccuracy   * accuracy
                + Self.wEngagement * engagement
                + Self.wResilience * resilience
                + Self.wIntegrity  * integrity

        return max(0.0, min(1.0, raw))
    }

    // MARK: - Trend Analysis

    /// Compares current FQ against the rolling 7-day baseline.
    ///
    /// - Parameters:
    ///   - currentFQ: The just-computed [0, 1] FQ for this session.
    ///   - priorFQs: Array of stored `focusQuotient` values from the last 7 days.
    func analyzeTrend(currentFQ: Double, priorFQs: [Double]) -> TrendPhase {
        guard priorFQs.count >= 3 else { return .insufficient }

        let baseline = priorFQs.reduce(0, +) / Double(priorFQs.count)
        let delta    = currentFQ - baseline

        switch delta {
        case let d where d >  0.05: return .upwardGrowth
        case let d where d < -0.05: return .fatigue
        default:                    return .steadyState
        }
    }
}
