// EarlyEdAdapter.swift
// Kzu — Local JSON loader for Pre-K / Kindergarten math content

import Foundation

/// Loads offline JSON modules for foundational grades (e.g. GK Mod 1)
final class EarlyEdAdapter {
    private var cachedUnits: [CurriculumUnit] = []

    init() {
        loadBundledData()
    }

    private func loadBundledData() {
        // Try reading from EarlyEdMath_GK_Mod1.json
        guard let url = Bundle.main.url(forResource: "EarlyEdMath_GK_Mod1", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("EarlyEdAdapter: Could not find EarlyEdMath_GK_Mod1.json in bundle")
            return
        }

        do {
            let decoder = JSONDecoder()
            let units = try decoder.decode([CurriculumUnit].self, from: data)
            self.cachedUnits = units
            print("EarlyEdAdapter: Successfully loaded \(units.count) foundational math units.")
        } catch {
            print("EarlyEdAdapter: Error decoding JSON: \(error)")
        }
    }
    
    /// Returns a unit matching the grade and subject, or a random foundational unit
    func fetchUnit(for grade: Int, subject: Subject) -> CurriculumUnit? {
        // Currently only handles foundational math grade 0
        let matches = cachedUnits.filter { unit in
            unit.subject == subject && unit.gradeRange.contains(grade)
        }
        return matches.first ?? cachedUnits.first
    }
}
