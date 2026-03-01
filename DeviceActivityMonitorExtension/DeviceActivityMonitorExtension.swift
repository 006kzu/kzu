// DeviceActivityMonitorExtension.swift
// Kzu — Background timer enforcement & reset penalty detection

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

// MARK: - Device Activity Monitor Extension

/// This extension runs as a separate process and survives app termination.
/// It monitors the DeviceActivity schedule and enforces the Pomodoro cycle
/// even when the main Kzu app is killed or backgrounded.
///
/// Key responsibilities:
/// 1. Track when the learning block interval starts/ends
/// 2. Clear ManagedSettings shields when the interval completes
/// 3. Detect when the app has been backgrounded > 10s (reset penalty)
class KzuDeviceActivityMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()
    private let sharedDefaults = UserDefaults(suiteName: "group.com.kzu.shared")

    // MARK: - Interval Lifecycle

    /// Called when a scheduled DeviceActivity interval begins.
    /// This corresponds to the start of a LEARNING_BLOCK.
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        // Ensure shields are active
        applyShieldsFromCache()

        // Log the learning block start
        sharedDefaults?.set("learningBlock", forKey: "currentPhase")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "intervalStartTime")
        sharedDefaults?.set(false, forKey: "resetPending")
    }

    /// Called when a scheduled DeviceActivity interval ends.
    /// This corresponds to the completion of a LEARNING_BLOCK (25 minutes elapsed).
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        // Clear all shields — the child has earned their break
        clearAllShields()

        // Signal the main app to transition to GAME_HUB
        sharedDefaults?.set("gameHub", forKey: "currentPhase")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "gameHubStartTime")

        // Post notification for the main app
        postAppNotification(name: "KzuGameHubUnlocked")
    }

    // MARK: - Event Callbacks

    /// Called when a monitored event's threshold is reached.
    /// We use this to detect if the user has been away from the app too long.
    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)

        // Check if this is the background penalty event
        if event.rawValue == "backgroundPenalty" {
            applyResetPenalty()
        }
    }

    // MARK: - Shield Management

    /// Re-applies shields from the cached FamilyActivitySelection
    private func applyShieldsFromCache() {
        guard let data = sharedDefaults?.data(forKey: "familyActivitySelection"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }

        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = ShieldSettings
                .ActivityCategoryPolicy.specific(selection.categoryTokens)
        }

        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }

        sharedDefaults?.set(true, forKey: "shieldsActive")
    }

    /// Clears all managed settings shields
    private func clearAllShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        sharedDefaults?.set(false, forKey: "shieldsActive")
    }

    // MARK: - Reset Penalty

    /// Applies the timer reset penalty.
    /// This writes a flag that the main app reads on resume.
    private func applyResetPenalty() {
        sharedDefaults?.set(true, forKey: "resetPending")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "resetTimestamp")

        // Re-apply shields (they should still be active during reset)
        applyShieldsFromCache()

        // Post notification
        postAppNotification(name: "KzuResetPenalty")
    }

    // MARK: - Notifications

    /// Posts a Darwin notification that the main app can observe
    private func postAppNotification(name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

// MARK: - DeviceActivity Schedule Helper

/// Utility to create the DeviceActivity schedule for a learning block.
/// Called from the main app when starting a new Pomodoro session.
enum KzuActivitySchedule {

    static let activityName = DeviceActivityName("kzu.learningBlock")
    static let backgroundPenaltyEvent = DeviceActivityEvent.Name("backgroundPenalty")

    /// Creates and starts monitoring a 25-minute learning block.
    static func startLearningBlock() throws {
        let center = DeviceActivityCenter()
        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())

        // Schedule ends 25 minutes from now
        var endComponents = now
        let totalSeconds = (now.minute ?? 0) * 60 + (now.second ?? 0) + 25 * 60
        endComponents.hour = (now.hour ?? 0) + totalSeconds / 3600
        endComponents.minute = (totalSeconds % 3600) / 60
        endComponents.second = totalSeconds % 60

        let schedule = DeviceActivitySchedule(
            intervalStart: now,
            intervalEnd: endComponents,
            repeats: false
        )

        try center.startMonitoring(activityName, during: schedule)
    }

    /// Stops all monitoring
    static func stopMonitoring() {
        let center = DeviceActivityCenter()
        center.stopMonitoring([activityName])
    }
}
