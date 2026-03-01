// ZenGardenScene.swift
// Kzu — Generative art mini-game: "Digital Zen"

import SpriteKit

// MARK: - Zen Garden Scene

/// A generative art experience where the child draws flowing patterns
/// that bloom into organic, meditative visuals. Physics-based particles
/// follow the touch, creating a living garden of color and light.
class ZenGardenScene: KzuGameScene {

    private var emitterNode: SKEmitterNode?
    private var trailNodes: [SKShapeNode] = []
    private var gardenColor: UIColor = UIColor(Color.kzuFlowBlue)
    private let colorPalette: [UIColor] = [
        UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1.0),  // Flow blue
        UIColor(red: 0.36, green: 0.72, blue: 0.48, alpha: 1.0),  // Garden green
        UIColor(red: 0.85, green: 0.68, blue: 0.32, alpha: 1.0),  // Gold
        UIColor(red: 0.55, green: 0.42, blue: 0.58, alpha: 1.0),  // Lavender
        UIColor(red: 0.92, green: 0.58, blue: 0.30, alpha: 1.0),  // Warm amber
    ]
    private var colorIndex = 0

    override func setupGame() {
        backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)

        // Ambient background particles
        if let ambient = createAmbientParticles() {
            ambient.position = CGPoint(x: size.width / 2, y: size.height / 2)
            ambient.zPosition = -1
            addChild(ambient)
        }

        // Instruction
        let instruction = SKLabelNode(fontNamed: "SFRounded-Regular")
        instruction.text = "touch to plant your garden"
        instruction.fontSize = 14
        instruction.fontColor = UIColor(Color.kzuSoftNavy).withAlphaComponent(0.5)
        instruction.position = CGPoint(x: size.width / 2, y: 80)
        instruction.name = "instruction"
        addChild(instruction)

        // Fade instruction after first touch
        instruction.run(SKAction.sequence([
            SKAction.wait(forDuration: 5.0),
            SKAction.fadeOut(withDuration: 2.0),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Cycle colors
        colorIndex = (colorIndex + 1) % colorPalette.count
        gardenColor = colorPalette[colorIndex]

        plantSeed(at: location)

        // Remove instruction on first touch
        childNode(withName: "instruction")?.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        drawTrail(at: location)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        bloomFlower(at: location)
    }

    // MARK: - Plant Seed

    private func plantSeed(at position: CGPoint) {
        let seed = SKShapeNode(circleOfRadius: 4)
        seed.fillColor = gardenColor
        seed.strokeColor = .clear
        seed.position = position
        seed.zPosition = 10
        addChild(seed)

        // Grow animation
        seed.run(SKAction.sequence([
            SKAction.scale(to: 2.0, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.2)
        ]))
    }

    // MARK: - Draw Trail

    private func drawTrail(at position: CGPoint) {
        let radius = CGFloat.random(in: 3...8)
        let trail = SKShapeNode(circleOfRadius: radius)
        trail.fillColor = gardenColor.withAlphaComponent(CGFloat.random(in: 0.3...0.7))
        trail.strokeColor = .clear
        trail.position = position
        trail.zPosition = 5
        addChild(trail)
        trailNodes.append(trail)

        // Organic drift + fade
        let drift = SKAction.moveBy(
            x: CGFloat.random(in: -20...20),
            y: CGFloat.random(in: 10...40),
            duration: Double.random(in: 3...6)
        )
        let fade = SKAction.fadeOut(withDuration: Double.random(in: 4...8))
        let scale = SKAction.scale(to: CGFloat.random(in: 0.3...1.5), duration: Double.random(in: 2...5))

        trail.run(SKAction.group([drift, fade, scale])) {
            trail.removeFromParent()
        }

        // Limit trail count for performance
        if trailNodes.count > 200 {
            trailNodes.first?.removeFromParent()
            trailNodes.removeFirst()
        }
    }

    // MARK: - Bloom Flower

    private func bloomFlower(at position: CGPoint) {
        let petalCount = Int.random(in: 5...8)
        let flowerRadius: CGFloat = CGFloat.random(in: 15...30)

        for i in 0..<petalCount {
            let angle = CGFloat(i) * (.pi * 2 / CGFloat(petalCount))
            let petal = SKShapeNode(ellipseOf: CGSize(width: flowerRadius * 0.6, height: flowerRadius))
            petal.fillColor = gardenColor.withAlphaComponent(0.6)
            petal.strokeColor = gardenColor.withAlphaComponent(0.3)
            petal.lineWidth = 1
            petal.position = position
            petal.zRotation = angle
            petal.zPosition = 8
            petal.alpha = 0
            petal.setScale(0.1)
            addChild(petal)

            let targetPos = CGPoint(
                x: position.x + cos(angle) * flowerRadius * 0.5,
                y: position.y + sin(angle) * flowerRadius * 0.5
            )

            let bloom = SKAction.group([
                SKAction.move(to: targetPos, duration: 0.5),
                SKAction.fadeIn(withDuration: 0.3),
                SKAction.scale(to: 1.0, duration: 0.5)
            ])
            bloom.timingMode = .easeOut

            let sway = SKAction.sequence([
                SKAction.rotate(byAngle: .pi / 16, duration: 2),
                SKAction.rotate(byAngle: -.pi / 16, duration: 2)
            ])

            petal.run(SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.05),
                bloom,
                SKAction.repeatForever(sway)
            ]))
        }

        // Center dot
        let center = SKShapeNode(circleOfRadius: 4)
        center.fillColor = UIColor(Color.kzuGold)
        center.strokeColor = .clear
        center.position = position
        center.zPosition = 9
        center.alpha = 0
        addChild(center)
        center.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.2)
        ]))
    }

    // MARK: - Ambient Particles

    private func createAmbientParticles() -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 2
        emitter.particleLifetime = 8
        emitter.particlePosition = .zero
        emitter.particlePositionRange = CGVector(dx: size.width, dy: size.height)
        emitter.particleSpeed = 5
        emitter.particleSpeedRange = 3
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi / 4
        emitter.particleAlpha = 0.1
        emitter.particleAlphaRange = 0.05
        emitter.particleAlphaSpeed = -0.01
        emitter.particleScale = 0.3
        emitter.particleScaleRange = 0.2
        emitter.particleColor = UIColor(Color.kzuFlowBlue)
        return emitter
    }

    // MARK: - Wind Down

    override func onWindDown() {
        // Slow particle birth rate
        enumerateChildNodes(withName: "//") { node, _ in
            if let emitter = node as? SKEmitterNode {
                emitter.run(SKAction.customAction(withDuration: 10) { node, elapsed in
                    (node as? SKEmitterNode)?.particleBirthRate = max(0.5, 2 - Float(elapsed) * 0.15)
                })
            }
        }
    }
}
