import CoreGraphics

/// Protocol for layout strategies. Each layout mode implements this.
protocol TilingLayout {
    /// Compute window frames for the given window IDs within the available rect.
    func computeFrames(
        windowIDs: [CGWindowID],
        in rect: CGRect,
        gaps: GapConfig,
        masterRatio: CGFloat,
        masterCount: Int
    ) -> [CGWindowID: CGRect]
}
