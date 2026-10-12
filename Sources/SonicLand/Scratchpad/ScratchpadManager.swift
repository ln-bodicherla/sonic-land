import AppKit
import CoreGraphics

/// A scratchpad definition — a hidden, toggle-able window or app.
struct Scratchpad: Codable {
    let name: String
    let appName: String?
    let bundleID: String?
    let command: String?
    var defaultWidth: CGFloat
    var defaultHeight: CGFloat
    var centerOnShow: Bool
    var autoHideOnFocusLost: Bool

    init(name: String, appName: String? = nil, bundleID: String? = nil,
         command: String? = nil, defaultWidth: CGFloat = 800,
         defaultHeight: CGFloat = 600, centerOnShow: Bool = true,
         autoHideOnFocusLost: Bool = false) {
        self.name = name
        self.appName = appName
        self.bundleID = bundleID
        self.command = command
        self.defaultWidth = defaultWidth
        self.defaultHeight = defaultHeight
        self.centerOnShow = centerOnShow
        self.autoHideOnFocusLost = autoHideOnFocusLost
    }
}

/// Manages scratchpad windows — hidden summonable windows.
final class ScratchpadManager {
    private var scratchpads: [String: Scratchpad] = [:]
    private var visibleScratchpads: Set<String> = []
    private var scratchpadWindows: [String: CGWindowID] = [:]

    func register(_ scratchpad: Scratchpad) {
        scratchpads[scratchpad.name] = scratchpad
        EventLog.shared.log(.scratchpadToggled, "Registered scratchpad: \(scratchpad.name)")
    }

    func unregisterAll() {
        scratchpads.removeAll()
        visibleScratchpads.removeAll()
        scratchpadWindows.removeAll()
    }

    func allScratchpads() -> [Scratchpad] {
        Array(scratchpads.values)
    }

    func isVisible(_ name: String) -> Bool {
        visibleScratchpads.contains(name)
    }

    func isScratchpadWindow(_ windowID: CGWindowID) -> Bool {
        scratchpadWindows.values.contains(windowID)
    }

    func scratchpadName(for windowID: CGWindowID) -> String? {
        scratchpadWindows.first { $0.value == windowID }?.key
    }

    /// Toggle a scratchpad. Returns the window ID if showing, nil if hiding.
    func toggle(
        name: String,
        windowManager: WindowManager,
        monitorManager: MonitorManager
    ) -> (windowID: CGWindowID?, action: ScratchpadAction) {
        guard let scratchpad = scratchpads[name] else {
            return (nil, .notFound)
        }

        if let windowID = scratchpadWindows[name],
           let window = windowManager.window(for: windowID) {
            // Window exists — toggle visibility
            if visibleScratchpads.contains(name) {
                // Hide
                AccessibilityWrapper.setWindowPosition(
                    window.axElement,
                    position: CGPoint(x: -10000, y: -10000)
                )
                visibleScratchpads.remove(name)
                EventLog.shared.log(.scratchpadToggled, "Hidden scratchpad: \(name)")
                return (windowID, .hidden)
            } else {
                // Show
                showScratchpadWindow(window, scratchpad: scratchpad, monitorManager: monitorManager)
                visibleScratchpads.insert(name)
                EventLog.shared.log(.scratchpadToggled, "Shown scratchpad: \(name)")
                return (windowID, .shown)
            }
        }

        // Try to find matching window by app name or bundle ID
        let matchingWindow = windowManager.allWindows.first { w in
            if let bundleID = scratchpad.bundleID,
               w.bundleID.lowercased() == bundleID.lowercased() {
                return true
            }
            if let appName = scratchpad.appName,
               w.appName.lowercased().contains(appName.lowercased()) {
                return true
            }
            return false
        }

        if let window = matchingWindow {
            scratchpadWindows[name] = window.windowID
            showScratchpadWindow(window, scratchpad: scratchpad, monitorManager: monitorManager)
            visibleScratchpads.insert(name)
            EventLog.shared.log(.scratchpadToggled, "Shown scratchpad: \(name) (found existing window)")
            return (window.windowID, .shown)
        }

        // Launch the app if we have a command or bundle ID
        if let command = scratchpad.command {
            launchCommand(command)
            return (nil, .launching)
        } else if let bundleID = scratchpad.bundleID,
                  let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            return (nil, .launching)
        }

        return (nil, .notFound)
    }

    func handleFocusLost(windowID: CGWindowID, windowManager: WindowManager) {
        guard let name = scratchpadName(for: windowID),
              let scratchpad = scratchpads[name],
              scratchpad.autoHideOnFocusLost,
              visibleScratchpads.contains(name) else { return }

        if let window = windowManager.window(for: windowID) {
            AccessibilityWrapper.setWindowPosition(
                window.axElement,
                position: CGPoint(x: -10000, y: -10000)
            )
        }
        visibleScratchpads.remove(name)
        EventLog.shared.log(.scratchpadToggled, "Auto-hidden scratchpad: \(name)")
    }

    func assignWindow(_ windowID: CGWindowID, toScratchpad name: String) {
        scratchpadWindows[name] = windowID
    }

    private func showScratchpadWindow(
        _ window: WindowNode,
        scratchpad: Scratchpad,
        monitorManager: MonitorManager
    ) {
        if scratchpad.centerOnShow, let monitor = monitorManager.primaryMonitor {
            let x = monitor.visibleFrame.midX - scratchpad.defaultWidth / 2
            let y = monitor.visibleFrame.midY - scratchpad.defaultHeight / 2
            let frame = CGRect(x: x, y: y, width: scratchpad.defaultWidth, height: scratchpad.defaultHeight)
            AccessibilityWrapper.setWindowFrame(window.axElement, frame: frame)
        }
        AccessibilityWrapper.focusWindow(window.axElement, pid: window.pid)
    }

    private func launchCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", command]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }
}

enum ScratchpadAction {
    case shown
    case hidden
    case launching
    case notFound
}
