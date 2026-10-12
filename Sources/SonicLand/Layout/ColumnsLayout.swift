import CoreGraphics

/// Columns layout: all windows arranged as equal-width columns.
struct ColumnsLayout: TilingLayout {
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
        let colWidth = (innerRect.width - (count - 1) * gaps.inner) / count

        for (i, wid) in windowIDs.enumerated() {
            frames[wid] = CGRect(
                x: innerRect.origin.x + CGFloat(i) * (colWidth + gaps.inner),
                y: innerRect.origin.y,
                width: colWidth,
                height: innerRect.height
            )
        }

        return frames
    }
}
