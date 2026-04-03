import UIKit

/// Animated mesh gradient background with soft color blobs that slowly drift.
final class MeshGradientView: UIView {

    private var blobLayers: [CAGradientLayer] = []
    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    private struct Blob {
        let color: UIColor
        let size: CGFloat       // fraction of screen diagonal
        let speed: CGFloat      // movement speed multiplier
        let phaseX: CGFloat     // offset so blobs start at different positions
        let phaseY: CGFloat
        let orbitX: CGFloat     // how far it drifts horizontally (fraction of width)
        let orbitY: CGFloat     // how far it drifts vertically (fraction of height)
        let anchorX: CGFloat    // center position (fraction of width)
        let anchorY: CGFloat    // center position (fraction of height)
    }

    private let blobs: [Blob] = [
        Blob(color: DesignTokens.Colors.accent,          size: 0.7,  speed: 0.06, phaseX: 0.0,  phaseY: 0.3,  orbitX: 0.15, orbitY: 0.10, anchorX: 0.2,  anchorY: 0.15),
        Blob(color: DesignTokens.Colors.accentSecondary,  size: 0.6,  speed: 0.04, phaseX: 1.2,  phaseY: 0.8,  orbitX: 0.12, orbitY: 0.14, anchorX: 0.8,  anchorY: 0.25),
        Blob(color: DesignTokens.Colors.accentTertiary,   size: 0.55, speed: 0.05, phaseX: 2.5,  phaseY: 1.6,  orbitX: 0.18, orbitY: 0.12, anchorX: 0.65, anchorY: 0.8),
        Blob(color: DesignTokens.Colors.accent,          size: 0.5,  speed: 0.035, phaseX: 3.8, phaseY: 2.4,  orbitX: 0.14, orbitY: 0.16, anchorX: 0.15, anchorY: 0.75),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        buildBlobs()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildBlobs() {
        for blob in blobs {
            let layer = CAGradientLayer()
            layer.type = .radial
            layer.colors = [
                blob.color.withAlphaComponent(0.18).cgColor,
                blob.color.withAlphaComponent(0.06).cgColor,
                blob.color.withAlphaComponent(0.0).cgColor,
            ]
            layer.locations = [0, 0.5, 1.0]
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1.0, y: 1.0)
            self.layer.addSublayer(layer)
            blobLayers.append(layer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBlobFrames(at: 0)
    }

    func startAnimating() {
        stopAnimating()
        guard !UIAccessibility.isReduceMotionEnabled else {
            updateBlobFrames(at: 0)
            return
        }
        startTime = CACurrentMediaTime()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 20)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let t = CACurrentMediaTime() - startTime
        updateBlobFrames(at: t)
    }

    private func updateBlobFrames(at time: CFTimeInterval) {
        let w = bounds.width
        let h = bounds.height
        guard w > 0 else { return }
        let diag = sqrt(w * w + h * h)

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for (i, blob) in blobs.enumerated() {
            let blobSize = diag * blob.size
            let t = CGFloat(time) * blob.speed

            let cx = w * blob.anchorX + sin(t * 2 * .pi + blob.phaseX) * w * blob.orbitX
            let cy = h * blob.anchorY + cos(t * 2 * .pi + blob.phaseY) * h * blob.orbitY

            blobLayers[i].frame = CGRect(
                x: cx - blobSize / 2,
                y: cy - blobSize / 2,
                width: blobSize,
                height: blobSize
            )
            blobLayers[i].cornerRadius = blobSize / 2
        }

        CATransaction.commit()
    }
}
