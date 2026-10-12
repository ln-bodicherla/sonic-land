import Foundation
import Network

let socketPath = "/tmp/com.sonicland.sock"

func printUsage() {
    let usage = """
    Usage: sonicctl <command> [options]

    Window Management:
      focus <direction>           Focus window (left/right/up/down)
      move <direction>            Move window (left/right/up/down)
      move-window --workspace <n> Move focused window to workspace
      focus-window <id>           Focus window by ID
      toggle-float                Toggle float for focused window
      move-to-master              Move focused window to master area
      rotate [cw|ccw]             Rotate windows in layout
      toggle-fullscreen           Toggle pseudo-fullscreen

    Resize:
      grow-width                  Grow focused window width
      shrink-width                Shrink focused window width
      grow-height                 Grow focused window height
      shrink-height               Shrink focused window height
      normalize                   Reset all pane sizes to equal

    Layout:
      set-layout <mode>           Set layout (bsp/masterStack/columns/rows/monocle/floating)
      cycle-layout                Cycle through layout modes
      master-ratio <delta>        Adjust master ratio (+/- float, e.g. 0.05)
      master-count <delta>        Adjust master count (+/- int)

    Workspaces:
      switch-workspace <id>       Switch to workspace (1-9+)
      rename-workspace <id> <name> Rename a workspace
      create-workspace <name>     Create a new workspace
      list-workspaces              List all workspaces
      active-workspace             Get active workspace

    Scratchpads:
      toggle-scratchpad <name>    Toggle a scratchpad
      list-scratchpads            List all scratchpads

    Session & Profiles:
      save-session                Save current session
      restore-session             Restore saved session
      list-profiles               List all profiles
      activate-profile <name>     Activate a profile
      save-profile <name>         Save current state as profile

    Query:
      list-windows                List all managed windows (JSON)
      get-layout                  Get current layout info
      event-log [count]           Get recent event log entries

    System:
      reload                      Reload configuration file

    Examples:
      sonicctl switch-workspace 3
      sonicctl set-layout masterStack
      sonicctl toggle-scratchpad terminal
      sonicctl master-ratio 0.05
      sonicctl rename-workspace 1 "Dev"
      sonicctl event-log 20
    """
    print(usage)
}

func buildCommand(args: [String]) -> [String: Any]? {
    guard args.count > 1 else { return nil }
    let command = args[1]

    switch command {
    case "switch-workspace":
        guard args.count > 2, let id = Int(args[2]) else {
            print("Error: switch-workspace requires a workspace ID")
            return nil
        }
        return ["command": "switch_workspace", "workspace": id]

    case "move-window":
        guard args.count > 3, args[2] == "--workspace", let id = Int(args[3]) else {
            print("Error: move-window requires --workspace <id>")
            return nil
        }
        return ["command": "move_window", "workspace": id]

    case "focus-window":
        guard args.count > 2, let id = Int(args[2]) else {
            print("Error: focus-window requires a window ID")
            return nil
        }
        return ["command": "focus_window", "window_id": id]

    case "focus":
        guard args.count > 2 else {
            print("Error: focus requires a direction (left/right/up/down)")
            return nil
        }
        return ["command": "focus_direction", "direction": args[2]]

    case "move":
        guard args.count > 2 else {
            print("Error: move requires a direction (left/right/up/down)")
            return nil
        }
        return ["command": "move_direction", "direction": args[2]]

    case "list-windows":
        return ["command": "list_windows"]

    case "list-workspaces":
        return ["command": "list_workspaces"]

    case "active-workspace":
        return ["command": "get_active_workspace"]

    case "reload":
        return ["command": "reload_config"]

    case "toggle-float":
        return ["command": "toggle_float"]

    case "set-layout":
        guard args.count > 2 else {
            print("Error: set-layout requires a layout mode")
            return nil
        }
        return ["command": "set_layout", "layout": args[2]]

    case "cycle-layout":
        return ["command": "cycle_layout"]

    case "rename-workspace":
        guard args.count > 3, let id = Int(args[2]) else {
            print("Error: rename-workspace requires <id> <name>")
            return nil
        }
        return ["command": "rename_workspace", "workspace": id, "name": args[3]]

    case "create-workspace":
        guard args.count > 2 else {
            print("Error: create-workspace requires a name")
            return nil
        }
        return ["command": "create_workspace", "name": args[2]]

    case "event-log":
        let count = args.count > 2 ? Int(args[2]) ?? 50 : 50
        return ["command": "get_event_log", "count": count]

    case "toggle-scratchpad":
        guard args.count > 2 else {
            print("Error: toggle-scratchpad requires a name")
            return nil
        }
        return ["command": "toggle_scratchpad", "name": args[2]]

    case "list-scratchpads":
        return ["command": "list_scratchpads"]

    case "save-session":
        return ["command": "save_session"]

    case "restore-session":
        return ["command": "restore_session"]

    case "list-profiles":
        return ["command": "list_profiles"]

    case "activate-profile":
        guard args.count > 2 else {
            print("Error: activate-profile requires a name")
            return nil
        }
        return ["command": "activate_profile", "name": args[2]]

    case "save-profile":
        guard args.count > 2 else {
            print("Error: save-profile requires a name")
            return nil
        }
        return ["command": "save_profile", "name": args[2]]

    case "get-layout":
        return ["command": "get_layout_info"]

    case "move-to-master":
        return ["command": "move_to_master"]

    case "rotate":
        let dir = args.count > 2 ? args[2] : "cw"
        return ["command": "rotate_windows", "direction": dir]

    case "master-ratio":
        guard args.count > 2, let delta = Double(args[2]) else {
            print("Error: master-ratio requires a delta value (e.g. 0.05 or -0.05)")
            return nil
        }
        return ["command": "adjust_master_ratio", "delta": delta]

    case "master-count":
        guard args.count > 2, let delta = Int(args[2]) else {
            print("Error: master-count requires a delta value (e.g. 1 or -1)")
            return nil
        }
        return ["command": "adjust_master_count", "delta": delta]

    case "grow-width": return ["command": "grow_width"]
    case "shrink-width": return ["command": "shrink_width"]
    case "grow-height": return ["command": "grow_height"]
    case "shrink-height": return ["command": "shrink_height"]
    case "normalize": return ["command": "normalize"]
    case "toggle-fullscreen": return ["command": "toggle_fullscreen"]

    case "help", "--help", "-h":
        printUsage()
        return nil

    default:
        print("Unknown command: \(command)")
        printUsage()
        return nil
    }
}

func sendCommand(_ commandDict: [String: Any]) {
    let semaphore = DispatchSemaphore(value: 0)

    let endpoint = NWEndpoint.unix(path: socketPath)
    let connection = NWConnection(to: endpoint, using: .tcp)

    connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
            do {
                var data = try JSONSerialization.data(withJSONObject: commandDict)
                data.append(contentsOf: "\n".utf8)
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Error sending command: \(error)")
                        semaphore.signal()
                        return
                    }
                })
            } catch {
                print("Error encoding command: \(error)")
                semaphore.signal()
            }

            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, error in
                defer { semaphore.signal() }

                if let error = error {
                    print("Error receiving response: \(error)")
                    return
                }

                guard let data = data, !data.isEmpty else {
                    print("No response received")
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data),
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    print(prettyString)
                } else if let string = String(data: data, encoding: .utf8) {
                    print(string)
                }
            }

        case .failed(let error):
            print("Connection failed: \(error)")
            print("Is SonicLand daemon running?")
            semaphore.signal()

        case .cancelled:
            semaphore.signal()

        default:
            break
        }
    }

    connection.start(queue: .global())

    let result = semaphore.wait(timeout: .now() + 5)
    if result == .timedOut {
        print("Connection timed out. Is SonicLand daemon running?")
    }

    connection.cancel()
}

// Main
let args = CommandLine.arguments

guard let command = buildCommand(args: args) else {
    if args.count <= 1 {
        printUsage()
    }
    exit(args.count <= 1 ? 0 : 1)
}

sendCommand(command)
