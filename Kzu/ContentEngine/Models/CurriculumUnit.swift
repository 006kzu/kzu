// CurriculumUnit.swift
// Kzu — JSON-decodable curriculum models (CK-12 / Common Core compatible)

import Foundation

// MARK: - Subject

enum Subject: String, Codable, CaseIterable {
    case literacy
    case math
    case visionary   // AI/Robotics future-tech lessons
}

// MARK: - Content Mode

enum ContentMode {
    case standard    // TEKSAdapter → Texas Gateway
    case visionary   // InnovationAdapter → local JSON
}

// MARK: - Grade Band

enum GradeBand: String, Codable {
    case foundational  // K-2: Phonics, Number Sense
    case exploration   // 3-8: Chapter Journeys
}

// MARK: - Visionary Theme

/// Sub-theme for Visionary (AI/Robotics) lessons.
enum VisionaryTheme: String, Codable {
    case ai        = "ai"
    case robotics  = "robotics"
    case data      = "data"
    case ethics    = "ethics"

    var label: String {
        switch self {
        case .ai:       return "🧠 Artificial Intelligence"
        case .robotics: return "🤖 Robotics"
        case .data:     return "📊 Data Science"
        case .ethics:   return "⚖️ AI Ethics"
        }
    }

    var teksArea: String {
        "TEKS §126 – Technology Applications"
    }
}

// MARK: - Curriculum Unit

/// Top-level container for a unit of curriculum.
/// A unit contains multiple lessons and optional explorer content.
struct CurriculumUnit: Codable, Identifiable {
    let unitId: String
    let standard: String            // e.g. "TEKS §126.39(b)(1)(B)" or CCSS
    let gradeRange: [Int]
    let subject: Subject
    let title: String
    let description: String
    let lessons: [Lesson]
    let explorerContent: ExplorerContent?

    // Visionary-only fields (nil for standard content)
    let visionaryTheme: VisionaryTheme?
    let teksStandardTitle: String?  // human-readable TEKS standard description

    var id: String { unitId }

    var gradeBand: GradeBand {
        guard let maxGrade = gradeRange.last else { return .foundational }
        return maxGrade <= 2 ? .foundational : .exploration
    }

    var isVisionary: Bool { subject == .visionary }
}

// MARK: - Lesson

struct Lesson: Codable, Identifiable {
    let lessonId: String
    let type: LessonType
    let content: LessonContent

    var id: String { lessonId }
}

// MARK: - Lesson Type

enum LessonType: String, Codable {
    // K-2 Foundational
    case phonicsDrill       = "phonics_drill"
    case letterTracing      = "letter_tracing"
    case numberSense        = "number_sense"
    case countingExercise   = "counting_exercise"
    case matching           = "matching"
    case visualAssociation  = "visual_association"

    // 3-8 Deep Exploration
    case readingPassage     = "reading_passage"
    case vocabularyBuilder  = "vocabulary_builder"
    case mathProblem        = "math_problem"
    case conceptualQuestion = "conceptual_question"
}

// MARK: - Lesson Content

struct LessonContent: Codable {
    // Common fields
    let prompt: String
    let instruction: String?

    // Multiple choice
    let options: [String]?
    let correctIndex: Int?

    // Free response
    let expectedAnswer: String?
    let acceptableVariations: [String]?

    // Reading passage
    let passageTitle: String?
    let passageText: String?
    let comprehensionQuestions: [ComprehensionQuestion]?

    // Media
    let mediaAsset: String?       // Asset name for SpriteKit animations
    let audioAsset: String?       // Asset name for pronunciation audio

    // Math specific
    let expression: String?       // e.g. "3 + 4 = ?"
    let numericAnswer: Double?
    let tolerance: Double?        // For approximate answers

    // Early Ed specific
    let matchingPairs: [MatchingPair]?
    let targetObject: String?     // e.g. "duck", "toothbrush"
}

// MARK: - Matching Pair

struct MatchingPair: Codable, Identifiable {
    let left: String
    let right: String
    
    var id: String { left + right }
}

// MARK: - Comprehension Question

struct ComprehensionQuestion: Codable, Identifiable {
    let id: String
    let question: String
    let options: [String]
    let correctIndex: Int
}

// MARK: - Explorer Content

/// Enrichment content for when the student finishes curriculum early.
struct ExplorerContent: Codable {
    let type: ExplorerType
    let title: String
    let instruction: String
    let payload: ExplorerPayload
}

enum ExplorerType: String, Codable {
    case logicPuzzle    = "logic_puzzle"
    case freeDrawing    = "free_drawing"
    case patternGame    = "pattern_game"
    case storyStarter   = "story_starter"
    case mathChallenge  = "math_challenge"
}

struct ExplorerPayload: Codable {
    // Logic puzzles
    let puzzleData: String?
    let solution: String?

    // Story starters
    let storyPrompt: String?

    // Pattern games
    let sequence: [Int]?
    let nextExpected: Int?

    // Free drawing
    let canvasPrompt: String?
}

// MARK: - Answer Result

struct AnswerResult {
    let isCorrect: Bool
    let lessonId: String
    let timeSpent: TimeInterval
    let attemptNumber: Int
}

// MARK: - Session Score

struct SessionScore {
    let totalQuestions: Int
    let correctAnswers: Int
    let averageTimePerQuestion: TimeInterval
    let accuracy: Double
    let engagementScore: Double  // Composite of accuracy + pacing

    var rewardTier: RewardTier {
        // Golden Key: >= 80% accuracy AND good pacing (not rushing)
        engagementScore >= 0.75 ? .goldenKey : .standard
    }
}
