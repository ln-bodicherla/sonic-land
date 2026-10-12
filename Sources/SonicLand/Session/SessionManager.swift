import Foundation
import AppKit

/// Persisted state for a single workspace.
struct WorkspaceState: Codable {
    let id: Int
    var name: String
    var layoutMode: String
    var masterRatio: CGFloat
    var masterCount: Int
    var windowStates: [WindowState]

    struct WindowState: Codable {
        let bundleID: String
        let appName: String
        let title: String?
        let isFloating: Bool
        let frame: CodableRect
        let workspaceID: Int
    }

    struct CodableRect: Codable {
        let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat

        init(_ rect: CGRect) {
            self.x = rect.origin.x
            self.y = rect.origin.y
            self.width = rect.size.width
            self.height = rect.size.height
        }

        var cgRect: CGRect {
            CGRect(x: x, y: y, width: width, height: height)
        }
    }
}

/// Full session state across all workspaces.
struct SessionState: Codable {
    var workspaces: [WorkspaceState]
    var activeWorkspaceIDs: [UInt32: Int]  // monitorID -> workspaceID
    var tilingMode: String
    var savedAt: Date
}

/// Manages session persistence — save/restore workspace layouts and window positions.
final class SessionManager {
    private let sessionFile: URL

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sonicland")
        self.sessionFile = configDir.appendingPathComponent("session.json")
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
    }

    func saveSession(
        workspaceManager: WorkspaceManager,
        windowManager: WindowManager,
        tilingMode: TilingMode
    ) {
        var workspaceStates: [WorkspaceState] = []

        for ws in workspaceManager.allWorkspaces {
            var windowStates: [WorkspaceState.WindowState] = []

            for windowID in ws.windowIDs {
                guard let window = windowManager.window(for: windowID) else { continue }
                windowStates.append(WorkspaceState.WindowState(
                    bundleID: window.bundleID,
                    appName: window.appName,
                    title: window.title,
                    isFloating: window.isFloating,
                    frame: WorkspaceState.CodableRect(window.targetFrame ?? window.frame),
                    workspaceID: ws.id
                ))
            }

            workspaceStates.append(WorkspaceState(
                id: ws.id,
                name: ws.name,
                layoutMode: ws.layoutMode.rawValue,
                masterRatio: ws.masterRatio,
                masterCount: ws.masterCount,
                windowStates: windowStates
            ))
        }

        var activeIDs: [UInt32: Int] = [:]
        for ws in workspaceManager.allWorkspaces where ws.isVisible {
            activeIDs[ws.monitorID] = ws.id
        }

        let session = SessionState(
            workspaces: workspaceStates,
            activeWorkspaceIDs: activeIDs,
            tilingMode: tilingMode.rawValue,
            savedAt: Date()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(session) {
            try? data.write(to: sessionFile)
            EventLog.shared.log(.sessionSaved, "Session saved with \(workspaceStates.count) workspaces")
        }
    }

    func loadSession() -> SessionState? {
        guard let data = try? Data(contentsOf: sessionFile),
              let session = try? JSONDecoder().decode(SessionState.self, from: data) else {
            return nil
        }
        EventLog.shared.log(.sessionRestored, "Loaded session from \(session.savedAt)")
        return session
    }

    func restoreWorkspaceMetadata(
        session: SessionState,
        workspaceManager: WorkspaceManager
    ) {
        for wsState in session.workspaces {
            guard var ws = workspaceManager.workspace(for: wsState.id) else { continue }
            ws.name = wsState.name
            ws.layoutMode = LayoutMode(rawValue: wsState.layoutMode) ?? .bsp
            ws.masterRatio = wsState.masterRatio
            ws.masterCount = wsState.masterCount
            workspaceManager.updateWorkspace(ws)
        }
    }

    func matchAndRestoreWindows(
        session: SessionState,
        windowManager: WindowManager,
        workspaceManager: WorkspaceManager
    ) {
        // Match running windows to saved window states by bundleID
        var unmatched = windowManager.allWindows

        for wsState in session.workspaces {
            for savedWindow in wsState.windowStates {
                // Find best matching window
                if let idx = unmatched.firstIndex(where: { $0.bundleID == savedWindow.bundleID }) {
                    let window = unmatched[idx]
                    window.workspaceID = savedWindow.workspaceID
                    window.isFloating = savedWindow.isFloating
                    unmatched.remove(at: idx)
                }
            }
        }
    }

    func deleteSession() {
        try? FileManager.default.removeItem(at: sessionFile)
    }
}
