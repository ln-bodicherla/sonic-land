import CoreGraphics

/// A node in the BSP tree. Either a window leaf or an internal split.
indirect enum LayoutNode {
    case empty
    case window(CGWindowID)
    case split(direction: SplitDirection, ratio: CGFloat, first: LayoutNode, second: LayoutNode)

    /// Check if this node contains a specific window.
    func contains(windowID: CGWindowID) -> Bool {
        switch self {
        case .empty:
            return false
        case .window(let id):
            return id == windowID
        case .split(_, _, let first, let second):
            return first.contains(windowID: windowID) || second.contains(windowID: windowID)
        }
    }

    /// Count the number of windows in this subtree.
    var windowCount: Int {
        switch self {
        case .empty:
            return 0
        case .window:
            return 1
        case .split(_, _, let first, let second):
            return first.windowCount + second.windowCount
        }
    }

    /// Get all window IDs in this subtree.
    var allWindowIDs: [CGWindowID] {
        switch self {
        case .empty:
            return []
        case .window(let id):
            return [id]
        case .split(_, _, let first, let second):
            return first.allWindowIDs + second.allWindowIDs
        }
    }
}
