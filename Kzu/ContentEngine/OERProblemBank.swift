// OERProblemBank.swift
// Kzu — Maps TEKS objectives to OER practice problems from the bundled
// OERProblems.json database. Used by TEKSAdapter to build lesson content.

import Foundation

// MARK: - OER Problem Bank

/// Converts a `TEKSObjective` → a `Lesson` using bundled OER content.
/// Falls back to a synthetically-generated lesson if no OER match is found.
struct OERProblemBank {

    // MARK: - Public API

    func lesson(for objective: TEKSObjective, grade: Int, subject: Subject) -> Lesson? {
        // Try exact TEKS ID match first
        if let match = bundledLesson(for: objective.identifier) {
            return match
        }
        // Fall back to synthetic lesson generated from the standard text
        return syntheticLesson(from: objective, grade: grade, subject: subject)
    }

    // MARK: - Bundle Lookup

    private struct OEREntry: Decodable {
        let teksId: String
        let lesson: Lesson
    }

    private func bundledLesson(for teksId: String) -> Lesson? {
        guard let url  = Bundle.main.url(forResource: "OERProblems", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([OEREntry].self, from: data) else {
            return nil
        }
        return entries.first { $0.teksId == teksId }?.lesson
    }

    // MARK: - Synthetic Lesson Generator
    //
    // When no OER match exists, we build a basic conceptual question from
    // the TEKS standard text. This ensures every objective is teachable.

    private func syntheticLesson(from objective: TEKSObjective,
                                 grade: Int,
                                 subject: Subject) -> Lesson {
        let lessonType: LessonType = subject == .math ? .mathProblem : .conceptualQuestion

        let content = LessonContent(
            prompt: "Based on the TEKS standard: \"\(objective.fullStatement)\" — which best describes a student who has mastered this skill?",
            instruction: "Read the standard carefully and choose the best answer.",
            options: [
                "A student who can apply this concept independently",
                "A student who has memorized the standard word-for-word",
                "A student who skips this topic entirely",
                "A student who only knows partially related ideas"
            ],
            correctIndex: 0,
            expectedAnswer: nil,
            acceptableVariations: nil,
            passageTitle: nil,
            passageText: nil,
            comprehensionQuestions: nil,
            mediaAsset: nil,
            audioAsset: nil,
            expression: nil,
            numericAnswer: nil,
            tolerance: nil,
            matchingPairs: nil,
            targetObject: nil
        )

        return Lesson(
            lessonId: "oer-syn-\(objective.identifier.prefix(12))",
            type: lessonType,
            content: content
        )
    }
}
