import SpriteKit
import UIKit

/// SpriteKit scene with ambient floating particles for cinematic onboarding screens.
/// Uses two emitter layers: fine "dust" and slow-drifting "orbs."
final class AmbientParticleScene: SKScene {

    /// Multiplier for particle birth rates (set > 1 for celebration screens).
    var intensityMultiplier: CGFloat = 1.0 {
        didSet { updateEmitterRates() }
    }

    private var dustEmitter: SKEmitterNode?
    private var orbEmitter: SKEmitterNode?

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        backgroundColor = .clear
        scaleMode = .resizeFill

        setupDustEmitter()
        setupOrbEmitter()

        if UIAccessibility.isReduceMotionEnabled {
            applyReducedMotion()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        dustEmitter?.position = CGPoint(x: size.width / 2, y: 0)
        dustEmitter?.particlePositionRange = CGVector(dx: size.width * 1.2, dy: size.height * 1.2)
        orbEmitter?.position = CGPoint(x: size.width / 2, y: 0)
        orbEmitter?.particlePositionRange = CGVector(dx: size.width * 1.2, dy: size.height * 1.2)
    }

    // MARK: - Dust Emitter

    private func setupDustEmitter() {
        let emitter = SKEmitterNode()

        // Tiny circle texture (4x4)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        let circleImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
        emitter.particleTexture = SKTexture(image: circleImage)

        emitter.particleBirthRate = 8 * intensityMultiplier
        emitter.particleLifetime = 12
        emitter.particleLifetimeRange = 4
        emitter.particlePositionRange = CGVector(dx: size.width * 1.2, dy: size.height * 1.2)

        emitter.particleSpeed = 6
        emitter.particleSpeedRange = 4
        emitter.emissionAngle = .pi / 2        // upward
        emitter.emissionAngleRange = .pi / 4

        emitter.particleAlpha = 0.15
        emitter.particleAlphaRange = 0.1
        emitter.particleAlphaSpeed = -0.01

        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3

        emitter.particleColor = DesignTokens.Colors.accent.withAlphaComponent(0.3)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleBlendMode = .add

        emitter.position = CGPoint(x: size.width / 2, y: 0)

        addChild(emitter)
        dustEmitter = emitter
    }

    // MARK: - Orb Emitter

    private func setupOrbEmitter() {
        let emitter = SKEmitterNode()

        // Soft circle texture (16x16 with radial gradient)
        let orbSize: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: orbSize, height: orbSize))
        let orbImage = renderer.image { ctx in
            let center = CGPoint(x: orbSize / 2, y: orbSize / 2)
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: orbSize / 2, options: [])
            }
        }
        emitter.particleTexture = SKTexture(image: orbImage)

        emitter.particleBirthRate = 1.5 * intensityMultiplier
        emitter.particleLifetime = 18
        emitter.particleLifetimeRange = 6
        emitter.particlePositionRange = CGVector(dx: size.width * 1.2, dy: size.height * 1.2)

        emitter.particleSpeed = 3
        emitter.particleSpeedRange = 2
        emitter.emissionAngle = .pi * 0.6      // slightly left-upward
        emitter.emissionAngleRange = .pi / 6

        emitter.particleAlpha = 0.08
        emitter.particleAlphaRange = 0.04

        emitter.particleScale = 2.0
        emitter.particleScaleRange = 1.5

        emitter.particleColor = .white
        emitter.particleBlendMode = .add

        // Breathing fade
        let breathe = SKAction.sequence([
            .fadeAlpha(to: 0.12, duration: 4),
            .fadeAlpha(to: 0.04, duration: 4),
        ])
        emitter.particleAction = .repeatForever(breathe)

        emitter.position = CGPoint(x: size.width / 2, y: 0)

        addChild(emitter)
        orbEmitter = emitter
    }

    // MARK: - Helpers

    private func updateEmitterRates() {
        dustEmitter?.particleBirthRate = 8 * intensityMultiplier
        orbEmitter?.particleBirthRate = 1.5 * intensityMultiplier
    }

    private func applyReducedMotion() {
        dustEmitter?.particleSpeed = 0
        dustEmitter?.particleBirthRate = 2
        orbEmitter?.particleSpeed = 0
        orbEmitter?.particleBirthRate = 0.5
    }
}
