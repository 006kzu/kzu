// PhysicsSandboxScene.swift
// Kzu — Physics playground mini-game: gravity, bounce, flow

import SpriteKit

// MARK: - Physics Sandbox Scene

/// A physics playground where the child drops shapes that interact
/// with gravity, bounce off surfaces, and create satisfying chain reactions.
/// Meditative and tactile — focused on cause and effect.
class PhysicsSandboxScene: KzuGameScene {

    private let shapeColors: [UIColor] = [
        UIColor(red: 0.29, green: 0.56, blue: 0.85, alpha: 1.0),
        UIColor(red: 0.36, green: 0.72, blue: 0.48, alpha: 1.0),
        UIColor(red: 0.85, green: 0.68, blue: 0.32, alpha: 1.0),
        UIColor(red: 0.82, green: 0.28, blue: 0.28, alpha: 1.0),
        UIColor(red: 0.55, green: 0.42, blue: 0.58, alpha: 1.0),
    ]

    override func setupGame() {
        backgroundColor = UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1.0)

        // Physics world
        physicsWorld.gravity = CGVector(dx: 0, dy: -4.0)

        // Floor
        let floor = SKShapeNode(rectOf: CGSize(width: size.width, height: 4))
        floor.position = CGPoint(x: size.width / 2, y: 40)
        floor.fillColor = UIColor(Color.kzuSurface)
        floor.strokeColor = .clear
        floor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: size.width, height: 4))
        floor.physicsBody?.isDynamic = false
        floor.physicsBody?.restitution = 0.6
        addChild(floor)

        // Side walls
        for x in [CGFloat(0), size.width] {
            let wall = SKShapeNode(rectOf: CGSize(width: 4, height: size.height))
            wall.position = CGPoint(x: x, y: size.height / 2)
            wall.fillColor = .clear
            wall.strokeColor = .clear
            wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 4, height: size.height))
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.restitution = 0.4
            addChild(wall)
        }

        // Random platforms
        for _ in 0..<3 {
            let platformWidth = CGFloat.random(in: 60...120)
            let platform = SKShapeNode(rectOf: CGSize(width: platformWidth, height: 6), cornerRadius: 3)
            platform.position = CGPoint(
                x: CGFloat.random(in: 60...(size.width - 60)),
                y: CGFloat.random(in: 120...(size.height * 0.6))
            )
            platform.fillColor = UIColor(Color.kzuSoftNavy).withAlphaComponent(0.3)
            platform.strokeColor = .clear
            platform.zRotation = CGFloat.random(in: -.pi/8 ... .pi/8)
            platform.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: platformWidth, height: 6))
            platform.physicsBody?.isDynamic = false
            platform.physicsBody?.restitution = 0.7
            addChild(platform)
        }

        // Instruction
        let instruction = SKLabelNode(fontNamed: "SFRounded-Regular")
        instruction.text = "tap to drop · drag to launch"
        instruction.fontSize = 14
        instruction.fontColor = UIColor(Color.kzuSoftNavy).withAlphaComponent(0.5)
        instruction.position = CGPoint(x: size.width / 2, y: size.height - 90)
        instruction.name = "instruction"
        addChild(instruction)

        instruction.run(SKAction.sequence([
            SKAction.wait(forDuration: 4.0),
            SKAction.fadeOut(withDuration: 1.5),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Touch: Tap to Drop

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        spawnShape(at: location)

        childNode(withName: "instruction")?.removeFromParent()
    }

    // MARK: - Touch: Drag to Launch

    private var dragStart: CGPoint?

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if dragStart == nil {
            dragStart = touch.previousLocation(in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = dragStart else {
            dragStart = nil
            return
        }

        let end = touch.location(in: self)
        let velocity = CGVector(
            dx: (end.x - start.x) * 3,
            dy: (end.y - start.y) * 3
        )

        // Launch the most recently added dynamic node
        if let lastShape = children.last(where: { $0.physicsBody?.isDynamic == true }) {
            lastShape.physicsBody?.applyImpulse(velocity)
        }

        dragStart = nil
    }

    // MARK: - Shape Spawning

    private func spawnShape(at position: CGPoint) {
        let shapeType = Int.random(in: 0...2)
        let color = shapeColors.randomElement()!
        let node: SKShapeNode

        switch shapeType {
        case 0:
            // Circle
            let radius = CGFloat.random(in: 15...35)
            node = SKShapeNode(circleOfRadius: radius)
            node.physicsBody = SKPhysicsBody(circleOfRadius: radius)

        case 1:
            // Rectangle
            let size = CGSize(
                width: CGFloat.random(in: 20...50),
                height: CGFloat.random(in: 20...50)
            )
            node = SKShapeNode(rectOf: size, cornerRadius: 4)
            node.physicsBody = SKPhysicsBody(rectangleOf: size)

        default:
            // Triangle
            let triSize: CGFloat = CGFloat.random(in: 25...45)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: triSize))
            path.addLine(to: CGPoint(x: -triSize * 0.866, y: -triSize * 0.5))
            path.addLine(to: CGPoint(x: triSize * 0.866, y: -triSize * 0.5))
            path.closeSubpath()
            node = SKShapeNode(path: path)
            node.physicsBody = SKPhysicsBody(polygonFrom: path)
        }

        node.fillColor = color.withAlphaComponent(0.7)
        node.strokeColor = color
        node.lineWidth = 2
        node.position = position
        node.zPosition = 5

        node.physicsBody?.restitution = CGFloat.random(in: 0.4...0.8)
        node.physicsBody?.friction = 0.3
        node.physicsBody?.linearDamping = 0.1
        node.physicsBody?.angularDamping = 0.1
        node.physicsBody?.mass = CGFloat.random(in: 0.5...2.0)

        // Entry animation
        node.setScale(0)
        node.alpha = 0

        addChild(node)

        node.run(SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.2),
            SKAction.fadeIn(withDuration: 0.15)
        ]))

        // Limit shapes on screen
        let dynamicNodes = children.filter { $0.physicsBody?.isDynamic == true }
        if dynamicNodes.count > 30 {
            dynamicNodes.first?.run(SKAction.sequence([
                SKAction.fadeOut(withDuration: 0.3),
                SKAction.removeFromParent()
            ]))
        }
    }

    // MARK: - Wind Down

    override func onWindDown() {
        // Reduce gravity for floaty feel
        run(SKAction.customAction(withDuration: 15) { [weak self] _, elapsed in
            let t = elapsed / 15.0
            self?.physicsWorld.gravity = CGVector(dx: 0, dy: -4.0 + Double(t) * 3.5)
        })
    }

    override func updateGame(delta: TimeInterval) {
        // Remove shapes that fall off screen
        for child in children where child.position.y < -50 {
            child.removeFromParent()
        }
    }
}
