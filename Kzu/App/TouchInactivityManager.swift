// TouchInactivityManager.swift
// Kzu — FocusFlow Humanist Inactivity Monitor
//
// Detects "zoning out" during a .learningBlock session and guides
// the student back through three progressive states:
//   .active → .ambientFade → .focusCheck(secondsLeft) → .flowFreeze

import SwiftUI
import Combine
import AVFoundation
import UIKit

// MARK: - Inactivity State

enum InactivityState: Equatable {
    case active
    case ambientFade
    case focusCheck(Int)   // seconds remaining in the 20s check window
    case flowFreeze
}

// MARK: - Touch Inactivity Manager

@Observable
final class TouchInactivityManager {

    // MARK: Public State
    var state: InactivityState = .active

    // MARK: Configuration
    static let baseAmbientFadeThreshold: TimeInterval = 120  // initial idle → fade (2 min)
    static let minimumThreshold:         TimeInterval = 45   // floor: never shorter than 45s
    static let thresholdReduction:       TimeInterval = 20   // shorten by 20s each strike
    static let focusCheckDuration:  TimeInterval   = 20    // seconds to respond
    static let dimmedBrightness:    CGFloat         = 0.25 // screen brightness floor
    static let dimmedAudioVolume:   Float           = 0.20 // audio volume floor

    // MARK: Private — Timer
    private var elapsedSeconds: Int = 0
    private var focusCheckSecondsLeft: Int = Int(focusCheckDuration)
    private var tickCancellable: AnyCancellable?

    /// Number of times the user has let the screen dim this session.
    /// Each occurrence shortens the next idle threshold.
    private(set) var consecutiveTriggers: Int = 0

    /// The computed idle threshold for the current cycle (shrinks each strike).
    private var currentThreshold: Int {
        let reduced = Self.baseAmbientFadeThreshold - Double(consecutiveTriggers) * Self.thresholdReduction
        return Int(max(Self.minimumThreshold, reduced))
    }

    // MARK: Private — System refs
    private weak var appState: AppStateManager?
    private var audioPlayer: AVAudioPlayer?
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var hapticTimer: AnyCancellable?
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    // MARK: - Init

    init() {
        prepareAudio()
        softHaptic.prepare()
    }

    /// Call from LearningBlockView.onAppear to wire the app state reference.
    func configure(appState: AppStateManager) {
        self.appState = appState
    }

    // MARK: - Lifecycle

    /// Call from LearningBlockView.onAppear
    func start() {
        resetTimer()
    }

    /// Call from LearningBlockView.onDisappear
    func stop() {
        tickCancellable?.cancel()
        hapticTimer?.cancel()
        restoreBrightness()
        restoreAudioVolume()
        state = .active
        elapsedSeconds = 0
        consecutiveTriggers = 0   // reset escalation counter on session end
    }

    // MARK: - Touch / Interaction Reset

    /// Call on every user interaction (tap, scroll, text entry).
    func resetTimer() {
        elapsedSeconds = 0
        focusCheckSecondsLeft = Int(Self.focusCheckDuration)

        // If frozen, unfreeze first — recovery is handled by FlowFreezeOverlay
        // (this path covers taps that bubble through; the overlay handles its own CTA)
        if case .flowFreeze = state {
            return // let the overlay handle it
        }

        // Restore everything immediately
        if state != .active {
            // ── Escalate: this idle event counted as a strike ──────────────
            consecutiveTriggers += 1
            print("⚠️ Inactivity strike \(consecutiveTriggers) — next threshold: \(currentThreshold)s")

            withAnimation(.easeInOut(duration: 1.0)) {
                state = .active
            }
            restoreBrightness()
            restoreAudioVolume()
            hapticTimer?.cancel()
            appState?.resumeFromFlowFreeze()
        }

        // (Re)start the 1-second tick
        tickCancellable?.cancel()
        tickCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    // MARK: - State Machine Tick

    private func tick() {
        elapsedSeconds += 1

        // Use the dynamic (escalating) threshold for this cycle
        let threshold = currentThreshold
        let checkEnd  = threshold + Int(Self.focusCheckDuration)

        switch elapsedSeconds {

        case threshold:
            // ── State 1: Ambient Fade ─────────────────────────────────────
            withAnimation(.easeInOut(duration: 2.0)) {
                state = .ambientFade
            }
            fadeBrightness(to: Self.dimmedBrightness, duration: 2.0)
            fadeAudio(to: Self.dimmedAudioVolume, duration: 2.0)

        case (threshold + 1) ..< checkEnd:
            // ── State 2: Focus Check ──────────────────────────────────────
            let remaining = checkEnd - elapsedSeconds
            withAnimation(.easeInOut(duration: 0.4)) {
                state = .focusCheck(remaining)
            }
            scheduleHapticBeat()

        case checkEnd:
            // ── State 3: Flow Freeze ──────────────────────────────────────
            hapticTimer?.cancel()
            withAnimation(.easeInOut(duration: 0.6)) {
                state = .flowFreeze
            }
            appState?.pauseForFlowFreeze()
            tickCancellable?.cancel()

        default:
            break
        }
    }

    // MARK: - Haptic Beat (every 2s during Focus Check)

    private var lastHapticSecond = -1

    private func scheduleHapticBeat() {
        guard elapsedSeconds != lastHapticSecond,
              elapsedSeconds % 2 == 1 else { return }
        lastHapticSecond = elapsedSeconds
        softHaptic.impactOccurred(intensity: 0.6)
    }

    // MARK: - Recovery (called by FlowFreezeOverlay after long press)

    func recover() {
        elapsedSeconds = 0
        focusCheckSecondsLeft = Int(Self.focusCheckDuration)
        hapticTimer?.cancel()

        // Recovery from full freeze also counts as a strike
        consecutiveTriggers += 1
        print("⚠️ Flow Freeze recovered — strike \(consecutiveTriggers) — next threshold: \(currentThreshold)s")

        withAnimation(.easeInOut(duration: 0.8)) {
            state = .active
        }
        restoreBrightness()
        restoreAudioVolume()
        appState?.resumeFromFlowFreeze()

        // Restart the idle ticker
        tickCancellable?.cancel()
        tickCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    // MARK: - Screen Brightness

    private func fadeBrightness(to target: CGFloat, duration: TimeInterval) {
        originalBrightness = UIScreen.main.brightness
        let steps  = Int(duration * 10)
        let delta  = (target - originalBrightness) / CGFloat(steps)
        var step   = 0

        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { t in
            step += 1
            UIScreen.main.brightness += delta
            if step >= steps { t.invalidate() }
        }
    }

    private func restoreBrightness() {
        let current = UIScreen.main.brightness
        let target  = originalBrightness
        let steps   = 20
        let delta   = (target - current) / CGFloat(steps)
        var step    = 0

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            step += 1
            UIScreen.main.brightness += delta
            if step >= steps { t.invalidate() }
        }
    }

    // MARK: - Audio Volume

    private func prepareAudio() {
        guard let url = Bundle.main.url(forResource: "ambient_focus", withExtension: "mp3") else {
            // No audio file present — silent no-op
            return
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.numberOfLoops = -1  // loop forever
        audioPlayer?.volume = 1.0
        audioPlayer?.prepareToPlay()
    }

    private func fadeAudio(to target: Float, duration: TimeInterval) {
        guard let player = audioPlayer else { return }
        let steps = Int(duration * 10)
        let delta = (target - player.volume) / Float(steps)
        var step  = 0

        Timer.scheduledTimer(withTimeInterval: duration / Double(steps), repeats: true) { t in
            step += 1
            player.volume = max(0, min(1, player.volume + delta))
            if step >= steps { t.invalidate() }
        }
    }

    private func restoreAudioVolume() {
        guard let player = audioPlayer else { return }
        let target: Float = 1.0
        let steps = 20
        let delta = (target - player.volume) / Float(steps)
        var step  = 0

        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            step += 1
            player.volume = max(0, min(1, player.volume + delta))
            if step >= steps { t.invalidate() }
        }
    }
}
