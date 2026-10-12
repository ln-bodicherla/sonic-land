import CoreGraphics

/// Rows layout: all windows arranged as equal-height rows.
struct RowsLayout: TilingLayout {
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
        let count = CGFloat(windowIDs.count)
        let rowHeight = (innerRect.height - (count - 1) * gaps.inner) / count

        for (i, wid) in windowIDs.enumerated() {
            frames[wid] = CGRect(
                x: innerRect.origin.x,
                y: innerRect.origin.y + CGFloat(i) * (rowHeight + gaps.inner),
                width: innerRect.width,
                height: rowHeight
            )
        }

        return frames
    }
}
