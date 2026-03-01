// AppState.swift
// Kzu — Core State Machine

import SwiftUI
import Combine

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
    static let backgroundGracePeriod: TimeInterval = 10        // 10 seconds
    static let appGroupIdentifier = "group.com.kzu.shared"
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

    // MARK: Internal
    private var timer: AnyCancellable?
    private var backgroundTimestamp: Date?
    private var isTimerRunning = false

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
            stopTimer()

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
    }

    func appWillEnterForeground() {
        guard let bgTimestamp = backgroundTimestamp else { return }
        let elapsed = Date().timeIntervalSince(bgTimestamp)
        backgroundTimestamp = nil

        if (currentPhase == .learningBlock || currentPhase == .explorerMode)
            && elapsed > KzuConstants.backgroundGracePeriod {
            applyResetPenalty()
        }
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
