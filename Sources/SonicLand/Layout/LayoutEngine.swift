import CoreGraphics

final class LayoutEngine {
    var gapsInner: CGFloat { gaps.inner }
    var gapsOuter: CGFloat { gaps.outer }
    private var gaps: GapConfig

    init(config: ConfigModel) {
        self.gaps = GapConfig(inner: config.general.gapsIn, outer: config.general.gapsOut)
    }

    func updateConfig(_ config: ConfigModel) {
        self.gaps = GapConfig(inner: config.general.gapsIn, outer: config.general.gapsOut)
    }

    /// Compute layout frames for windows in the given rect.
    func computeLayout(windowIDs: [CGWindowID], in rect: CGRect, tree: BSPTree) -> [CGWindowID: CGRect] {
        return tree.computeFrames(in: rect, gaps: gaps)
    }

    /// Insert a window into a BSP tree.
    func insertWindow(_ windowID: CGWindowID, into tree: inout BSPTree) {
        tree.insert(windowID: windowID)
    }

    /// Remove a window from a BSP tree.
    func removeWindow(_ windowID: CGWindowID, from tree: inout BSPTree) {
        tree.remove(windowID: windowID)
    }

    /// Move a window in a direction.
    func moveWindow(_ windowID: CGWindowID, direction: Direction, in tree: inout BSPTree) {
        tree.moveWindow(windowID, direction: direction)
    }

    /// Find the neighbor of a window in a direction.
    func findNeighbor(of windowID: CGWindowID, direction: Direction, in tree: BSPTree) -> CGWindowID? {
        return tree.findNeighbor(of: windowID, direction: direction)
    }

    /// Toggle the split direction at the parent of a window.
    func toggleSplitDirection(at windowID: CGWindowID, in tree: inout BSPTree) {
        tree.toggleDirection(for: windowID)
    }
}
