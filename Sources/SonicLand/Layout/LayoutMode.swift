import Foundation

/// Available layout modes for workspaces.
enum LayoutMode: String, Codable, CaseIterable {
    case bsp           // Binary space partitioning (default)
    case masterStack   // Master pane + stack
    case columns       // Equal columns
    case rows          // Equal rows
    case monocle       // Single window fullscreen
    case floating      // All windows float

    var displayName: String {
        switch self {
        case .bsp: return "BSP"
        case .masterStack: return "Master-Stack"
        case .columns: return "Columns"
        case .rows: return "Rows"
        case .monocle: return "Monocle"
        case .floating: return "Floating"
        }
    }

    var next: LayoutMode {
        let all = LayoutMode.allCases
        guard let idx = all.firstIndex(of: self) else { return .bsp }
        return all[(idx + 1) % all.count]
    }

    var previous: LayoutMode {
        let all = LayoutMode.allCases
        guard let idx = all.firstIndex(of: self) else { return .bsp }
        return all[(idx - 1 + all.count) % all.count]
    }
}
