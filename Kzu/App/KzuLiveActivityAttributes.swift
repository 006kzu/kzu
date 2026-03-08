// KzuLiveActivityAttributes.swift
// Kzu — ActivityKit Live Activity shared model
// Compiled into both the main app target and the KzuLiveActivityExtension.

import ActivityKit
import Foundation

/// The attributes that describe the Kzu background-grace-period Live Activity.
///
/// Static metadata: none (the grace period is always 20 seconds).
/// Dynamic content: the deadline date and the total seconds (for progress math).
public struct KzuLiveActivityAttributes: ActivityAttributes {

    // MARK: - Dynamic Content State

    public struct ContentState: Codable, Hashable {
        /// The exact moment the session will reset if the user doesn't return.
        /// Used with SwiftUI's `timerInterval`/`ProgressView(timerInterval:)` APIs
        /// so the OS keeps the countdown accurate without needing push updates.
        public var deadline: Date

        /// Total grace period in seconds (always KzuConstants.backgroundGracePeriod).
        /// Stored here so the extension can compute the progress fraction without
        /// importing the main app module.
        public var totalSeconds: Double
    }
}
