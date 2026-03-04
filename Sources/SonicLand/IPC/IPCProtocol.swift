import Foundation

/// Commands that can be sent to the daemon via IPC.
enum IPCCommand {
    case switchWorkspace(Int)
    case moveWindow(Int)       // Move focused window to workspace
    case focusWindow(Int)      // Focus window by ID
    case listWindows
    case listWorkspaces
    case reloadConfig
    case getActiveWorkspace
    case unknown(String)

    /// Parse a command from a JSON string.
    static func parse(from data: Data) -> IPCCommand? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = json["command"] as? String else {
            return nil
        }

        switch command {
        case "switch_workspace":
            guard let id = json["workspace"] as? Int else { return .unknown(command) }
            return .switchWorkspace(id)
        case "move_window":
            guard let id = json["workspace"] as? Int else { return .unknown(command) }
            return .moveWindow(id)
        case "focus_window":
            guard let id = json["window_id"] as? Int else { return .unknown(command) }
            return .focusWindow(id)
        case "list_windows":
            return .listWindows
        case "list_workspaces":
            return .listWorkspaces
        case "reload_config":
            return .reloadConfig
        case "get_active_workspace":
            return .getActiveWorkspace
        default:
            return .unknown(command)
        }
    }
}

/// Response from the daemon.
struct IPCResponse: Codable {
    let status: Status
    let message: String?
    let data: ResponseData?

    enum Status: String, Codable {
        case ok
        case error
    }

    enum ResponseData: Codable {
        case windows([WindowInfo])
        case workspaces([WorkspaceInfo])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .windows(let windows):
                try container.encode(windows)
            case .workspaces(let workspaces):
                try container.encode(workspaces)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let windows = try? container.decode([WindowInfo].self) {
                self = .windows(windows)
            } else if let workspaces = try? container.decode([WorkspaceInfo].self) {
                self = .workspaces(workspaces)
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown response data")
            }
        }
    }

    init(status: Status, data: ResponseData? = nil, message: String? = nil) {
        self.status = status
        self.data = data
        self.message = message
    }
}

/// Window information for IPC responses.
struct WindowInfo: Codable {
    let windowID: Int
    let app: String
    let title: String
    let frame: FrameInfo
    let workspace: Int
    let floating: Bool
}

/// Frame info for JSON serialization.
struct FrameInfo: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
}

/// Workspace information for IPC responses.
struct WorkspaceInfo: Codable {
    let id: Int
    let name: String
    let windowCount: Int
    let monitorID: UInt32
    let focused: Bool
}
