import CoreGraphics

final class LayoutEngine {
    var gapsInner: CGFloat { gaps.inner }
    var gapsOuter: CGFloat { gaps.outer }
    private var gaps: GapConfig
    private var defaultLayout: LayoutMode
    private var defaultMasterRatio: CGFloat
    private var defaultMasterCount: Int

    private let layouts: [LayoutMode: TilingLayout] = [
        .masterStack: MasterStackLayout(),
        .columns: ColumnsLayout(),
        .rows: RowsLayout(),
        .monocle: MonocleLayout(),
    ]

    init(config: ConfigModel) {
        self.gaps = GapConfig(inner: config.general.gapsIn, outer: config.general.gapsOut)
        self.defaultLayout = LayoutMode(rawValue: config.general.defaultLayout) ?? .bsp
        self.defaultMasterRatio = config.general.masterRatio
        self.defaultMasterCount = config.general.masterCount
    }

    func updateConfig(_ config: ConfigModel) {
        self.gaps = GapConfig(inner: config.general.gapsIn, outer: config.general.gapsOut)
        self.defaultLayout = LayoutMode(rawValue: config.general.defaultLayout) ?? .bsp
        self.defaultMasterRatio = config.general.masterRatio
        self.defaultMasterCount = config.general.masterCount
    }

    var defaultLayoutMode: LayoutMode { defaultLayout }

    /// Compute layout frames using the appropriate layout strategy.
    func computeLayout(
        windowIDs: [CGWindowID],
        in rect: CGRect,
        workspace: Workspace
    ) -> [CGWindowID: CGRect] {
        let effectiveGaps = workspace.gapsOverride ?? gaps
        let mode = workspace.layoutMode

        switch mode {
        case .bsp:
            return workspace.layoutTree.computeFrames(in: rect, gaps: effectiveGaps)

        case .floating:
            return [:]  // No auto-layout for floating mode

        default:
            if let layout = layouts[mode] {
                // For non-BSP layouts, order pinned windows first
                let ordered = windowIDs
                // Move pinned windows to front (they become master)
                // This is handled by the caller providing ordered IDs

                return layout.computeFrames(
                    windowIDs: ordered,
                    in: rect,
                    gaps: effectiveGaps,
                    masterRatio: workspace.masterRatio,
                    masterCount: workspace.masterCount
                )
            }
            return workspace.layoutTree.computeFrames(in: rect, gaps: effectiveGaps)
        }
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

    /// Find neighbor using ordered window list (for non-BSP layouts).
    func findNeighbor(of windowID: CGWindowID, direction: Direction, in windowIDs: [CGWindowID]) -> CGWindowID? {
        guard let idx = windowIDs.firstIndex(of: windowID) else { return nil }
        let targetIdx: Int
        switch direction {
        case .left, .up:
            targetIdx = idx - 1
        case .right, .down:
            targetIdx = idx + 1
        }
        guard targetIdx >= 0 && targetIdx < windowIDs.count else { return nil }
        return windowIDs[targetIdx]
    }

    /// Toggle the split direction at the parent of a window.
    func toggleSplitDirection(at windowID: CGWindowID, in tree: inout BSPTree) {
        tree.toggleDirection(for: windowID)
    }

    /// Rotate windows in the layout.
    func rotateWindows(_ direction: RotationDirection, in windowIDs: inout [CGWindowID]) {
        guard windowIDs.count > 1 else { return }
        switch direction {
        case .clockwise:
            let last = windowIDs.removeLast()
            windowIDs.insert(last, at: 0)
        case .counterClockwise:
            let first = windowIDs.removeFirst()
            windowIDs.append(first)
        }
    }

    /// Normalize all pane sizes (reset ratios to equal).
    func normalizeRatios(in tree: inout BSPTree) {
        tree.root = normalizeNode(tree.root)
    }

    private func normalizeNode(_ node: LayoutNode) -> LayoutNode {
        switch node {
        case .empty, .window:
            return node
        case .split(let dir, _, let first, let second):
            return .split(direction: dir, ratio: 0.5,
                          first: normalizeNode(first),
                          second: normalizeNode(second))
        }
    }
}
