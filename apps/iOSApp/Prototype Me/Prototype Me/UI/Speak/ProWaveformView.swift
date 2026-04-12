import UIKit

/// Audio-reactive waveform visualizer. Each bar represents a chunk of the raw audio buffer,
/// giving a true waveform shape that updates every ~23ms with zero latency.
final class ProWaveformView: UIView {

    // MARK: - Config

    private let barCount = VoiceInputButton.waveformSegments
    private let barSpacing: CGFloat = 2.5
    private let barCornerRadius: CGFloat = 1.5
    private let minBarFraction: CGFloat = 0.06
    private let maxBarFraction: Float = 0.75

    // MARK: - State

    private var barLayers: [CALayer] = []
    private var displayLink: CADisplayLink?
    /// Target heights from latest audio data (0–1 per segment).
    private var targetHeights: [Float] = []
    /// Smoothed heights for display.
    private var barHeights: [Float] = []

    private let barColor = DesignTokens.Colors.destructive

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = false
        isUserInteractionEnabled = false

        for _ in 0..<barCount {
            let bar = CALayer()
            bar.backgroundColor = barColor.cgColor
            bar.cornerRadius = barCornerRadius
            bar.masksToBounds = true
            layer.addSublayer(bar)
            barLayers.append(bar)
            targetHeights.append(0)
            barHeights.append(0)
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutBars()
    }

    private func layoutBars() {
        guard bounds.width > 0 else { return }
        let totalSpacing = barSpacing * CGFloat(barCount - 1)
        let barWidth = (bounds.width - totalSpacing) / CGFloat(barCount)
        let maxHeight = bounds.height

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in barLayers.enumerated() {
            let x = CGFloat(i) * (barWidth + barSpacing)
            let fraction = max(minBarFraction, CGFloat(barHeights[i]))
            let height = maxHeight * fraction
            let y = (maxHeight - height) / 2
            bar.frame = CGRect(x: x, y: y, width: barWidth, height: height)
            bar.cornerRadius = min(barCornerRadius, barWidth / 2)
            bar.opacity = Float(0.4 + fraction * 0.6)
        }
        CATransaction.commit()
    }

    // MARK: - Waveform Data

    /// Feed new waveform segment amplitudes (each 0–1).
    func updateBands(_ bands: [Float]) {
        let count = min(bands.count, barCount)
        for i in 0..<count {
            targetHeights[i] = min(bands[i], maxBarFraction)
        }
    }

    /// Fallback: single level drives all bars uniformly.
    func updateLevel(_ level: Float) {
        let clamped = min(level, maxBarFraction)
        for i in 0..<barCount {
            targetHeights[i] = clamped
        }
    }

    // MARK: - Start / Stop

    func startAnimating() {
        guard displayLink == nil else { return }
        for i in 0..<barCount {
            targetHeights[i] = 0
            barHeights[i] = 0
        }

        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
        for i in 0..<barCount {
            targetHeights[i] = 0
            barHeights[i] = 0
        }
    }

    @objc private func tick() {
        for i in 0..<barCount {
            let target = targetHeights[i]
            let current = barHeights[i]
            if target > current {
                barHeights[i] += (target - current) * 0.6   // rise fast
            } else {
                barHeights[i] += (target - current) * 0.25  // fall smoothly
            }
        }
        layoutBars()
    }

    // MARK: - Cleanup

    deinit {
        displayLink?.invalidate()
    }
}
