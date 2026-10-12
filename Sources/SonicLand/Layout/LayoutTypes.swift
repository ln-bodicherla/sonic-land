import Foundation

/// The direction of a BSP split.
enum SplitDirection: String, Codable {
    case horizontal // Left/Right split
    case vertical   // Top/Bottom split

    var toggled: SplitDirection {
        switch self {
        case .horizontal: return .vertical
        case .vertical: return .horizontal
        }
    }
}

/// Cardinal directions for focus/move operations.
enum Direction {
    case left, right, up, down
}

/// Rotation direction for tree operations.
enum RotationDirection {
    case clockwise
    case counterClockwise
}

/// Resize axis for grow/shrink operations.
enum ResizeAxis {
    case horizontal
    case vertical
    case both
}
