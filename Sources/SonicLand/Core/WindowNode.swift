import AppKit
import CoreGraphics

/// Represents a single managed window.
final class WindowNode {
    let windowID: CGWindowID
    let axElement: AXUIElement
    let pid: pid_t
    let bundleID: String
    let appName: String

    var title: String?
    var frame: CGRect
    var targetFrame: CGRect?
    var workspaceID: Int
    var monitorID: UInt32
    var isFloating: Bool
    var isModeFloated: Bool
    var isMinimized: Bool
    var isFullscreen: Bool
    var isPseudoFullscreen: Bool
    var isPinned: Bool           // Pinned to master area
    var isSticky: Bool           // Visible across all workspaces
    var tags: Set<String>        // User-defined tags/categories
    var alwaysFloat: Bool        // Rule-based permanent float
    var floatGeometry: CGRect?   // Preferred floating position/size
    var centerOnOpen: Bool       // Center when opened as float

    /// Whether the window has drifted from its target (e.g., user dragged it).
    var hasDrifted: Bool {
        guard let target = targetFrame, !isFloating else { return false }
        let threshold: CGFloat = 10
        return abs(frame.origin.x - target.origin.x) > threshold ||
               abs(frame.origin.y - target.origin.y) > threshold ||
               abs(frame.size.width - target.size.width) > threshold ||
               abs(frame.size.height - target.size.height) > threshold
    }

    init(windowID: CGWindowID, axElement: AXUIElement, pid: pid_t,
         bundleID: String, appName: String, title: String?, frame: CGRect) {
        self.windowID = windowID
        self.axElement = axElement
        self.pid = pid
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.frame = frame
        self.workspaceID = 0
        self.monitorID = 0
        self.isFloating = false
        self.isModeFloated = false
        self.isMinimized = false
        self.isFullscreen = false
        self.isPseudoFullscreen = false
        self.isPinned = false
        self.isSticky = false
        self.tags = []
        self.alwaysFloat = false
        self.floatGeometry = nil
        self.centerOnOpen = false
    }
}
