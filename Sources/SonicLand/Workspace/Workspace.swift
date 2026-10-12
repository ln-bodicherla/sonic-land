import CoreGraphics

/// Workspace type/purpose hint.
enum WorkspaceType: String, Codable, CaseIterable {
    case general
    case coding
    case communication
    case research
    case design
    case media
    case system
}

/// Represents a virtual workspace (independent of macOS Spaces).
struct Workspace {
    let id: Int
    var name: String
    var monitorID: UInt32
    var windowIDs: [CGWindowID]
    var layoutTree: BSPTree
    var focusedWindowID: CGWindowID?
    var isVisible: Bool
    var layoutMode: LayoutMode
    var workspaceType: WorkspaceType
    var masterRatio: CGFloat
    var masterCount: Int
    var gapsOverride: GapConfig?
    var doNotDisturb: Bool          // Suppress auto-retile
    var startupActions: [String]    // Commands to run when workspace activates
    var hotkeys: [String: String]   // Workspace-specific hotkey overrides

    init(id: Int, name: String = "", monitorID: UInt32 = 0) {
        self.id = id
        self.name = name.isEmpty ? "Workspace \(id)" : name
        self.monitorID = monitorID
        self.windowIDs = []
        self.layoutTree = BSPTree()
        self.focusedWindowID = nil
        self.isVisible = false
        self.layoutMode = .bsp
        self.workspaceType = .general
        self.masterRatio = 0.55
        self.masterCount = 1
        self.gapsOverride = nil
        self.doNotDisturb = false
        self.startupActions = []
        self.hotkeys = [:]
    }
}

/// A workspace template for quick setup.
struct WorkspaceTemplate: Codable {
    var name: String
    var layoutMode: String
    var workspaceType: String
    var masterRatio: CGFloat
    var masterCount: Int
    var appAssignments: [String]  // Bundle IDs to auto-assign
    var startupActions: [String]

    init(name: String, layoutMode: LayoutMode = .bsp, workspaceType: WorkspaceType = .general) {
        self.name = name
        self.layoutMode = layoutMode.rawValue
        self.workspaceType = workspaceType.rawValue
        self.masterRatio = 0.55
        self.masterCount = 1
        self.appAssignments = []
        self.startupActions = []
    }
}
