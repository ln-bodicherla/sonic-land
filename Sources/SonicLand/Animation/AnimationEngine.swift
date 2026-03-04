import AppKit

/// Coordinates window animations during layout changes.
final class AnimationEngine {
    private var activeAnimators: [CGWindowID: WindowAnimator] = [:]
    private var enabled: Bool
    private var duration: TimeInterval
    private var curve: EasingCurve

    init(config: ConfigModel) {
        self.enabled = config.animation.enabled
        self.duration = config.animation.duration / 1000.0 // Convert ms to seconds
        self.curve = config.animation.curve
    }

    func updateConfig(_ config: ConfigModel) {
        self.enabled = config.animation.enabled
        self.duration = config.animation.duration / 1000.0
        self.curve = config.animation.curve
    }

    /// Animate a window from its current frame to a target frame.
    /// The completion closure should set the real window position.
    func animate(from sourceFrame: CGRect, to targetFrame: CGRect,
                 completion: @escaping () -> Void) {
        guard enabled else {
            completion()
            return
        }

        // Skip animation if frames are very close
        let threshold: CGFloat = 2
        if abs(sourceFrame.origin.x - targetFrame.origin.x) < threshold &&
           abs(sourceFrame.origin.y - targetFrame.origin.y) < threshold &&
           abs(sourceFrame.size.width - targetFrame.size.width) < threshold &&
           abs(sourceFrame.size.height - targetFrame.size.height) < threshold {
            completion()
            return
        }

        // Execute completion immediately (snap real window)
        completion()

        // Animate overlay
        let animator = WindowAnimator()
        animator.animate(from: sourceFrame, to: targetFrame,
                        duration: duration, curve: curve) {
            // Animation complete
        }
    }

    /// Cancel all active animations.
    func cancelAll() {
        for (_, animator) in activeAnimators {
            animator.cancel()
        }
        activeAnimators.removeAll()
    }
}
