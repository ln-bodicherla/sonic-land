import AppKit

/// Manages a single overlay window animation for a window transition.
final class WindowAnimator {
    private var overlayWindow: NSWindow?

    /// Animate a transition from one frame to another using an overlay window.
    /// The real window is snapped to the target immediately, while the overlay
    /// animates from the old position to create a smooth visual effect.
    func animate(from sourceFrame: CGRect, to targetFrame: CGRect,
                 duration: TimeInterval, curve: EasingCurve,
                 completion: @escaping () -> Void) {
        // Create overlay at the source position
        let overlay = NSWindow(
            contentRect: sourceFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlay.level = .floating
        overlay.isOpaque = false
        overlay.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08)
        overlay.hasShadow = false
        overlay.ignoresMouseEvents = true
        overlay.orderFront(nil)
        overlayWindow = overlay

        // Animate the overlay from source to target
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: curve.caTimingName)
            overlay.animator().setFrame(targetFrame, display: true)
            overlay.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            overlay.orderOut(nil)
            self?.overlayWindow = nil
            completion()
        })
    }

    func cancel() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }
}

extension EasingCurve {
    var caTimingName: CAMediaTimingFunctionName {
        switch self {
        case .linear: return .linear
        case .easeIn: return .easeIn
        case .easeOut: return .easeOut
        case .easeInOut: return .easeInEaseOut
        case .spring: return .easeOut // Closest approximation
        }
    }
}
