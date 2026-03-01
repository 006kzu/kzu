// RhythmFlowScene.swift
// Kzu — Rhythm/music mini-game: tap to the beat

import SpriteKit

// MARK: - Rhythm Flow Scene

/// A minimal rhythm game where orbs pulse in patterns and the child
/// taps in sync. Focus on rhythm, timing, and flow state —
/// a musical meditation rather than a competitive game.
class RhythmFlowScene: KzuGameScene {

    private var pulseNodes: [SKShapeNode] = []
    private var beatInterval: TimeInterval = 1.2
    private var lastBeatTime: TimeInterval = 0
    private var score = 0
    private var scoreLabel: SKLabelNode?

    private let orbColors: [UIColor] = [
        UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1.0),
        UIColor(red: 0.55, green: 0.42, blue: 0.58, alpha: 1.0),
        UIColor(red: 0.85, green: 0.68, blue: 0.32, alpha: 1.0),
    ]

    override func setupGame() {
        backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.22, alpha: 1.0)

        // Score label
        let label = SKLabelNode(fontNamed: "SFRounded-Thin")
        label.fontSize = 24
        label.fontColor = UIColor(Color.kzuIvory).withAlphaComponent(0.4)
        label.position = CGPoint(x: size.width / 2, y: size.height - 90)
        label.zPosition = 50
        addChild(label)
        scoreLabel = label

        // Create initial pulse circles
        let positions = [
            CGPoint(x: size.width * 0.25, y: size.height * 0.4),
            CGPoint(x: size.width * 0.50, y: size.height * 0.55),
            CGPoint(x: size.width * 0.75, y: size.height * 0.4),
        ]

        for (i, pos) in positions.enumerated() {
            let orb = createOrb(color: orbColors[i], position: pos)
            addChild(orb)
            pulseNodes.append(orb)
        }

        // Ambient ring
        let ring = SKShapeNode(circleOfRadius: size.width * 0.35)
        ring.strokeColor = UIColor(Color.kzuIvory).withAlphaComponent(0.05)
        ring.fillColor = .clear
        ring.lineWidth = 1
        ring.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        ring.zPosition = 0
        addChild(ring)

        // Instruction
        let instruction = SKLabelNode(fontNamed: "SFRounded-Regular")
        instruction.text = "tap when the orbs glow"
        instruction.fontSize = 14
        instruction.fontColor = UIColor(Color.kzuIvory).withAlphaComponent(0.3)
        instruction.position = CGPoint(x: size.width / 2, y: 80)
        addChild(instruction)

        instruction.run(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.fadeOut(withDuration: 1.0),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Create Orb

    private func createOrb(color: UIColor, position: CGPoint) -> SKShapeNode {
        let orb = SKShapeNode(circleOfRadius: 30)
        orb.fillColor = color.withAlphaComponent(0.3)
        orb.strokeColor = color.withAlphaComponent(0.6)
        orb.lineWidth = 2
        orb.position = position
        orb.zPosition = 10
        orb.name = "orb"

        // Glow
        let glow = SKShapeNode(circleOfRadius: 40)
        glow.fillColor = color.withAlphaComponent(0.1)
        glow.strokeColor = .clear
        glow.name = "glow"
        orb.addChild(glow)

        return orb
    }

    // MARK: - Beat System

    override func updateGame(delta: TimeInterval) {
        lastBeatTime += delta

        if lastBeatTime >= beatInterval {
            lastBeatTime = 0
            triggerBeat()
        }

        scoreLabel?.text = "\(score)"
    }

    private func triggerBeat() {
        // Pick a random orb to pulse
        guard let orb = pulseNodes.randomElement() else { return }

        orb.userData = ["active": true]

        // Pulse animation
        let pulse = SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.3, duration: beatInterval * 0.3),
                SKAction.run {
                    orb.fillColor = orb.strokeColor?.withAlphaComponent(0.7) ?? .white
                    orb.childNode(withName: "glow")?.run(
                        SKAction.fadeAlpha(to: 0.4, duration: beatInterval * 0.3)
                    )
                }
            ]),
            SKAction.group([
                SKAction.scale(to: 1.0, duration: beatInterval * 0.5),
                SKAction.run {
                    orb.fillColor = orb.strokeColor?.withAlphaComponent(0.3) ?? .white
                    orb.childNode(withName: "glow")?.run(
                        SKAction.fadeAlpha(to: 0.1, duration: beatInterval * 0.5)
                    )
                }
            ]),
            SKAction.run {
                orb.userData = ["active": false]
            }
        ])

        orb.run(pulse, withKey: "beat")
    }

    // MARK: - Touch

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        for orb in pulseNodes {
            let distance = hypot(location.x - orb.position.x, location.y - orb.position.y)

            if distance < 50 {
                let isActive = (orb.userData?["active"] as? Bool) ?? false

                if isActive {
                    // Hit! Satisfying feedback
                    score += 1
                    showHitEffect(at: orb.position, color: orb.strokeColor ?? .white)
                } else {
                    // Gentle ripple for off-beat taps (no punishment)
                    showRipple(at: orb.position)
                }
                break
            }
        }
    }

    // MARK: - Effects

    private func showHitEffect(at position: CGPoint, color: UIColor) {
        // Expanding ring
        let ring = SKShapeNode(circleOfRadius: 30)
        ring.strokeColor = color
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.position = position
        ring.zPosition = 20
        addChild(ring)

        ring.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 3.0, duration: 0.5),
                SKAction.fadeOut(withDuration: 0.5)
            ]),
            SKAction.removeFromParent()
        ]))

        // Particle burst
        for _ in 0..<6 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = color
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 15
            addChild(particle)

            let angle = CGFloat.random(in: 0 ... .pi * 2)
            let distance = CGFloat.random(in: 40...80)
            let target = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )

            particle.run(SKAction.sequence([
                SKAction.group([
                    SKAction.move(to: target, duration: 0.4),
                    SKAction.fadeOut(withDuration: 0.4),
                    SKAction.scale(to: 0.1, duration: 0.4)
                ]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func showRipple(at position: CGPoint) {
        let ripple = SKShapeNode(circleOfRadius: 20)
        ripple.strokeColor = UIColor(Color.kzuIvory).withAlphaComponent(0.2)
        ripple.fillColor = .clear
        ripple.lineWidth = 1
        ripple.position = position
        ripple.zPosition = 15
        addChild(ripple)

        ripple.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 2.0, duration: 0.4),
                SKAction.fadeOut(withDuration: 0.4)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Wind Down

    override func onWindDown() {
        // Slow the beat
        run(SKAction.customAction(withDuration: 20) { [weak self] _, elapsed in
            self?.beatInterval = 1.2 + Double(elapsed) * 0.1  // Gradually slower
        })

        // Dim orbs
        for orb in pulseNodes {
            orb.run(SKAction.fadeAlpha(to: 0.4, duration: 15.0))
        }
    }
}
