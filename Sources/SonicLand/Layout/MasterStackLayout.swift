import CoreGraphics

/// Master-stack layout: one master pane on the left, remaining windows stacked on the right.
struct MasterStackLayout: TilingLayout {
    func computeFrames(
        windowIDs: [CGWindowID],
        in rect: CGRect,
        gaps: GapConfig,
        masterRatio: CGFloat,
        masterCount: Int
    ) -> [CGWindowID: CGRect] {
        guard !windowIDs.isEmpty else { return [:] }

        var frames: [CGWindowID: CGRect] = [:]
        let innerRect = rect.insetBy(gaps: gaps)
        let halfGap = gaps.inner / 2
        let clampedMasterCount = min(masterCount, windowIDs.count)

        if windowIDs.count == 1 {
            frames[windowIDs[0]] = innerRect
            return frames
        }

        let masterIDs = Array(windowIDs.prefix(clampedMasterCount))
        let stackIDs = Array(windowIDs.dropFirst(clampedMasterCount))

        if stackIDs.isEmpty {
            // All windows are masters, stack them vertically
            let height = (innerRect.height - CGFloat(masterIDs.count - 1) * gaps.inner) / CGFloat(masterIDs.count)
            for (i, wid) in masterIDs.enumerated() {
                frames[wid] = CGRect(
                    x: innerRect.origin.x,
                    y: innerRect.origin.y + CGFloat(i) * (height + gaps.inner),
                    width: innerRect.width,
                    height: height
                )
            }
            return frames
        }

        // Master area on the left
        let masterWidth = innerRect.width * masterRatio - halfGap
        let masterHeight = (innerRect.height - CGFloat(masterIDs.count - 1) * gaps.inner) / CGFloat(masterIDs.count)

        for (i, wid) in masterIDs.enumerated() {
            frames[wid] = CGRect(
                x: innerRect.origin.x,
                y: innerRect.origin.y + CGFloat(i) * (masterHeight + gaps.inner),
                width: masterWidth,
                height: masterHeight
            )
        }

        // Stack area on the right
        let stackX = innerRect.origin.x + innerRect.width * masterRatio + halfGap
        let stackWidth = innerRect.width * (1 - masterRatio) - halfGap
        let stackHeight = (innerRect.height - CGFloat(stackIDs.count - 1) * gaps.inner) / CGFloat(stackIDs.count)

        for (i, wid) in stackIDs.enumerated() {
            frames[wid] = CGRect(
                x: stackX,
                y: innerRect.origin.y + CGFloat(i) * (stackHeight + gaps.inner),
                width: stackWidth,
                height: stackHeight
            )
        }

        return frames
    }
}
