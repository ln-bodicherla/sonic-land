import AppKit
import ApplicationServices
import CoreGraphics

// Private API to get CGWindowID from AXUIElement.
// Used by AeroSpace, yabai, and other WMs. Works through macOS 15.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ outWindowID: UnsafeMutablePointer<CGWindowID>) -> AXError

enum AccessibilityWrapper {

    // MARK: - Window Enumeration

    /// Get all windows for an application by PID.
    static func getWindows(for pid: pid_t) -> [AXUIElement] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            return []
        }
        return windows
    }

    /// Get the CGWindowID for an AXUIElement.
    static func getWindowID(_ element: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        let result = _AXUIElementGetWindow(element, &windowID)
        return result == .success ? windowID : nil
    }

    // MARK: - Window Properties

    /// Get the frame (position + size) of a window.
    static func getWindowFrame(_ element: AXUIElement) -> CGRect? {
        guard let position = getWindowPosition(element),
              let size = getWindowSize(element) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// Get the position (top-left corner) of a window.
    static func getWindowPosition(_ element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(axValue as! AXValue, .cgPoint, &point)
        return point
    }

    /// Get the size of a window.
    static func getWindowSize(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        var size = CGSize.zero
        AXValueGetValue(axValue as! AXValue, .cgSize, &size)
        return size
    }

    /// Get the title of a window.
    static func getWindowTitle(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    /// Get the subrole of a window (e.g., AXStandardWindow, AXDialog).
    static func getWindowSubrole(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    /// Get the role of a window.
    static func getWindowRole(_ element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    /// Check if a window is minimized.
    static func isMinimized(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value)
        guard result == .success else { return false }
        return (value as? Bool) ?? false
    }

    /// Check if a window is fullscreen.
    static func isFullscreen(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value)
        guard result == .success else { return false }
        return (value as? Bool) ?? false
    }

    /// Subroles that should never be tiled.
    /// Note: AXDialog is NOT here — many apps (Terminal, Finder) use it for real windows.
    private static let untileableSubroles: Set<String> = [
        "AXSheet",
        "AXSystemFloatingWindow",
    ]

    /// Check if a window is suitable for tiling.
    /// Accepts AXStandardWindow, windows with no subrole, and anything not in
    /// the explicit reject list. Logs rejections for debugging.
    static func isWindowTileable(_ element: AXUIElement) -> Bool {
        guard let role = getWindowRole(element), role == kAXWindowRole as String else {
            let actualRole = getWindowRole(element) ?? "nil"
            NSLog("[SonicLand] Skipping non-window element (role: \(actualRole))")
            return false
        }

        let subrole = getWindowSubrole(element)

        // Explicitly reject known non-tileable subroles
        if let sr = subrole, untileableSubroles.contains(sr) {
            let title = getWindowTitle(element) ?? "untitled"
            NSLog("[SonicLand] Skipping untileable subrole \(sr): \(title)")
            return false
        }

        // Accept: AXStandardWindow, nil subrole, or any other subrole not in the reject list
        // (many apps report custom or no subrole for their main windows)

        // Resizable check — if the attribute is missing, assume resizable
        var isResizable: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXResizable" as CFString, &isResizable)
        if result == .success, let resizable = isResizable as? Bool, !resizable {
            let title = getWindowTitle(element) ?? "untitled"
            NSLog("[SonicLand] Skipping non-resizable window: \(title)")
            return false
        }

        // Skip tiny windows (tooltips, popups, etc.)
        if let size = getWindowSize(element), size.width < 100 || size.height < 100 {
            return false
        }

        return true
    }

    // MARK: - Window Manipulation

    /// Set the frame of a window using the size-position-size pattern.
    /// This handles macOS minimum size constraints correctly.
    static func setWindowFrame(_ element: AXUIElement, frame: CGRect) {
        // Size first (to handle min-size constraints)
        setWindowSize(element, size: frame.size)
        // Then position
        setWindowPosition(element, position: frame.origin)
        // Then size again (in case position change affected available size)
        setWindowSize(element, size: frame.size)
    }

    /// Set just the position of a window.
    static func setWindowPosition(_ element: AXUIElement, position: CGPoint) {
        var point = position
        guard let value = AXValueCreate(.cgPoint, &point) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    /// Set just the size of a window.
    static func setWindowSize(_ element: AXUIElement, size: CGSize) {
        var sz = size
        guard let value = AXValueCreate(.cgSize, &sz) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    /// Focus a window and bring its app to front.
    static func focusWindow(_ element: AXUIElement, pid: pid_t) {
        let app = NSRunningApplication(processIdentifier: pid)
        app?.activate()
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
    }

    // MARK: - AXObserver

    /// Create an AXObserver for an application.
    static func createObserver(for pid: pid_t, callback: @escaping AXObserverCallback) -> AXObserver? {
        var observer: AXObserver?
        let result = AXObserverCreate(pid, callback, &observer)
        guard result == .success, let obs = observer else { return nil }
        return obs
    }

    /// Notifications to watch for window management.
    static let windowNotifications: [String] = [
        kAXWindowCreatedNotification,
        kAXUIElementDestroyedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXFocusedWindowChangedNotification,
        kAXTitleChangedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
    ]

    /// Register an observer for all window-related notifications.
    static func registerObserver(_ observer: AXObserver, element: AXUIElement,
                                  notifications: [String], refcon: UnsafeMutableRawPointer?) {
        for notification in notifications {
            AXObserverAddNotification(observer, element, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }

    /// Unregister an observer.
    static func unregisterObserver(_ observer: AXObserver, element: AXUIElement, notifications: [String]) {
        for notification in notifications {
            AXObserverRemoveNotification(observer, element, notification as CFString)
        }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
    }
}
