// AppState.swift
// Kzu — Core State Machine

import SwiftUI
import Combine
import UserNotifications
import ActivityKit

// MARK: - App Phase

enum AppPhase: String, Codable {
    case idle
    case requestingAuth
    case onboarding
    case learningBlock
    case explorerMode
    case gameHub
}

// MARK: - Reward Tier

enum RewardTier: String, Codable {
    case standard
    case goldenKey
}

// MARK: - Constants

enum KzuConstants {
    static let learningBlockDuration: TimeInterval = 25 * 60  // 25 minutes
    static let gameHubDuration: TimeInterval = 5 * 60          // 5 minutes
    static let backgroundGracePeriod: TimeInterval = 20        // 20 seconds
    static let appGroupIdentifier = "group.com.006kzu.shared"
}

// MARK: - App State Manager

@Observable
final class AppStateManager {
    // MARK: Published State
    var currentPhase: AppPhase = .idle
    var timeRemaining: TimeInterval = KzuConstants.learningBlockDuration
    var rewardTier: RewardTier = .standard
    var sessionsCompletedToday: Int = 0
    var totalResets: Int = 0

    // Session pause state (for dashboard countdown)
    var isSessionPaused: Bool = false
    var dashboardCountdown: TimeInterval = 0
    private var savedTimeRemaining: TimeInterval = 0
    private var savedPhase: AppPhase = .idle
    private var dashboardTimer: AnyCancellable?

    // MARK: Internal
    private var timer: AnyCancellable?
    private var backgroundTimestamp: Date?
    private var isTimerRunning = false

    /// The currently running Live Activity (nil when inactive).
    private var liveActivity: Activity<KzuLiveActivityAttributes>?

    // For App Group shared state with extensions
    private let sharedDefaults = UserDefaults(suiteName: KzuConstants.appGroupIdentifier)

    // MARK: - Phase Transitions

    func beginFlow() {
        guard currentPhase == .idle || currentPhase == .onboarding else { return }
        transitionTo(.learningBlock)
    }

    func transitionTo(_ phase: AppPhase) {
        let previousPhase = currentPhase

        withAnimation(.easeInOut(duration: 0.6)) {
            currentPhase = phase
        }

        switch phase {
        case .idle:
            if !isSessionPaused {
                stopTimer()
            }

        case .requestingAuth:
            stopTimer()

        case .onboarding:
            stopTimer()

        case .learningBlock:
            timeRemaining = KzuConstants.learningBlockDuration
            rewardTier = .standard
            startTimer(duration: KzuConstants.learningBlockDuration) { [weak self] in
                self?.onLearningBlockComplete()
            }
            syncSharedState(phase: .learningBlock)

        case .explorerMode:
            // Timer continues from learningBlock — don't reset
            break

        case .gameHub:
            timeRemaining = KzuConstants.gameHubDuration
            startTimer(duration: KzuConstants.gameHubDuration) { [weak self] in
                self?.onGameHubComplete()
            }
            syncSharedState(phase: .gameHub)
        }
    }

    // MARK: - Timer

    private func startTimer(duration: TimeInterval, onComplete: @escaping () -> Void) {
        stopTimer()
        isTimerRunning = true
        timeRemaining = duration

        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isTimerRunning else { return }
                self.timeRemaining -= 1

                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.stopTimer()
                    onComplete()
                }
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        isTimerRunning = false
    }

    // MARK: - Learning Block Completion

    private func onLearningBlockComplete() {
        sessionsCompletedToday += 1
        transitionTo(.gameHub)
    }

    // MARK: - Game Hub Completion

    private func onGameHubComplete() {
        // Cycle back — the Pomodoro continues
        transitionTo(.learningBlock)
    }

    /// DEV ONLY: Skip the timer to trigger game hub
    func devSkipTimer() {
        timeRemaining = 0
        stopTimer()
        if currentPhase == .learningBlock || currentPhase == .explorerMode {
            onLearningBlockComplete()
        } else if currentPhase == .gameHub {
            onGameHubComplete()
        }
    }

    // MARK: - Flow Freeze (FocusFlow inactivity monitor)

    /// Stored completion callback so we can restart the exact same timer after unfreeze.
    private var frozenOnComplete: (() -> Void)?

    /// Pauses the Pomodoro timer **in-place** for the Flow Freeze state.
    /// Does NOT trigger the 20s dashboard countdown — the session stays alive.
    func pauseForFlowFreeze() {
        guard isTimerRunning else { return }
        frozenOnComplete = currentPhase == .gameHub
            ? { [weak self] in self?.onGameHubComplete() }
            : { [weak self] in self?.onLearningBlockComplete() }
        stopTimer()
    }

    /// Resumes the Pomodoro timer from exactly where it was frozen.
    func resumeFromFlowFreeze() {
        guard !isTimerRunning, let completion = frozenOnComplete else { return }
        frozenOnComplete = nil
        startTimer(duration: timeRemaining, onComplete: completion)
    }

    // MARK: - Session Pause / Resume

    /// Pauses the current session and starts a 20s dashboard countdown.
    /// Shields stay active. The learning timer is frozen.
    func pauseSession() {
        guard currentPhase == .learningBlock || currentPhase == .explorerMode || currentPhase == .gameHub else { return }
        savedTimeRemaining = timeRemaining
        savedPhase = currentPhase
        isSessionPaused = true
        dashboardCountdown = KzuConstants.backgroundGracePeriod
        stopTimer()

        // Start the 20-second dashboard countdown
        dashboardTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.dashboardCountdown -= 1
                if self.dashboardCountdown <= 0 {
                    self.dashboardCountdown = 0
                    self.expirePausedSession()
                }
            }

        transitionTo(.idle)
    }

    /// Resumes the paused session, restoring the learning timer.
    func resumeSession() {
        guard isSessionPaused else { return }
        dashboardTimer?.cancel()
        dashboardTimer = nil
        isSessionPaused = false
        timeRemaining = savedTimeRemaining

        // Restart the timer from where we left off
        currentPhase = savedPhase
        if savedPhase == .gameHub {
            startTimer(duration: timeRemaining) { [weak self] in
                self?.onGameHubComplete()
            }
        } else {
            startTimer(duration: timeRemaining) { [weak self] in
                self?.onLearningBlockComplete()
            }
        }
        syncSharedState(phase: savedPhase)
    }

    /// Fully ends the session (used with Face ID verification).
    /// Clears shields and stops monitoring.
    func endSession() {
        dashboardTimer?.cancel()
        dashboardTimer = nil
        isSessionPaused = false
        dashboardCountdown = 0
        stopTimer()
        // Shields will be cleared by the caller
    }

    /// Called when the 20s dashboard countdown expires
    private func expirePausedSession() {
        dashboardTimer?.cancel()
        dashboardTimer = nil
        isSessionPaused = false
        dashboardCountdown = 0
        totalResets += 1
        timeRemaining = KzuConstants.learningBlockDuration
        // Session ends — shields stay active but timer resets
    }

    // MARK: - Reset Penalty

    /// Called when the DeviceActivityMonitor detects the app was backgrounded > 10s
    func applyResetPenalty() {
        guard currentPhase == .learningBlock || currentPhase == .explorerMode else { return }
        totalResets += 1
        timeRemaining = KzuConstants.learningBlockDuration
        syncSharedState(phase: .learningBlock)
    }

    // MARK: - Background Detection

    func appDidEnterBackground() {
        backgroundTimestamp = Date()
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "lastBackgroundTimestamp")

        // Start a Live Activity (with notification fallback) if in a learning phase
        if currentPhase == .learningBlock || currentPhase == .explorerMode {
            startLiveActivity()
        }
    }

    func appWillEnterForeground() {
        guard let bgTimestamp = backgroundTimestamp else { return }
        let elapsed = Date().timeIntervalSince(bgTimestamp)
        backgroundTimestamp = nil

        // Dismiss the Live Activity (and any fallback notifications)
        endLiveActivity()

        if (currentPhase == .learningBlock || currentPhase == .explorerMode)
            && elapsed > KzuConstants.backgroundGracePeriod {
            applyResetPenalty()
        }
    }

    // MARK: - Background Reminder (Live Activity + Notification Fallback)

    private static let backgroundReminderIdentifier = "kzu.backgroundReminder"

    /// Requests notification permission (call early in app lifecycle).
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: Live Activity

    /// Starts a Live Activity showing the 20-second countdown on the Lock Screen
    /// and Dynamic Island. Falls back to a standard notification on devices that
    /// don't support Live Activities (iPads, older iPhones).
    private func startLiveActivity() {
        // ── Live Activity path ─────────────────────────────────────────────
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            let deadline = Date.now.addingTimeInterval(KzuConstants.backgroundGracePeriod)
            let state = KzuLiveActivityAttributes.ContentState(
                deadline: deadline,
                totalSeconds: KzuConstants.backgroundGracePeriod
            )
            let content = ActivityContent(
                state: state,
                staleDate: deadline.addingTimeInterval(5) // auto-stale 5s after deadline
            )
            do {
                liveActivity = try Activity.request(
                    attributes: KzuLiveActivityAttributes(),
                    content: content,
                    pushType: nil   // timer-based, no push updates needed
                )
                print("▶︎ Kzu Live Activity started: \(liveActivity?.id ?? "unknown")")

                // Fire an immediate alert so a persistent banner appears on the
                // home screen with a live countdown — without this the activity
                // is silent on the lock screen only.
                if let activity = liveActivity {
                    Task {
                        let alert = AlertConfiguration(
                            title: "Come back! 📚",
                            body: "You have 20 seconds before your session resets.",
                            sound: .default
                        )
                        await activity.update(
                            ActivityContent(state: state, staleDate: deadline.addingTimeInterval(5)),
                            alertConfiguration: alert
                        )
                    }
                }
            } catch {
                print("⚠️ Kzu Live Activity error: \(error) — falling back to notification")
                scheduleNotificationFallback()
            }
        } else {
            // ── Notification fallback (iPad / older iPhone) ────────────────
            scheduleNotificationFallback()
        }
    }

    /// Ends the currently running Live Activity immediately.
    private func endLiveActivity() {
        guard let activity = liveActivity else {
            // No active Live Activity — cancel any pending fallback notifications
            cancelNotificationFallback()
            return
        }
        let finalState = activity.content.state
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            print("■ Kzu Live Activity ended")
        }
        liveActivity = nil
        cancelNotificationFallback()
    }

    // MARK: Notification Fallback

    private func scheduleNotificationFallback() {
        let center = UNUserNotificationCenter.current()

        let immediateContent = UNMutableNotificationContent()
        immediateContent.title = "Come back! 📚"
        immediateContent.body = "You have 20 seconds to return before your timer resets!"
        immediateContent.sound = .default
        immediateContent.interruptionLevel = .timeSensitive

        let immediateTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let immediateRequest = UNNotificationRequest(
            identifier: Self.backgroundReminderIdentifier,
            content: immediateContent,
            trigger: immediateTrigger
        )

        let urgentContent = UNMutableNotificationContent()
        urgentContent.title = "⚠️ Hurry back!"
        urgentContent.body = "Only 5 seconds left before your timer resets!"
        urgentContent.sound = UNNotificationSound.defaultCritical
        urgentContent.interruptionLevel = .timeSensitive

        let urgentTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 15, repeats: false)
        let urgentRequest = UNNotificationRequest(
            identifier: "\(Self.backgroundReminderIdentifier).urgent",
            content: urgentContent,
            trigger: urgentTrigger
        )

        center.add(immediateRequest) { error in
            if let error { print("⚠️ Kzu notification error: \(error)") }
        }
        center.add(urgentRequest) { error in
            if let error { print("⚠️ Kzu urgent notification error: \(error)") }
        }
    }

    private func cancelNotificationFallback() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                Self.backgroundReminderIdentifier,
                "\(Self.backgroundReminderIdentifier).urgent"
            ])
    }

    // MARK: - Explorer Mode

    func transitionToExplorerMode() {
        guard currentPhase == .learningBlock else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            currentPhase = .explorerMode
        }
        // Timer continues counting down — no reset
    }

    // MARK: - Reward Tier Update

    func updateRewardTier(_ tier: RewardTier) {
        rewardTier = tier
    }

    // MARK: - Shared State (App Group)

    private func syncSharedState(phase: AppPhase) {
        sharedDefaults?.set(phase.rawValue, forKey: "currentPhase")
        sharedDefaults?.set(timeRemaining, forKey: "timeRemaining")
        sharedDefaults?.set(Date().timeIntervalSince1970, forKey: "lastSync")
    }

    // MARK: - Formatted Time

    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        let total = currentPhase == .gameHub
            ? KzuConstants.gameHubDuration
            : KzuConstants.learningBlockDuration
        return 1.0 - (timeRemaining / total)
    }

    var phaseLabel: String {
        switch currentPhase {
        case .idle:           return "Ready to Begin"
        case .requestingAuth: return "Seeking Permission"
        case .onboarding:     return "Setting Your Path"
        case .learningBlock:  return "In Your Flow"
        case .explorerMode:   return "Exploring Freely"
        case .gameHub:        return "Rest & Reflect"
        }
    }
}
