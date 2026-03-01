// GameScene.swift
// Kzu — Base SpriteKit scene with 5-minute lifecycle and graceful wind-down

import SpriteKit

// MARK: - Base Game Scene

/// Abstract base class for all Game Hub mini-games.
/// Enforces the 5-minute fixed-duration lifecycle and provides a graceful
/// wind-down at the 30-second mark.
class KzuGameScene: SKScene {

    // MARK: Properties
    var gameDuration: TimeInterval = KzuConstants.gameHubDuration  // 5 minutes
    var timeRemaining: TimeInterval = KzuConstants.gameHubDuration
    var rewardTier: RewardTier = .standard
    var isWindingDown = false

    private var lastUpdateTime: TimeInterval = 0
    private var timerLabel: SKLabelNode?
    private var windDownOverlay: SKShapeNode?

    // Callback when game time expires
    var onGameComplete: (() -> Void)?

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = UIColor(Color.kzuIvory)

        setupTimerDisplay()
        setupGame()
    }

    // MARK: - Timer Display

    private func setupTimerDisplay() {
        let timer = SKLabelNode(fontNamed: "SFRounded-Medium")
        timer.fontSize = 16
        timer.fontColor = UIColor(Color.kzuSoftNavy)
        timer.position = CGPoint(x: size.width / 2, y: size.height - 50)
        timer.zPosition = 100
        timer.name = "timerLabel"
        addChild(timer)
        timerLabel = timer
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // Count down
        timeRemaining -= delta

        // Update timer display
        let minutes = Int(max(0, timeRemaining)) / 60
        let seconds = Int(max(0, timeRemaining)) % 60
        timerLabel?.text = "rest & reflect · \(String(format: "%d:%02d", minutes, seconds))"

        // Wind-down at 30 seconds
        if timeRemaining <= 30 && !isWindingDown {
            isWindingDown = true
            beginWindDown()
        }

        // Game over
        if timeRemaining <= 0 {
            timeRemaining = 0
            endGame()
            return
        }

        // Subclass update
        updateGame(delta: delta)
    }

    // MARK: - Wind Down

    /// Triggers a graceful wind-down animation at 30 seconds remaining.
    /// The game should slow down, become quieter, and prepare the child
    /// for the transition back to learning.
    private func beginWindDown() {
        // Gentle vignette overlay
        let overlay = SKShapeNode(rectOf: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.fillColor = UIColor(Color.kzuDeepNavy.opacity(0.05))
        overlay.strokeColor = .clear
        overlay.zPosition = 90
        overlay.alpha = 0
        addChild(overlay)
        windDownOverlay = overlay

        overlay.run(SKAction.fadeAlpha(to: 0.4, duration: 10.0))

        // Update timer color
        timerLabel?.run(SKAction.colorize(
            with: UIColor(Color.kzuGold),
            colorBlendFactor: 1.0,
            duration: 2.0
        ))

        // Slow down scene
        run(SKAction.speed(to: 0.6, duration: 15.0))

        // Notify subclass
        onWindDown()
    }

    // MARK: - End Game

    private func endGame() {
        isPaused = true

        // "Rest and Reflect" message
        let endLabel = SKLabelNode(fontNamed: "SFRounded-Bold")
        endLabel.text = "Rest & Reflect"
        endLabel.fontSize = 28
        endLabel.fontColor = UIColor(Color.kzuDeepNavy)
        endLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        endLabel.zPosition = 200
        endLabel.alpha = 0
        addChild(endLabel)

        endLabel.run(SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.8),
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                self?.onGameComplete?()
            }
        ]))
    }

    // MARK: - Subclass Overrides

    /// Override to set up game-specific nodes and physics.
    func setupGame() {
        // Subclasses implement
    }

    /// Override for per-frame game logic.
    func updateGame(delta: TimeInterval) {
        // Subclasses implement
    }

    /// Override to respond to the wind-down phase (slow particles, quiet music, etc.)
    func onWindDown() {
        // Subclasses implement
    }
}
