import Foundation
import Network

let socketPath = "/tmp/com.sonicland.sock"

func printUsage() {
    let usage = """
    Usage: sonicctl <command> [options]

    Commands:
      switch-workspace <id>     Switch to workspace (1-9)
      move-window --workspace <id>  Move focused window to workspace
      focus-window <id>         Focus window by ID
      list-windows              List all managed windows
      list-workspaces           List all workspaces
      active-workspace          Get the active workspace
      reload                    Reload configuration

    Examples:
      sonicctl switch-workspace 3
      sonicctl move-window --workspace 2
      sonicctl list-windows
      sonicctl reload
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

    case "list-windows":
        return ["command": "list_windows"]

    case "list-workspaces":
        return ["command": "list_workspaces"]

    case "active-workspace":
        return ["command": "get_active_workspace"]

    case "reload":
        return ["command": "reload_config"]

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
            // Send command
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

            // Receive response
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

                // Pretty-print JSON response
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

    // Wait for response with timeout
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
