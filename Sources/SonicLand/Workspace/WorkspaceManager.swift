import AppKit
import CoreGraphics

final class WorkspaceManager {
    private var workspaces: [Int: Workspace] = [:]
    private var activeWorkspacePerMonitor: [UInt32: Int] = [:]
    private let monitorManager: MonitorManager
    private let defaultWorkspaceCount = 9

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

    /// Get the active workspace ID for a specific monitor.
    func activeWorkspaceID(for monitorID: UInt32) -> Int? {
        return activeWorkspacePerMonitor[monitorID]
    }

    init(monitorManager: MonitorManager) {
        self.monitorManager = monitorManager
    }

    // MARK: - Workspace CRUD

    func ensureDefaultWorkspace(for monitorID: UInt32) {
        // Create workspaces 1-9 if they don't exist yet (assigned to first monitor)
        for i in 1...defaultWorkspaceCount {
            if workspaces[i] == nil {
                workspaces[i] = Workspace(id: i, monitorID: monitorID)
            }
        }

        // Ensure this monitor has an active workspace
        if activeWorkspacePerMonitor[monitorID] == nil {
            // Find an existing workspace for this monitor, or reassign the first unused one
            if let existingWS = (1...defaultWorkspaceCount).first(where: { workspaces[$0]?.monitorID == monitorID }) {
                activeWorkspacePerMonitor[monitorID] = existingWS
                workspaces[existingWS]?.isVisible = true
                NSLog("[SonicLand] Monitor \(monitorID): active workspace = \(existingWS)")
            } else {
                // No workspace assigned to this monitor yet — take the first inactive one
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

    // MARK: - Navigation

    func switchTo(workspaceID: Int) {
        guard let monitor = monitorManager.primaryMonitor else { return }
        guard let targetWS = workspaces[workspaceID] else { return }

        // Mark current workspace as not visible
        if let currentID = activeWorkspacePerMonitor[monitor.id] {
            workspaces[currentID]?.isVisible = false
        }

        // Switch
        activeWorkspacePerMonitor[monitor.id] = workspaceID
        workspaces[workspaceID]?.isVisible = true

        NSLog("[SonicLand] Switched to workspace \(workspaceID) (\(targetWS.name))")
    }

    // MARK: - Window Management

    func addWindow(_ windowID: CGWindowID, to workspaceID: Int) {
        workspaces[workspaceID]?.windowIDs.append(windowID)
    }

    func moveWindow(windowID: CGWindowID, to workspaceID: Int) {
        // Remove from current workspace
        for (id, var ws) in workspaces {
            if let index = ws.windowIDs.firstIndex(of: windowID) {
                ws.windowIDs.remove(at: index)
                if ws.focusedWindowID == windowID {
                    ws.focusedWindowID = ws.windowIDs.first
                }
                workspaces[id] = ws
            }
        }

        // Add to target workspace
        workspaces[workspaceID]?.windowIDs.append(windowID)
        NSLog("[SonicLand] Moved window \(windowID) to workspace \(workspaceID)")
    }

    func setFocusedWindow(_ windowID: CGWindowID, in workspaceID: Int) {
        workspaces[workspaceID]?.focusedWindowID = windowID
    }
}
