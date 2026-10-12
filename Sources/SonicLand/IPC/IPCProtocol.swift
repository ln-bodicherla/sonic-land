import Foundation

/// Commands that can be sent to the daemon via IPC.
enum IPCCommand {
    case switchWorkspace(Int)
    case moveWindow(Int)
    case focusWindow(Int)
    case listWindows
    case listWorkspaces
    case reloadConfig
    case getActiveWorkspace
    case toggleFloat
    case setLayout(String)
    case cycleLayout
    case renameWorkspace(Int, String)
    case createWorkspace(String)
    case getEventLog(Int)
    case toggleScratchpad(String)
    case listScratchpads
    case saveSession
    case restoreSession
    case listProfiles
    case activateProfile(String)
    case saveProfile(String)
    case getLayoutInfo
    case moveToMaster
    case rotateWindows(String)  // "cw" or "ccw"
    case adjustMasterRatio(Double)
    case adjustMasterCount(Int)
    case focusDirection(String) // "left", "right", "up", "down"
    case moveDirection(String)
    case growWidth
    case shrinkWidth
    case growHeight
    case shrinkHeight
    case normalize
    case togglePseudoFullscreen
    case unknown(String)

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
        case "toggle_float":
            return .toggleFloat
        case "set_layout":
            guard let layout = json["layout"] as? String else { return .unknown(command) }
            return .setLayout(layout)
        case "cycle_layout":
            return .cycleLayout
        case "rename_workspace":
            guard let id = json["workspace"] as? Int,
                  let name = json["name"] as? String else { return .unknown(command) }
            return .renameWorkspace(id, name)
        case "create_workspace":
            guard let name = json["name"] as? String else { return .unknown(command) }
            return .createWorkspace(name)
        case "get_event_log":
            let count = json["count"] as? Int ?? 50
            return .getEventLog(count)
        case "toggle_scratchpad":
            guard let name = json["name"] as? String else { return .unknown(command) }
            return .toggleScratchpad(name)
        case "list_scratchpads":
            return .listScratchpads
        case "save_session":
            return .saveSession
        case "restore_session":
            return .restoreSession
        case "list_profiles":
            return .listProfiles
        case "activate_profile":
            guard let name = json["name"] as? String else { return .unknown(command) }
            return .activateProfile(name)
        case "save_profile":
            guard let name = json["name"] as? String else { return .unknown(command) }
            return .saveProfile(name)
        case "get_layout_info":
            return .getLayoutInfo
        case "move_to_master":
            return .moveToMaster
        case "rotate_windows":
            let dir = json["direction"] as? String ?? "cw"
            return .rotateWindows(dir)
        case "adjust_master_ratio":
            guard let delta = json["delta"] as? Double else { return .unknown(command) }
            return .adjustMasterRatio(delta)
        case "adjust_master_count":
            guard let delta = json["delta"] as? Int else { return .unknown(command) }
            return .adjustMasterCount(delta)
        case "focus_direction":
            guard let dir = json["direction"] as? String else { return .unknown(command) }
            return .focusDirection(dir)
        case "move_direction":
            guard let dir = json["direction"] as? String else { return .unknown(command) }
            return .moveDirection(dir)
        case "grow_width": return .growWidth
        case "shrink_width": return .shrinkWidth
        case "grow_height": return .growHeight
        case "shrink_height": return .shrinkHeight
        case "normalize": return .normalize
        case "toggle_fullscreen": return .togglePseudoFullscreen
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
        case events([EventInfo])
        case scratchpads([ScratchpadInfo])
        case profiles([String])
        case layout(LayoutInfo)
        case text(String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .windows(let windows): try container.encode(windows)
            case .workspaces(let workspaces): try container.encode(workspaces)
            case .events(let events): try container.encode(events)
            case .scratchpads(let sps): try container.encode(sps)
            case .profiles(let names): try container.encode(names)
            case .layout(let info): try container.encode(info)
            case .text(let text): try container.encode(text)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let windows = try? container.decode([WindowInfo].self) {
                self = .windows(windows)
            } else if let workspaces = try? container.decode([WorkspaceInfo].self) {
                self = .workspaces(workspaces)
            } else if let events = try? container.decode([EventInfo].self) {
                self = .events(events)
            } else if let sps = try? container.decode([ScratchpadInfo].self) {
                self = .scratchpads(sps)
            } else if let names = try? container.decode([String].self) {
                self = .profiles(names)
            } else if let info = try? container.decode(LayoutInfo.self) {
                self = .layout(info)
            } else if let text = try? container.decode(String.self) {
                self = .text(text)
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
    let pinned: Bool
    let sticky: Bool
    let tags: [String]
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
    let layout: String
    let workspaceType: String
    let masterRatio: CGFloat
    let masterCount: Int
}

/// Event log entry for IPC responses.
struct EventInfo: Codable {
    let timestamp: String
    let type: String
    let message: String
}

/// Scratchpad info for IPC responses.
struct ScratchpadInfo: Codable {
    let name: String
    let app: String?
    let bundleID: String?
    let visible: Bool
}

/// Layout info for IPC responses.
struct LayoutInfo: Codable {
    let mode: String
    let windowCount: Int
    let masterRatio: CGFloat
    let masterCount: Int
    let workspaceID: Int
    let workspaceName: String
}
