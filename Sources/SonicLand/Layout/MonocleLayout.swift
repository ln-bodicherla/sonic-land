import CoreGraphics

/// Monocle layout: all windows occupy the full area, stacked on top of each other.
/// Only the focused window is visible.
struct MonocleLayout: TilingLayout {
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

        for wid in windowIDs {
            frames[wid] = innerRect
        }

        return frames
    }
}
