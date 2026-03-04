import CoreGraphics

/// Represents a virtual workspace (independent of macOS Spaces).
struct Workspace {
    let id: Int
    var name: String
    var monitorID: UInt32
    var windowIDs: [CGWindowID]
    var layoutTree: BSPTree
    var focusedWindowID: CGWindowID?
    var isVisible: Bool

    init(id: Int, name: String = "", monitorID: UInt32 = 0) {
        self.id = id
        self.name = name.isEmpty ? "Workspace \(id)" : name
        self.monitorID = monitorID
        self.windowIDs = []
        self.layoutTree = BSPTree()
        self.focusedWindowID = nil
        self.isVisible = false
    }
}
