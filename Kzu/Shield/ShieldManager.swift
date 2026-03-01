// ShieldManager.swift
// Kzu — FamilyControls / ManagedSettings Shield Toggling

import Foundation
import ManagedSettings
import FamilyControls
import DeviceActivity

// MARK: - Shield Manager

/// Manages the application-level shielding of "distraction" apps using Apple's
/// ManagedSettings framework. This class is the single point of control for
/// applying and removing app restrictions.
///
/// Architecture note: The `ManagedSettingsStore` persists across app terminations.
/// Once shields are applied, they remain in effect even if Kzu is killed, until
/// explicitly cleared. This is critical for the Pomodoro enforcement model.
final class ShieldManager {

    // MARK: - Properties

    /// The managed settings store for the main app target.
    /// Using the default store so it persists system-wide.
    private let store = ManagedSettingsStore()

    /// Cached selection from the FamilyActivityPicker
    private var currentSelection: FamilyActivitySelection?

    /// App Group shared defaults for extension communication
    private let sharedDefaults = UserDefaults(suiteName: KzuConstants.appGroupIdentifier)

    /// Whether shields are currently active
    var isShielded: Bool {
        sharedDefaults?.bool(forKey: "shieldsActive") ?? false
    }

    // MARK: - Initialization

    init() {
        // Restore any cached selection
        if let data = sharedDefaults?.data(forKey: "familyActivitySelection"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            currentSelection = selection
        }
    }

    // MARK: - Apply Shields

    /// Applies shields to the user-selected distraction apps.
    /// Call this at the start of every `LEARNING_BLOCK`.
    ///
    /// - Parameter selection: The `FamilyActivitySelection` from the parent's
    ///   `FamilyActivityPicker` configuration. If nil, uses the cached selection.
    /// - Throws: If no selection is available.
    func applyShields(for selection: FamilyActivitySelection? = nil) throws {
        let activeSelection = selection ?? currentSelection

        guard let activeSelection else {
            throw ShieldError.noAppsSelected
        }

        // Cache the selection for future use and extension access
        currentSelection = activeSelection
        if let data = try? JSONEncoder().encode(activeSelection) {
            sharedDefaults?.set(data, forKey: "familyActivitySelection")
        }

        // Apply shields to individual apps
        store.shield.applications = activeSelection.applicationTokens.isEmpty
            ? nil
            : activeSelection.applicationTokens

        // Apply shields to app categories
        store.shield.applicationCategories = activeSelection.categoryTokens.isEmpty
            ? nil
            : ShieldSettings.ActivityCategoryPolicy.specific(activeSelection.categoryTokens)

        // Apply web domain shields if any
        store.shield.webDomains = activeSelection.webDomainTokens.isEmpty
            ? nil
            : activeSelection.webDomainTokens

        // Persist shield state
        sharedDefaults?.set(true, forKey: "shieldsActive")
    }

    // MARK: - Clear Shields

    /// Removes all shields, granting full access to previously blocked apps.
    /// Call this when the `LEARNING_BLOCK` timer completes successfully.
    func clearShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil

        sharedDefaults?.set(false, forKey: "shieldsActive")
    }

    // MARK: - Update Selection

    /// Updates the cached app selection without immediately applying shields.
    /// Used when the parent modifies the distraction list from the dashboard.
    func updateSelection(_ selection: FamilyActivitySelection) {
        currentSelection = selection
        if let data = try? JSONEncoder().encode(selection) {
            sharedDefaults?.set(data, forKey: "familyActivitySelection")
        }
    }

    // MARK: - Query

    /// Returns the number of currently shielded application tokens.
    var shieldedAppCount: Int {
        currentSelection?.applicationTokens.count ?? 0
    }

    /// Returns the number of shielded categories.
    var shieldedCategoryCount: Int {
        currentSelection?.categoryTokens.count ?? 0
    }
}

// MARK: - Shield Error

enum ShieldError: LocalizedError {
    case noAppsSelected
    case authorizationDenied
    case storeUnavailable

    var errorDescription: String? {
        switch self {
        case .noAppsSelected:
            return "No distraction apps have been selected. Please ask a parent to configure the app list."
        case .authorizationDenied:
            return "Screen Time permission was not granted. Kzu needs this to protect your focus."
        case .storeUnavailable:
            return "Unable to access the settings store. Please restart Kzu."
        }
    }
}
