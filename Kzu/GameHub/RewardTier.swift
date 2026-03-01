// RewardTier.swift
// Kzu — Standard vs Golden Key reward system

import Foundation

// Note: The RewardTier enum is defined in AppState.swift.
// This file contains reward-related logic and descriptions.

// MARK: - Reward Description

extension RewardTier {
    var displayName: String {
        switch self {
        case .standard:  return "Standard Pass"
        case .goldenKey: return "Golden Key"
        }
    }

    var icon: String {
        switch self {
        case .standard:  return "ticket"
        case .goldenKey: return "key.fill"
        }
    }

    var description: String {
        switch self {
        case .standard:
            return "Enjoy the games at your leisure."
        case .goldenKey:
            return "Your mastery has unlocked premium skins and special powers."
        }
    }

    /// Whether this tier grants access to premium game skins
    var hasPremiumSkins: Bool {
        self == .goldenKey
    }

    /// Whether this tier grants "God Mode" in mini-games
    var hasGodMode: Bool {
        self == .goldenKey
    }
}
