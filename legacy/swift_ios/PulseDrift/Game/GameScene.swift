import SpriteKit
import UIKit

final class GameScene: SKScene, SKPhysicsContactDelegate {
    weak var session: GameSession?

    private enum PhysicsCategory {
        static let player: UInt32 = 0x1 << 0
        static let gate: UInt32 = 0x1 << 1
        static let spark: UInt32 = 0x1 << 2
        static let scoreLine: UInt32 = 0x1 << 3
    }

    private let backdropNode = SKNode()
    private let laneNode = SKNode()
    private let gameplayNode = SKNode()
    private let player = SKShapeNode(circleOfRadius: 22)
    private let feedbackLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let impactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private var laneXPositions: [CGFloat] = []
    private var currentLane = 1
    private var lastRestartToken: UUID?
    private var cleanDodges = 0
    private var lastUpdateTime: TimeInterval = 0
    private var gateTimer: TimeInterval = 0
    private var sparkTimer: TimeInterval = 0

    override func didMove(to view: SKView) {
        if children.isEmpty {
            setupScene()
        }
        restartIfNeeded(force: true)
    }

    override func update(_ currentTime: TimeInterval) {
        if session?.isGameOver == true { return }

        if lastUpdateTime == 0 {
            lastUpdateTime = currentTime
            return
        }

        let delta = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        gateTimer += delta
        sparkTimer += delta

        if gateTimer >= Balance.gateSpawnDelay(for: cleanDodges) {
            gateTimer = 0
            spawnGate()
        }

        if sparkTimer >= Balance.sparkSpawnDelay(for: cleanDodges) {
            sparkTimer = 0
            spawnSpark()
        }

        recycleOffscreenNodes()
        restartIfNeeded(force: false)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard session?.isGameOver == false, let touch = touches.first else { return }

        let targetLane = nearestLaneIndex(to: touch.location(in: self).x)
        guard targetLane != currentLane else { return }

        currentLane = targetLane
        let move = SKAction.moveTo(x: laneXPositions[currentLane], duration: 0.14)
        move.timingMode = .easeInEaseOut
        player.run(move)
        SoundEffectPlayer.shared.play(.laneShift)
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let pair = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if pair == (PhysicsCategory.player | PhysicsCategory.gate) {
            session?.endRun()
            runCrashEffect()
            flashFeedback("CRASH", color: .systemRed)
            SoundEffectPlayer.shared.play(.crash)
            return
        }

        if pair == (PhysicsCategory.player | PhysicsCategory.spark) {
            let sparkNode = contact.bodyA.categoryBitMask == PhysicsCategory.spark ? contact.bodyA.node : contact.bodyB.node
            sparkNode?.removeFromParent()
            session?.collectSpark()
            flashFeedback("+\(Balance.sparkBonus)", color: .systemCyan)
            SoundEffectPlayer.shared.play(.spark)
            return
        }

        if pair == (PhysicsCategory.player | PhysicsCategory.scoreLine) {
            guard let gate = contact.bodyA.categoryBitMask == PhysicsCategory.scoreLine ? contact.bodyA.node?.userData?["gate"] as? SKNode : contact.bodyB.node?.userData?["gate"] as? SKNode else {
                return
            }

            if gate.userData?["scored"] as? Bool == true {
                return
            }

            gate.userData?["scored"] = true
            cleanDodges += 1
            session?.registerDodge()
            flashFeedback("FLOW", color: .systemMint)
            SoundEffectPlayer.shared.play(.dodge)
        }
    }

    private func setupScene() {
        backgroundColor = .clear
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        addChild(backdropNode)
        addChild(laneNode)
        addChild(gameplayNode)
        createBackdrop()
        createLanes()
        createPlayer()
        createFeedbackLabel()
    }

    private func createBackdrop() {
        for index in 0..<18 {
            let orb = SKShapeNode(circleOfRadius: CGFloat.random(in: 10...34))
            orb.fillColor = index.isMultiple(of: 2) ? .systemTeal.withAlphaComponent(0.15) : .systemPink.withAlphaComponent(0.11)
            orb.strokeColor = .clear
            orb.position = CGPoint(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height)
            )
            orb.blendMode = .add
            backdropNode.addChild(orb)
        }
    }

    private func createLanes() {
        let spacing = size.width / 4
        laneXPositions = [spacing, spacing * 2, spacing * 3]

        for laneX in laneXPositions {
            let line = SKShapeNode(rectOf: CGSize(width: 2, height: size.height * 1.4), cornerRadius: 1)
            line.fillColor = .white.withAlphaComponent(0.1)
            line.strokeColor = .clear
            line.position = CGPoint(x: laneX, y: size.height / 2)
            laneNode.addChild(line)
        }
    }

    private func createPlayer() {
        player.fillColor = .white
        player.strokeColor = .systemMint
        player.lineWidth = 4
        player.glowWidth = 8
        player.position = CGPoint(x: laneXPositions[currentLane], y: size.height * 0.18)
        player.zPosition = 10
        player.physicsBody = SKPhysicsBody(circleOfRadius: 22)
        player.physicsBody?.isDynamic = true
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.collisionBitMask = 0
        player.physicsBody?.contactTestBitMask = PhysicsCategory.gate | PhysicsCategory.spark | PhysicsCategory.scoreLine
        gameplayNode.addChild(player)
    }

    private func createFeedbackLabel() {
        feedbackLabel.fontSize = 26
        feedbackLabel.alpha = 0
        feedbackLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        feedbackLabel.zPosition = 50
        addChild(feedbackLabel)
    }

    private func spawnGate() {
        let blockedLane = Int.random(in: 0..<laneXPositions.count)
        let gateNode = SKNode()
        gateNode.userData = ["scored": false]
        gateNode.position = CGPoint(x: 0, y: size.height + 120)

        for lane in 0..<laneXPositions.count where lane != blockedLane {
            let bar = SKShapeNode(rectOf: CGSize(width: 70, height: 24), cornerRadius: 12)
            bar.fillColor = .systemOrange
            bar.strokeColor = .systemRed
            bar.lineWidth = 2
            bar.position = CGPoint(x: laneXPositions[lane], y: 0)
            let body = SKPhysicsBody(rectangleOf: CGSize(width: 70, height: 24))
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.gate
            body.contactTestBitMask = PhysicsCategory.player
            body.collisionBitMask = 0
            bar.physicsBody = body
            gateNode.addChild(bar)
        }

        let scoreLine = SKNode()
        scoreLine.position = CGPoint(x: laneXPositions[blockedLane], y: -40)
        let scoreBody = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 10))
        scoreBody.isDynamic = false
        scoreBody.categoryBitMask = PhysicsCategory.scoreLine
        scoreBody.contactTestBitMask = PhysicsCategory.player
        scoreBody.collisionBitMask = 0
        scoreLine.physicsBody = scoreBody
        scoreLine.userData = ["gate": gateNode]
        gateNode.addChild(scoreLine)

        let moveDuration = obstacleTravelDuration(distance: size.height + 240)
        gateNode.run(.sequence([
            .moveBy(x: 0, y: -(size.height + 240), duration: moveDuration),
            .removeFromParent(),
        ]))

        gameplayNode.addChild(gateNode)
    }

    private func spawnSpark() {
        let sparkLane = Int.random(in: 0..<laneXPositions.count)
        let spark = SKShapeNode(circleOfRadius: 12)
        spark.fillColor = .systemCyan
        spark.strokeColor = .white
        spark.lineWidth = 2
        spark.glowWidth = 10
        spark.position = CGPoint(x: laneXPositions[sparkLane], y: size.height + 80)
        spark.physicsBody = SKPhysicsBody(circleOfRadius: 12)
        spark.physicsBody?.isDynamic = false
        spark.physicsBody?.categoryBitMask = PhysicsCategory.spark
        spark.physicsBody?.contactTestBitMask = PhysicsCategory.player
        spark.physicsBody?.collisionBitMask = 0

        let moveDuration = obstacleTravelDuration(
            distance: size.height + 180,
            speedMultiplier: 0.84
        )
        spark.run(.sequence([
            .group([
                .moveBy(x: 0, y: -(size.height + 180), duration: moveDuration),
                .repeatForever(.sequence([
                    .scale(to: 1.2, duration: 0.28),
                    .scale(to: 0.9, duration: 0.28),
                ])),
            ]),
            .removeFromParent(),
        ]))

        gameplayNode.addChild(spark)
    }

    private func recycleOffscreenNodes() {
        for node in gameplayNode.children where node !== player && node.position.y < -160 {
            node.removeFromParent()
        }
    }

    private func nearestLaneIndex(to xPosition: CGFloat) -> Int {
        laneXPositions.enumerated()
            .min { abs($0.element - xPosition) < abs($1.element - xPosition) }?
            .offset ?? currentLane
    }

    private func obstacleTravelDuration(distance: CGFloat, speedMultiplier: Double = 1.0) -> TimeInterval {
        let speed = Balance.speed(for: cleanDodges) * speedMultiplier
        return TimeInterval(distance / speed)
    }

    private func runCrashEffect() {
        impactGenerator.prepare()
        impactGenerator.impactOccurred()

        let flash = SKShapeNode(circleOfRadius: 30)
        flash.position = player.position
        flash.fillColor = .systemRed
        flash.strokeColor = .clear
        flash.glowWidth = 20
        flash.blendMode = .add
        gameplayNode.addChild(flash)

        flash.run(.sequence([
            .group([
                .fadeOut(withDuration: 0.25),
                .scale(to: 2.4, duration: 0.25),
            ]),
            .removeFromParent(),
        ]))
    }

    private func flashFeedback(_ text: String, color: UIColor) {
        feedbackLabel.removeAllActions()
        feedbackLabel.text = text
        feedbackLabel.fontColor = color
        feedbackLabel.setScale(0.7)
        feedbackLabel.alpha = 0
        feedbackLabel.run(.sequence([
            .group([
                .fadeAlpha(to: 1, duration: 0.08),
                .scale(to: 1.0, duration: 0.12),
            ]),
            .wait(forDuration: 0.14),
            .group([
                .fadeOut(withDuration: 0.18),
                .moveBy(x: 0, y: 18, duration: 0.18),
            ]),
            .run { [weak self] in
                guard let self else { return }
                self.feedbackLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height * 0.72)
            },
        ]))
    }

    private func restartIfNeeded(force: Bool) {
        guard let session else { return }
        guard force || lastRestartToken != session.restartToken else { return }

        lastRestartToken = session.restartToken
        cleanDodges = 0
        lastUpdateTime = 0
        gateTimer = 0
        sparkTimer = 0
        currentLane = 1

        for node in gameplayNode.children where node !== player {
            node.removeFromParent()
        }

        player.removeAllActions()
        player.position = CGPoint(x: laneXPositions[currentLane], y: size.height * 0.18)
        feedbackLabel.removeAllActions()
        feedbackLabel.alpha = 0
    }
}
