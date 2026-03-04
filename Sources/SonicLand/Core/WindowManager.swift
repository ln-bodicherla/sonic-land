import AppKit
import ApplicationServices
import CoreGraphics

protocol WindowManagerDelegate: AnyObject {
    func windowManager(_ manager: WindowManager, didDetectNewWindow window: WindowNode)
    func windowManager(_ manager: WindowManager, didRemoveWindow windowID: CGWindowID)
    func windowManager(_ manager: WindowManager, didFocusWindow windowID: CGWindowID)
    func windowManagerNeedsRelayout(_ manager: WindowManager)
}

final class WindowManager {
    weak var delegate: WindowManagerDelegate?

    private var windows: [CGWindowID: WindowNode] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private var appElements: [pid_t: AXUIElement] = [:]

    var allWindows: [WindowNode] {
        Array(windows.values)
    }

    func window(for id: CGWindowID) -> WindowNode? {
        windows[id]
    }

    // MARK: - Bootstrap

    func bootstrap() {
        NSLog("[SonicLand] Bootstrapping window manager...")

        // Enumerate running applications
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }

        for app in apps {
            addApplication(app)
        }

        NSLog("[SonicLand] Bootstrap complete. Tracking \(windows.count) windows across \(observers.count) apps.")

        // Watch for app launch/terminate
        let wsNotificationCenter = NSWorkspace.shared.notificationCenter
        wsNotificationCenter.addObserver(
            self, selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil
        )
        wsNotificationCenter.addObserver(
            self, selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil
        )
    }

    // MARK: - Application Tracking

    private func addApplication(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard pid > 0 else { return }
        guard observers[pid] == nil else { return }

        let appElement = AXUIElementCreateApplication(pid)
        appElements[pid] = appElement

        // Create observer
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let observer = AccessibilityWrapper.createObserver(for: pid, callback: axObserverCallback) else {
            return
        }

        AccessibilityWrapper.registerObserver(
            observer, element: appElement,
            notifications: AccessibilityWrapper.windowNotifications,
            refcon: refcon
        )
        observers[pid] = observer

        // Enumerate existing windows
        let axWindows = AccessibilityWrapper.getWindows(for: pid)
        for axWindow in axWindows {
            addWindow(axWindow, pid: pid, app: app)
        }
    }

    private func removeApplication(pid: pid_t) {
        // Remove observer
        if let observer = observers[pid], let element = appElements[pid] {
            AccessibilityWrapper.unregisterObserver(observer, element: element, notifications: AccessibilityWrapper.windowNotifications)
        }
        observers.removeValue(forKey: pid)
        appElements.removeValue(forKey: pid)

        // Remove all windows belonging to this app
        let appWindowIDs = windows.filter { $0.value.pid == pid }.map { $0.key }
        for windowID in appWindowIDs {
            windows.removeValue(forKey: windowID)
            delegate?.windowManager(self, didRemoveWindow: windowID)
        }
    }

    // MARK: - Window Tracking

    private func addWindow(_ axElement: AXUIElement, pid: pid_t, app: NSRunningApplication) {
        guard AccessibilityWrapper.isWindowTileable(axElement) else { return }
        guard let windowID = AccessibilityWrapper.getWindowID(axElement) else { return }
        guard windows[windowID] == nil else { return }
        guard let frame = AccessibilityWrapper.getWindowFrame(axElement) else { return }

        let title = AccessibilityWrapper.getWindowTitle(axElement)
        let bundleID = app.bundleIdentifier ?? ""
        let appName = app.localizedName ?? ""

        let node = WindowNode(
            windowID: windowID,
            axElement: axElement,
            pid: pid,
            bundleID: bundleID,
            appName: appName,
            title: title,
            frame: frame
        )

        node.isMinimized = AccessibilityWrapper.isMinimized(axElement)
        node.isFullscreen = AccessibilityWrapper.isFullscreen(axElement)

        windows[windowID] = node

        NSLog("[SonicLand] Tracked window: \(appName) - \(title ?? "untitled") (ID: \(windowID))")
        delegate?.windowManager(self, didDetectNewWindow: node)
    }

    // MARK: - Refresh

    /// Refresh the state of all tracked windows (called each tick).
    func refreshWindowStates() {
        var removedIDs: [CGWindowID] = []

        for (windowID, node) in windows {
            guard let frame = AccessibilityWrapper.getWindowFrame(node.axElement) else {
                // Window is gone
                removedIDs.append(windowID)
                continue
            }
            node.frame = frame
            node.title = AccessibilityWrapper.getWindowTitle(node.axElement)
            node.isMinimized = AccessibilityWrapper.isMinimized(node.axElement)
            node.isFullscreen = AccessibilityWrapper.isFullscreen(node.axElement)
        }

        for windowID in removedIDs {
            windows.removeValue(forKey: windowID)
            delegate?.windowManager(self, didRemoveWindow: windowID)
        }
    }

    // MARK: - Notifications

    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        guard app.activationPolicy == .regular else { return }
        NSLog("[SonicLand] App launched: \(app.localizedName ?? "unknown")")
        addApplication(app)
    }

    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        NSLog("[SonicLand] App terminated: \(app.localizedName ?? "unknown")")
        removeApplication(pid: app.processIdentifier)
    }

    // MARK: - AXObserver Handling

    func handleAXNotification(_ notification: String, element: AXUIElement) {
        switch notification {
        case kAXWindowCreatedNotification:
            // Find the app for this element
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            if let app = NSRunningApplication(processIdentifier: pid) {
                addWindow(element, pid: pid, app: app)
            }

        case kAXUIElementDestroyedNotification:
            if let windowID = AccessibilityWrapper.getWindowID(element) {
                if windows.removeValue(forKey: windowID) != nil {
                    delegate?.windowManager(self, didRemoveWindow: windowID)
                }
            }

        case kAXFocusedWindowChangedNotification:
            if let windowID = AccessibilityWrapper.getWindowID(element) {
                delegate?.windowManager(self, didFocusWindow: windowID)
            }

        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            if let windowID = AccessibilityWrapper.getWindowID(element),
               let node = windows[windowID],
               let frame = AccessibilityWrapper.getWindowFrame(element) {
                node.frame = frame
            }

        case kAXTitleChangedNotification:
            if let windowID = AccessibilityWrapper.getWindowID(element),
               let node = windows[windowID] {
                node.title = AccessibilityWrapper.getWindowTitle(element)
            }

        case kAXWindowMiniaturizedNotification:
            if let windowID = AccessibilityWrapper.getWindowID(element),
               let node = windows[windowID] {
                node.isMinimized = true
                NSLog("[SonicLand] Window minimized: \(node.appName)")
                delegate?.windowManagerNeedsRelayout(self)
            }

        case kAXWindowDeminiaturizedNotification:
            if let windowID = AccessibilityWrapper.getWindowID(element),
               let node = windows[windowID] {
                node.isMinimized = false
                NSLog("[SonicLand] Window unminimized: \(node.appName)")
                delegate?.windowManagerNeedsRelayout(self)
            }

        default:
            break
        }
    }
}

// MARK: - AXObserver C Callback

private func axObserverCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon = refcon else { return }
    let manager = Unmanaged<WindowManager>.fromOpaque(refcon).takeUnretainedValue()
    manager.handleAXNotification(notification as String, element: element)
}
