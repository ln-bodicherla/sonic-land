import CoreGraphics

/// Binary Space Partition tree for tiling layout.
struct BSPTree {
    var root: LayoutNode = .empty

    /// The default split direction alternates based on the aspect ratio of the available space.
    private var nextDirection: SplitDirection = .horizontal

    /// Insert a window into the tree. Splits the first empty or smallest leaf.
    mutating func insert(windowID: CGWindowID) {
        root = insertNode(windowID: windowID, into: root, direction: nextDirection)
        nextDirection = nextDirection.toggled
    }

    /// Remove a window from the tree, collapsing empty splits.
    mutating func remove(windowID: CGWindowID) {
        root = removeNode(windowID: windowID, from: root)
    }

    /// Compute the frame for each window given the available rect.
    func computeFrames(in rect: CGRect, gaps: GapConfig = GapConfig()) -> [CGWindowID: CGRect] {
        var frames: [CGWindowID: CGRect] = [:]
        let innerRect = CGRect(
            x: rect.origin.x + gaps.outer,
            y: rect.origin.y + gaps.outer,
            width: rect.width - gaps.outer * 2,
            height: rect.height - gaps.outer * 2
        )
        computeFramesRecursive(node: root, rect: innerRect, gaps: gaps, frames: &frames)
        return frames
    }

    /// Swap two windows in the tree.
    mutating func swapWindows(_ a: CGWindowID, _ b: CGWindowID) {
        root = swapInNode(root, a: a, b: b)
    }

    /// Adjust the split ratio at the node containing the given window.
    mutating func adjustRatio(for windowID: CGWindowID, delta: CGFloat) {
        root = adjustRatioInNode(root, windowID: windowID, delta: delta)
    }

    /// Toggle the split direction at the parent of the given window.
    mutating func toggleDirection(for windowID: CGWindowID) {
        root = toggleDirectionInNode(root, windowID: windowID)
    }

    /// Move a window in a direction within the tree (swap with neighbor).
    mutating func moveWindow(_ windowID: CGWindowID, direction: Direction) {
        // Find neighbor and swap
        let allIDs = root.allWindowIDs
        guard let currentIndex = allIDs.firstIndex(of: windowID) else { return }

        let targetIndex: Int
        switch direction {
        case .left, .up:
            targetIndex = max(0, currentIndex - 1)
        case .right, .down:
            targetIndex = min(allIDs.count - 1, currentIndex + 1)
        }

        if targetIndex != currentIndex {
            swapWindows(allIDs[currentIndex], allIDs[targetIndex])
        }
    }

    /// Find a neighbor window in the given direction.
    func findNeighbor(of windowID: CGWindowID, direction: Direction) -> CGWindowID? {
        let allIDs = root.allWindowIDs
        guard let currentIndex = allIDs.firstIndex(of: windowID) else { return nil }

        let targetIndex: Int
        switch direction {
        case .left, .up:
            targetIndex = currentIndex - 1
        case .right, .down:
            targetIndex = currentIndex + 1
        }

        guard targetIndex >= 0 && targetIndex < allIDs.count else { return nil }
        return allIDs[targetIndex]
    }

    // MARK: - Private Helpers

    private func insertNode(windowID: CGWindowID, into node: LayoutNode, direction: SplitDirection) -> LayoutNode {
        switch node {
        case .empty:
            return .window(windowID)

        case .window(let existingID):
            return .split(
                direction: direction,
                ratio: 0.5,
                first: .window(existingID),
                second: .window(windowID)
            )

        case .split(let dir, let ratio, let first, let second):
            // Insert into the side with fewer windows
            if first.windowCount <= second.windowCount {
                return .split(direction: dir, ratio: ratio,
                              first: insertNode(windowID: windowID, into: first, direction: dir.toggled),
                              second: second)
            } else {
                return .split(direction: dir, ratio: ratio,
                              first: first,
                              second: insertNode(windowID: windowID, into: second, direction: dir.toggled))
            }
        }
    }

    private func removeNode(windowID: CGWindowID, from node: LayoutNode) -> LayoutNode {
        switch node {
        case .empty:
            return .empty

        case .window(let id):
            return id == windowID ? .empty : node

        case .split(let dir, let ratio, let first, let second):
            let newFirst = removeNode(windowID: windowID, from: first)
            let newSecond = removeNode(windowID: windowID, from: second)

            // Collapse if one side is empty
            switch (newFirst, newSecond) {
            case (.empty, .empty):
                return .empty
            case (.empty, let remaining):
                return remaining
            case (let remaining, .empty):
                return remaining
            default:
                return .split(direction: dir, ratio: ratio, first: newFirst, second: newSecond)
            }
        }
    }

    private func computeFramesRecursive(
        node: LayoutNode, rect: CGRect, gaps: GapConfig,
        frames: inout [CGWindowID: CGRect]
    ) {
        switch node {
        case .empty:
            break

        case .window(let id):
            frames[id] = rect

        case .split(_, let ratio, let first, let second):
            // Dynamically choose direction based on rect aspect ratio:
            // Wide rects → split into left/right columns (vertical tiling)
            // Tall rects → split into top/bottom rows
            let direction: SplitDirection = rect.width >= rect.height ? .horizontal : .vertical
            let halfGap = gaps.inner / 2

            let (firstRect, secondRect): (CGRect, CGRect)

            switch direction {
            case .horizontal:
                let splitX = rect.origin.x + rect.width * ratio
                firstRect = CGRect(
                    x: rect.origin.x,
                    y: rect.origin.y,
                    width: splitX - rect.origin.x - halfGap,
                    height: rect.height
                )
                secondRect = CGRect(
                    x: splitX + halfGap,
                    y: rect.origin.y,
                    width: rect.maxX - splitX - halfGap,
                    height: rect.height
                )

            case .vertical:
                let splitY = rect.origin.y + rect.height * ratio
                firstRect = CGRect(
                    x: rect.origin.x,
                    y: rect.origin.y,
                    width: rect.width,
                    height: splitY - rect.origin.y - halfGap
                )
                secondRect = CGRect(
                    x: rect.origin.x,
                    y: splitY + halfGap,
                    width: rect.width,
                    height: rect.maxY - splitY - halfGap
                )
            }

            computeFramesRecursive(node: first, rect: firstRect, gaps: gaps, frames: &frames)
            computeFramesRecursive(node: second, rect: secondRect, gaps: gaps, frames: &frames)
        }
    }

    private func swapInNode(_ node: LayoutNode, a: CGWindowID, b: CGWindowID) -> LayoutNode {
        switch node {
        case .empty:
            return .empty
        case .window(let id):
            if id == a { return .window(b) }
            if id == b { return .window(a) }
            return node
        case .split(let dir, let ratio, let first, let second):
            return .split(direction: dir, ratio: ratio,
                          first: swapInNode(first, a: a, b: b),
                          second: swapInNode(second, a: a, b: b))
        }
    }

    private func adjustRatioInNode(_ node: LayoutNode, windowID: CGWindowID, delta: CGFloat) -> LayoutNode {
        switch node {
        case .empty, .window:
            return node
        case .split(let dir, let ratio, let first, let second):
            if first.contains(windowID: windowID) || second.contains(windowID: windowID) {
                let newRatio = max(0.1, min(0.9, ratio + delta))
                return .split(direction: dir, ratio: newRatio,
                              first: adjustRatioInNode(first, windowID: windowID, delta: delta),
                              second: adjustRatioInNode(second, windowID: windowID, delta: delta))
            }
            return .split(direction: dir, ratio: ratio,
                          first: adjustRatioInNode(first, windowID: windowID, delta: delta),
                          second: adjustRatioInNode(second, windowID: windowID, delta: delta))
        }
    }

    private func toggleDirectionInNode(_ node: LayoutNode, windowID: CGWindowID) -> LayoutNode {
        switch node {
        case .empty, .window:
            return node
        case .split(let dir, let ratio, let first, let second):
            if first.contains(windowID: windowID) || second.contains(windowID: windowID) {
                // If the window is a direct child, toggle this node
                let isDirectChild: Bool
                switch (first, second) {
                case (.window(let id), _) where id == windowID: isDirectChild = true
                case (_, .window(let id)) where id == windowID: isDirectChild = true
                default: isDirectChild = false
                }

                if isDirectChild {
                    return .split(direction: dir.toggled, ratio: ratio, first: first, second: second)
                }
            }
            return .split(direction: dir, ratio: ratio,
                          first: toggleDirectionInNode(first, windowID: windowID),
                          second: toggleDirectionInNode(second, windowID: windowID))
        }
    }
}

/// Gap configuration.
struct GapConfig {
    var inner: CGFloat = 5
    var outer: CGFloat = 10

    init(inner: CGFloat = 5, outer: CGFloat = 10) {
        self.inner = inner
        self.outer = outer
    }
}
