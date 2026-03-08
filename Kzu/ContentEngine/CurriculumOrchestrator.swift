// CurriculumOrchestrator.swift
// Kzu — Top-level router that pulls content from the correct adapter
// based on the requested Subject.

import Foundation

// MARK: - Curriculum Orchestrator

/// Single entry point for all curriculum fetching.
/// Routes to `TEKSAdapter` (standard) or `InnovationAdapter` (visionary).
final class CurriculumOrchestrator {

    private let teksAdapter       = TEKSAdapter()
    private let innovationAdapter = InnovationAdapter()
    private let earlyEdAdapter    = EarlyEdAdapter()
    private let supabaseAdapter   = SupabaseContentAdapter()

    // MARK: - Public API

    /// Fetch a curriculum unit for the given grade and subject.
    /// - Checks Supabase Cloud first (live updates)
    /// - Standard subjects (.literacy, .math): falls back to TEKSAdapter → Texas Gateway API with offline cache
    /// - Visionary subject (.visionary): falls back to InnovationAdapter → local VisionaryLessons.json
    ///
    /// Returns `nil` if no unit could be loaded (no network + no cache + no bundled fallback).
    func fetchUnit(for grade: Int, subject: Subject) async -> CurriculumUnit? {
        
        // 1. Always check Supabase first for live, over-the-air curriculum updates
        if let liveUnit = await supabaseAdapter.fetchUnit(for: grade, subject: subject) {
            return liveUnit
        }
        
        // 2. Fallbacks if Supabase is unreachable or has no matching row
        switch subject {
        case .visionary:
            return innovationAdapter.randomUnit(for: grade)

        case .literacy, .math:
            // Math Pre-K / K foundational JSON fallback
            if subject == .math && grade == 0,
               let earlyUnit = earlyEdAdapter.fetchUnit(for: grade, subject: subject) {
                return earlyUnit
            }

            // Try TEKSAdapter (live API + offline cache)
            if let unit = await teksAdapter.fetchUnit(for: grade, subject: subject) {
                return unit
            }
            // Final fallback: bundled sample curriculum (existing CDEngine behaviour)
            return nil
        }
    }

    /// Synchronous access to Visionary units — no async needed
    /// since all Visionary content is bundled locally.
    func visionaryUnits(for grade: Int) -> [CurriculumUnit] {
        innovationAdapter.availableUnits(for: grade)
    }
}
