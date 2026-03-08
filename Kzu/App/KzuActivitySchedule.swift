// KzuActivitySchedule.swift
// Kzu — DeviceActivity schedule helper (main app target)

import DeviceActivity
import Foundation

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
