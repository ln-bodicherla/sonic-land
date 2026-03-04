import AppKit

final class MonitorManager {
    private(set) var monitors: [Monitor] = []

    init() {
        refresh()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Refresh the monitor list from NSScreen.
    func refresh() {
        monitors = NSScreen.screens.map { Monitor(screen: $0) }
        NSLog("[SonicLand] Detected \(monitors.count) monitor(s):")
        for monitor in monitors {
            NSLog("[SonicLand]   \(monitor.name) — frame: \(monitor.frame), visible: \(monitor.visibleFrame)")
        }
    }

    /// Get monitor by display ID.
    func monitor(for displayID: UInt32) -> Monitor? {
        monitors.first { $0.id == displayID }
    }

    /// Get the primary monitor.
    var primaryMonitor: Monitor? {
        monitors.first
    }

    /// Find which monitor contains the given point (in AX coordinates).
    func monitorContaining(point: CGPoint) -> Monitor? {
        monitors.first { $0.frame.contains(point) }
    }

    /// Find which monitor contains the center of the given rect.
    func monitorContaining(rect: CGRect) -> Monitor? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return monitorContaining(point: center) ?? primaryMonitor
    }

    /// Get monitors eligible for tiling based on config setting.
    /// - "all": all monitors
    /// - "built-in": only built-in display
    /// - "external": only external displays
    /// - Any other string: match by monitor name (case-insensitive substring)
    func tilingMonitors(filter: String) -> [Monitor] {
        let filterLower = filter.lowercased().trimmingCharacters(in: .whitespaces)
        switch filterLower {
        case "all", "":
            return monitors
        case "built-in", "builtin", "internal":
            return monitors.filter { $0.name.lowercased().contains("built-in") || $0.name.lowercased().contains("retina") }
        case "external":
            return monitors.filter { !$0.name.lowercased().contains("built-in") && !$0.name.lowercased().contains("retina") }
        default:
            return monitors.filter { $0.name.lowercased().contains(filterLower) }
        }
    }

    @objc private func screensDidChange(_ notification: Notification) {
        NSLog("[SonicLand] Screen configuration changed.")
        refresh()
    }
}
