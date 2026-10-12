import AppKit
import CoreGraphics

final class WorkspaceManager {
    private var workspaces: [Int: Workspace] = [:]
    private var activeWorkspacePerMonitor: [UInt32: Int] = [:]
    private let monitorManager: MonitorManager
    private let defaultWorkspaceCount = 9
    private var templates: [String: WorkspaceTemplate] = [:]
    private var nextDynamicID = 100

    var activeWorkspace: Workspace? {
        guard let monitor = monitorManager.primaryMonitor,
              let wsID = activeWorkspacePerMonitor[monitor.id] else { return nil }
        return workspaces[wsID]
    }

    var activeWorkspaceMutable: Workspace? {
        get {
            guard let monitor = monitorManager.primaryMonitor,
                  let wsID = activeWorkspacePerMonitor[monitor.id] else { return nil }
            return workspaces[wsID]
        }
        set {
            if let ws = newValue {
                workspaces[ws.id] = ws
            }
        }
    }

    var allWorkspaces: [Workspace] {
        Array(workspaces.values).sorted { $0.id < $1.id }
    }

    func activeWorkspaceID(for monitorID: UInt32) -> Int? {
        return activeWorkspacePerMonitor[monitorID]
    }

    init(monitorManager: MonitorManager) {
        self.monitorManager = monitorManager
    }

    // MARK: - Workspace CRUD

    func ensureDefaultWorkspace(for monitorID: UInt32) {
        for i in 1...defaultWorkspaceCount {
            if workspaces[i] == nil {
                workspaces[i] = Workspace(id: i, monitorID: monitorID)
            }
        }

        if activeWorkspacePerMonitor[monitorID] == nil {
            if let existingWS = (1...defaultWorkspaceCount).first(where: { workspaces[$0]?.monitorID == monitorID }) {
                activeWorkspacePerMonitor[monitorID] = existingWS
                workspaces[existingWS]?.isVisible = true
                NSLog("[SonicLand] Monitor \(monitorID): active workspace = \(existingWS)")
            } else {
                let monitorsWithWS = Set(activeWorkspacePerMonitor.values)
                if let freeWS = (1...defaultWorkspaceCount).first(where: { !monitorsWithWS.contains($0) }) {
                    workspaces[freeWS]?.monitorID = monitorID
                    activeWorkspacePerMonitor[monitorID] = freeWS
                    workspaces[freeWS]?.isVisible = true
                    NSLog("[SonicLand] Monitor \(monitorID): assigned workspace = \(freeWS)")
                }
            }
        }
    }

    func workspace(for id: Int) -> Workspace? {
        return workspaces[id]
    }

    func updateWorkspace(_ ws: Workspace) {
        workspaces[ws.id] = ws
    }

    // MARK: - Dynamic Workspace Creation

    func createWorkspace(name: String, monitorID: UInt32, layoutMode: LayoutMode = .bsp) -> Workspace {
        let id = nextDynamicID
        nextDynamicID += 1

        var ws = Workspace(id: id, name: name, monitorID: monitorID)
        ws.layoutMode = layoutMode
        workspaces[id] = ws

        EventLog.shared.log(.workspaceCreated, "Created workspace '\(name)' (ID: \(id))")
        return ws
    }

    func deleteWorkspace(_ id: Int) {
        guard id > defaultWorkspaceCount else { return } // Don't delete default workspaces
        workspaces.removeValue(forKey: id)
    }

    func renameWorkspace(_ id: Int, to name: String) {
        workspaces[id]?.name = name
        EventLog.shared.log(.workspaceRenamed, "Renamed workspace \(id) to '\(name)'")
    }

    // MARK: - Templates

    func registerTemplate(_ template: WorkspaceTemplate) {
        templates[template.name] = template
    }

    func applyTemplate(_ templateName: String, to workspaceID: Int) {
        guard let template = templates[templateName],
              var ws = workspaces[workspaceID] else { return }

        ws.name = template.name
        ws.layoutMode = LayoutMode(rawValue: template.layoutMode) ?? .bsp
        ws.workspaceType = WorkspaceType(rawValue: template.workspaceType) ?? .general
        ws.masterRatio = template.masterRatio
        ws.masterCount = template.masterCount
        ws.startupActions = template.startupActions
        workspaces[workspaceID] = ws
    }

    func allTemplates() -> [WorkspaceTemplate] {
        Array(templates.values)
    }

    // MARK: - Navigation

    func switchTo(workspaceID: Int) {
        guard let monitor = monitorManager.primaryMonitor else { return }
        guard workspaces[workspaceID] != nil else { return }

        if let currentID = activeWorkspacePerMonitor[monitor.id] {
            workspaces[currentID]?.isVisible = false
        }

        activeWorkspacePerMonitor[monitor.id] = workspaceID
        workspaces[workspaceID]?.isVisible = true

        EventLog.shared.log(.workspaceSwitched,
            "Switched to workspace \(workspaceID)",
            details: ["name": workspaces[workspaceID]?.name ?? ""])
    }

    /// Switch to next non-empty workspace.
    func switchToNext() -> Int? {
        guard let monitor = monitorManager.primaryMonitor,
              let currentID = activeWorkspacePerMonitor[monitor.id] else { return nil }

        let sorted = allWorkspaces.filter { $0.monitorID == monitor.id }
        guard let idx = sorted.firstIndex(where: { $0.id == currentID }) else { return nil }

        let nextIdx = (idx + 1) % sorted.count
        let targetID = sorted[nextIdx].id
        switchTo(workspaceID: targetID)
        return targetID
    }

    /// Switch to previous workspace.
    func switchToPrevious() -> Int? {
        guard let monitor = monitorManager.primaryMonitor,
              let currentID = activeWorkspacePerMonitor[monitor.id] else { return nil }

        let sorted = allWorkspaces.filter { $0.monitorID == monitor.id }
        guard let idx = sorted.firstIndex(where: { $0.id == currentID }) else { return nil }

        let prevIdx = (idx - 1 + sorted.count) % sorted.count
        let targetID = sorted[prevIdx].id
        switchTo(workspaceID: targetID)
        return targetID
    }

    /// Switch to most recently active workspace.
    func switchToRecent() -> Int? {
        // Simple: switch to previous (could be enhanced with history tracking)
        return switchToPrevious()
    }

    // MARK: - Window Management

    func addWindow(_ windowID: CGWindowID, to workspaceID: Int) {
        workspaces[workspaceID]?.windowIDs.append(windowID)
    }

    func moveWindow(windowID: CGWindowID, to workspaceID: Int) {
        for (id, var ws) in workspaces {
            if let index = ws.windowIDs.firstIndex(of: windowID) {
                ws.windowIDs.remove(at: index)
                if ws.focusedWindowID == windowID {
                    ws.focusedWindowID = ws.windowIDs.first
                }
                workspaces[id] = ws
            }
        }

        workspaces[workspaceID]?.windowIDs.append(windowID)
        EventLog.shared.log(.windowMoved, "Moved window \(windowID) to workspace \(workspaceID)")
    }

    func setFocusedWindow(_ windowID: CGWindowID, in workspaceID: Int) {
        workspaces[workspaceID]?.focusedWindowID = windowID
    }

    /// Get workspaces that contain windows from a specific app.
    func workspacesContaining(bundleID: String, windowManager: WindowManager) -> [Int] {
        var result: [Int] = []
        for ws in allWorkspaces {
            for wid in ws.windowIDs {
                if let w = windowManager.window(for: wid), w.bundleID == bundleID {
                    result.append(ws.id)
                    break
                }
            }
        }
        return result
    }

    /// Get sticky windows that should appear in all workspaces.
    func stickyWindows(windowManager: WindowManager) -> [CGWindowID] {
        windowManager.allWindows.filter { $0.isSticky }.map { $0.windowID }
    }

    // MARK: - Layout Mode

    func setLayoutMode(_ mode: LayoutMode, for workspaceID: Int) {
        workspaces[workspaceID]?.layoutMode = mode
        EventLog.shared.log(.layoutChanged,
            "Layout changed to \(mode.displayName) for workspace \(workspaceID)")
    }

    func cycleLayout(for workspaceID: Int) -> LayoutMode? {
        guard var ws = workspaces[workspaceID] else { return nil }
        ws.layoutMode = ws.layoutMode.next
        workspaces[workspaceID] = ws
        EventLog.shared.log(.layoutChanged,
            "Cycled layout to \(ws.layoutMode.displayName) for workspace \(workspaceID)")
        return ws.layoutMode
    }

    // MARK: - Master Controls

    func adjustMasterRatio(for workspaceID: Int, delta: CGFloat) {
        guard var ws = workspaces[workspaceID] else { return }
        ws.masterRatio = max(0.1, min(0.9, ws.masterRatio + delta))
        workspaces[workspaceID] = ws
    }

    func adjustMasterCount(for workspaceID: Int, delta: Int) {
        guard var ws = workspaces[workspaceID] else { return }
        ws.masterCount = max(1, ws.masterCount + delta)
        workspaces[workspaceID] = ws
    }

    // MARK: - Workspace Configuration

    func applyWorkspaceConfig(_ configs: [Int: ConfigModel.WorkspaceConfig]) {
        for (id, config) in configs {
            guard var ws = workspaces[id] else { continue }
            if let name = config.name { ws.name = name }
            if let layout = config.layout { ws.layoutMode = LayoutMode(rawValue: layout) ?? ws.layoutMode }
            if let type = config.type { ws.workspaceType = WorkspaceType(rawValue: type) ?? ws.workspaceType }
            if let ratio = config.masterRatio { ws.masterRatio = ratio }
            if let count = config.masterCount { ws.masterCount = count }
            if let gIn = config.gapsIn, let gOut = config.gapsOut {
                ws.gapsOverride = GapConfig(inner: gIn, outer: gOut)
            }
            ws.startupActions = config.startupActions
            workspaces[id] = ws
        }
    }
}
