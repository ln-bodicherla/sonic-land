import AppKit
import CoreGraphics

/// Manages visual overlay windows for feedback.
final class OverlayManager {
    private var overlayWindows: [String: NSWindow] = [:]
    private var hideTimers: [String: Timer] = [:]

    /// Show a text overlay briefly (layout name, workspace name, etc.)
    func showNotification(_ text: String, duration: TimeInterval = 1.0) {
        hideOverlay(id: "notification")

        let overlay = createTextOverlay(text: text)
        overlayWindows["notification"] = overlay
        overlay.orderFront(nil)

        hideTimers["notification"] = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideOverlay(id: "notification")
        }
    }

    /// Show the current workspace name.
    func showWorkspaceName(_ name: String) {
        showNotification(name, duration: 0.8)
    }

    /// Show the current layout mode name.
    func showLayoutName(_ name: String) {
        showNotification(name, duration: 0.8)
    }

    /// Show a focus ring around the given frame.
    func showFocusRing(frame: CGRect, color: NSColor = .controlAccentColor) {
        hideOverlay(id: "focusRing")

        let borderWidth: CGFloat = 3
        let expandedFrame = frame.insetBy(dx: -borderWidth, dy: -borderWidth)

        let overlay = NSWindow(
            contentRect: expandedFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlay.level = .floating
        overlay.isOpaque = false
        overlay.backgroundColor = .clear
        overlay.hasShadow = false
        overlay.ignoresMouseEvents = true

        let borderView = FocusRingView(frame: NSRect(origin: .zero, size: expandedFrame.size))
        borderView.ringColor = color
        borderView.borderWidth = borderWidth
        overlay.contentView = borderView

        overlayWindows["focusRing"] = overlay
        overlay.orderFront(nil)
    }

    /// Hide the focus ring.
    func hideFocusRing() {
        hideOverlay(id: "focusRing")
    }

    /// Show a mini workspace map overlay.
    func showWorkspaceMap(
        workspaces: [(id: Int, name: String, isActive: Bool, windowCount: Int)],
        duration: TimeInterval = 1.5
    ) {
        hideOverlay(id: "workspaceMap")

        guard let screen = NSScreen.main else { return }
        let itemWidth: CGFloat = 60
        let itemHeight: CGFloat = 40
        let padding: CGFloat = 8
        let spacing: CGFloat = 4
        let totalWidth = CGFloat(workspaces.count) * (itemWidth + spacing) - spacing + padding * 2
        let totalHeight = itemHeight + padding * 2

        let x = screen.frame.midX - totalWidth / 2
        let y = screen.frame.height * 0.15

        let overlay = NSWindow(
            contentRect: CGRect(x: x, y: y, width: totalWidth, height: totalHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlay.level = .floating
        overlay.isOpaque = false
        overlay.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        overlay.hasShadow = true
        overlay.ignoresMouseEvents = true

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: totalHeight))

        for (i, ws) in workspaces.enumerated() {
            let itemX = padding + CGFloat(i) * (itemWidth + spacing)
            let itemView = NSView(frame: NSRect(x: itemX, y: padding, width: itemWidth, height: itemHeight))
            itemView.wantsLayer = true
            itemView.layer?.cornerRadius = 4

            if ws.isActive {
                itemView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.8).cgColor
            } else if ws.windowCount > 0 {
                itemView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
            } else {
                itemView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.05).cgColor
            }

            let label = NSTextField(labelWithString: "\(ws.id)")
            label.font = .systemFont(ofSize: 14, weight: ws.isActive ? .bold : .regular)
            label.textColor = .white
            label.alignment = .center
            label.frame = NSRect(x: 0, y: 8, width: itemWidth, height: 24)
            itemView.addSubview(label)

            contentView.addSubview(itemView)
        }

        overlay.contentView = contentView
        overlayWindows["workspaceMap"] = overlay
        overlay.orderFront(nil)

        hideTimers["workspaceMap"] = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.hideOverlay(id: "workspaceMap")
        }
    }

    func hideAll() {
        for (id, _) in overlayWindows {
            hideOverlay(id: id)
        }
    }

    private func hideOverlay(id: String) {
        hideTimers[id]?.invalidate()
        hideTimers.removeValue(forKey: id)
        overlayWindows[id]?.orderOut(nil)
        overlayWindows.removeValue(forKey: id)
    }

    private func createTextOverlay(text: String) -> NSWindow {
        guard let screen = NSScreen.main else {
            return NSWindow()
        }

        let font = NSFont.systemFont(ofSize: 28, weight: .semibold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 24
        let width = textSize.width + padding * 2
        let height = textSize.height + padding * 2

        let x = screen.frame.midX - width / 2
        let y = screen.frame.height * 0.2

        let overlay = NSWindow(
            contentRect: CGRect(x: x, y: y, width: width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        overlay.level = .floating
        overlay.isOpaque = false
        overlay.backgroundColor = NSColor.black.withAlphaComponent(0.75)
        overlay.hasShadow = true
        overlay.ignoresMouseEvents = true

        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 0, y: padding / 2, width: width, height: height - padding)
        overlay.contentView?.addSubview(label)

        // Round corners
        overlay.contentView?.wantsLayer = true
        overlay.contentView?.layer?.cornerRadius = 12

        return overlay
    }
}

/// A view that draws a focus ring border.
final class FocusRingView: NSView {
    var ringColor: NSColor = .controlAccentColor
    var borderWidth: CGFloat = 3

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2),
                                xRadius: 6, yRadius: 6)
        ringColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()
    }
}
