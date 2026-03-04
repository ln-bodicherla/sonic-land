import Foundation

/// Which monitors participate in tiling.
enum TilingMode: String, CaseIterable {
    case external
    case builtIn
    case sharedSpace

    /// Display title for the menu bar submenu.
    var menuTitle: String {
        switch self {
        case .external:    return "External Monitor"
        case .builtIn:     return "Built-in Monitor"
        case .sharedSpace: return "Shared Space"
        }
    }

    /// Filter string compatible with `MonitorManager.tilingMonitors(filter:)`.
    var monitorFilter: String {
        switch self {
        case .external:    return "external"
        case .builtIn:     return "built-in"
        case .sharedSpace: return "all"
        }
    }

    /// UserDefaults key for persistence.
    static let defaultsKey = "SonicLandTilingMode"

    /// Derive a mode from the legacy `general.monitor` config value.
    static func from(configMonitor value: String) -> TilingMode {
        let lower = value.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "external":
            return .external
        case "built-in", "builtin", "internal":
            return .builtIn
        default:
            return .sharedSpace
        }
    }
}
