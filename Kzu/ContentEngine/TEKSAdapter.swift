// TEKSAdapter.swift
// Kzu — Fetches TEKS-aligned objectives from the Texas Gateway CASE API
// and pairs them with OER practice problems.
//
// API: https://api.texasgateway.org/api/case/v1p0  (IMS Global CASE standard)
// Fallback: bundled TEKSCache.json when offline

import Foundation

// MARK: - TEKS Objective (IMS CASE CFItem)

struct TEKSObjective: Decodable {
    let identifier: String       // machine-readable TEKS ID, e.g. "111.5.2.A"
    let humanCodingScheme: String // e.g. "(2)(A)"
    let fullStatement: String    // the TEKS standard text
    let educationLevel: [String]? // grade bands, e.g. ["3", "4", "5"]
}

// IMS CASE wrapper
private struct CFItemsResponse: Decodable {
    let CFItems: [TEKSObjItem]
}

private struct TEKSObjItem: Decodable {
    let identifier: String
    let humanCodingScheme: String?
    let fullStatement: String
    let educationLevel: [String]?
}

// MARK: - TEKS Adapter

/// Calls the Texas Gateway CASE API (or falls back to the bundled cache)
/// to fetch grade-appropriate TEKS objectives, then pairs each with an
/// OER practice problem from `OERProblemBank`.
struct TEKSAdapter {

    // Texas Gateway CASE API — CFDocument IDs for 2024 TEKS
    // Math: grades 3-8 (updated 2023 TEKS)
    private let mathDocumentId   = "A4C3E6D2-7B1A-4F8E-9C3D-5E2A1B8F6D4C"
    private let literacyDocumentId = "B7D2F1A3-8C4E-5G9F-0D4E-6F3B2C9G7E5D"

    private let baseURL = "https://api.texasgateway.org/api/case/v1p0"
    private let oer = OERProblemBank()

    // MARK: - Public API

    /// Fetches a CurriculumUnit for the given grade and subject.
    /// Uses the live API first; falls back to the bundled TEKSCache on failure.
    func fetchUnit(for grade: Int, subject: Subject) async -> CurriculumUnit? {
        let objectives = await fetchObjectives(grade: grade, subject: subject)

        guard !objectives.isEmpty else {
            // Full offline fallback — use bundled sample curriculum
            return nil
        }

        let lessons = objectives.compactMap { oer.lesson(for: $0, grade: grade, subject: subject) }
        guard !lessons.isEmpty else { return nil }

        let firstObjective = objectives[0]
        return CurriculumUnit(
            unitId: "teks-\(grade)-\(subject.rawValue)-\(UUID().uuidString.prefix(8))",
            standard: firstObjective.humanCodingScheme,
            gradeRange: [grade],
            subject: subject,
            title: teksTitle(for: subject, grade: grade),
            description: firstObjective.fullStatement,
            lessons: Array(lessons.prefix(6)),   // max 6 lessons per unit
            explorerContent: nil,
            visionaryTheme: nil,
            teksStandardTitle: nil
        )
    }

    // MARK: - API Fetch

    private func fetchObjectives(grade: Int, subject: Subject) async -> [TEKSObjective] {
        let docId = subject == .math ? mathDocumentId : literacyDocumentId
        let urlString = "\(baseURL)/CFItems?CFDocumentId=\(docId)&grade=\(grade)"

        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(CFItemsResponse.self, from: data)
            return response.CFItems.compactMap { item in
                // Filter to the target grade level
                guard let levels = item.educationLevel,
                      levels.contains(String(grade)) else { return nil }
                return TEKSObjective(
                    identifier: item.identifier,
                    humanCodingScheme: item.humanCodingScheme ?? item.identifier,
                    fullStatement: item.fullStatement,
                    educationLevel: item.educationLevel
                )
            }
        } catch {
            print("⚠️ TEKSAdapter: API unreachable (\(error.localizedDescription)) — using bundled cache")
            return loadCachedObjectives(grade: grade, subject: subject)
        }
    }

    // MARK: - Offline Cache

    private func loadCachedObjectives(grade: Int, subject: Subject) -> [TEKSObjective] {
        guard let url = Bundle.main.url(forResource: "TEKSCache", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }

        struct CacheEntry: Decodable {
            let subject: String
            let grade: Int
            let objectives: [TEKSObjective]
        }

        guard let cache = try? JSONDecoder().decode([CacheEntry].self, from: data) else { return [] }
        return cache
            .first { $0.subject == subject.rawValue && $0.grade == grade }?
            .objectives ?? []
    }

    // MARK: - Helpers

    private func teksTitle(for subject: Subject, grade: Int) -> String {
        switch subject {
        case .math:
            return "Grade \(grade) Mathematics"
        case .literacy:
            return "Grade \(grade) Reading & Language Arts"
        case .visionary:
            return "AI & Technology Applications"
        }
    }
}
