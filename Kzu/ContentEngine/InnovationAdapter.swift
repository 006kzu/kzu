// InnovationAdapter.swift
// Kzu — Loads Visionary (AI/Robotics) lessons from the bundled local JSON database.
// All lessons carry Technology Applications TEKS standard IDs for parental transparency.

import Foundation

// MARK: - Innovation Adapter

/// Reads `VisionaryLessons.json` from the app bundle and vends `CurriculumUnit` values
/// for the Visionary subject path. No network calls — fully offline.
struct InnovationAdapter {

    // MARK: - Public API

    /// Returns all available Visionary units for a given grade range.
    func availableUnits(for grade: Int) -> [CurriculumUnit] {
        allUnits().filter { $0.gradeRange.contains(grade) || gradeInRange($0.gradeRange, grade: grade) }
    }

    /// Returns the first Visionary unit appropriate for the given grade,
    /// optionally filtered by theme.
    func fetchUnit(for grade: Int, theme: VisionaryTheme? = nil) -> CurriculumUnit? {
        var units = availableUnits(for: grade)
        if let theme {
            units = units.filter { $0.visionaryTheme == theme }
        }
        return units.first
    }

    /// Returns a random Visionary unit appropriate for the given grade.
    func randomUnit(for grade: Int) -> CurriculumUnit? {
        availableUnits(for: grade).randomElement()
    }

    // MARK: - Bundle Loading

    private func allUnits() -> [CurriculumUnit] {
        guard let url  = Bundle.main.url(forResource: "VisionaryLessons", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ InnovationAdapter: VisionaryLessons.json not found in bundle")
            return []
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode([CurriculumUnit].self, from: data)
        } catch {
            print("⚠️ InnovationAdapter: decode error — \(error)")
            return []
        }
    }

    // MARK: - Helpers

    /// A unit's gradeRange may be [3, 8] meaning grades 3–8 inclusive.
    private func gradeInRange(_ range: [Int], grade: Int) -> Bool {
        guard range.count >= 2 else { return range.contains(grade) }
        return grade >= range[0] && grade <= range[range.count - 1]
    }
}
