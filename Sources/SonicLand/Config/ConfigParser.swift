import Foundation

/// Parses Hyprland-style configuration files.
final class ConfigParser {
    private let configPath: String

    init() {
        self.configPath = NSString("~/.config/sonicland/sonicland.conf").expandingTildeInPath
    }

    /// Load and parse the config file. Returns default config if file doesn't exist.
    func loadConfig() -> ConfigModel {
        var config = ConfigModel()

        guard FileManager.default.fileExists(atPath: configPath) else {
            NSLog("[SonicLand] No config file at \(configPath). Using defaults.")
            return config
        }

        guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            NSLog("[SonicLand] Failed to read config file.")
            return config
        }

        let lines = contents.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            if let equalsIndex = trimmed.firstIndex(of: "=") {
                let key = trimmed[trimmed.startIndex..<equalsIndex].trimmingCharacters(in: .whitespaces).lowercased()
                let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)

                switch key {
                // General
                case "general.gaps_in":
                    config.general.gapsIn = CGFloat(Double(value) ?? 5)
                case "general.gaps_out":
                    config.general.gapsOut = CGFloat(Double(value) ?? 10)
                case "general.border_size":
                    config.general.borderSize = CGFloat(Double(value) ?? 2)
                case "general.monitor":
                    config.general.monitor = value
                case "general.layout":
                    config.general.defaultLayout = value.lowercased()
                case "general.master_ratio":
                    config.general.masterRatio = CGFloat(Double(value) ?? 0.55)
                case "general.master_count":
                    config.general.masterCount = Int(value) ?? 1
                case "general.focus_follows_mouse":
                    config.general.focusFollowsMouse = value.lowercased() == "true"
                case "general.dnd":
                    config.general.dndMode = value.lowercased() == "true"

                // Animation
                case "animation.enabled":
                    config.animation.enabled = value.lowercased() == "true"
                case "animation.duration":
                    config.animation.duration = Double(value) ?? 200
                case "animation.curve":
                    config.animation.curve = EasingCurve(rawValue: value.lowercased()) ?? .easeOut

                // Session
                case "session.enabled":
                    config.sessionRestore.enabled = value.lowercased() == "true"
                case "session.restore_apps":
                    config.sessionRestore.restoreApps = value.lowercased() == "true"
                case "session.save_on_quit":
                    config.sessionRestore.saveOnQuit = value.lowercased() == "true"

                // Overlay
                case "overlay.workspace_name":
                    config.overlay.showWorkspaceName = value.lowercased() == "true"
                case "overlay.layout_name":
                    config.overlay.showLayoutName = value.lowercased() == "true"
                case "overlay.focus_ring":
                    config.overlay.showFocusRing = value.lowercased() == "true"
                case "overlay.workspace_map":
                    config.overlay.showWorkspaceMap = value.lowercased() == "true"

                // Keybindings
                case "bind":
                    let parts = value.split(separator: ",", maxSplits: 1)
                    if parts.count == 2 {
                        let keys = parts[0].trimmingCharacters(in: .whitespaces)
                        let action = parts[1].trimmingCharacters(in: .whitespaces)
                        config.bindings.append(ConfigModel.BindingConfig(keys: keys, action: action))
                    }

                // Window rules
                case "windowrule":
                    config.windowRules.append(value)

                // Context rules
                case "contextrule":
                    config.contextRules.append(value)

                // Scratchpads
                case "scratchpad":
                    if let sp = parseScratchpad(value) {
                        config.scratchpads.append(sp)
                    }

                // Workspace config: workspace.1.name = Dev
                default:
                    if key.hasPrefix("workspace.") {
                        parseWorkspaceConfig(key: key, value: value, config: &config)
                    } else {
                        NSLog("[SonicLand] Unknown config key: \(key)")
                    }
                }
            }
        }

        NSLog("[SonicLand] Config loaded: \(config.bindings.count) bindings, \(config.windowRules.count) rules, \(config.scratchpads.count) scratchpads")
        return config
    }

    private func parseScratchpad(_ value: String) -> ConfigModel.ScratchpadConfig? {
        // Format: name, app:Terminal or name, bundle:com.apple.Terminal
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }

        var sp = ConfigModel.ScratchpadConfig(name: parts[0])

        for part in parts.dropFirst() {
            let kv = part.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2 else { continue }
            switch kv[0].lowercased() {
            case "app": sp.app = kv[1]
            case "bundle": sp.bundleID = kv[1]
            case "command": sp.command = kv[1]
            case "width": sp.width = CGFloat(Double(kv[1]) ?? 800)
            case "height": sp.height = CGFloat(Double(kv[1]) ?? 600)
            case "center": sp.center = kv[1].lowercased() == "true"
            case "autohide": sp.autoHide = kv[1].lowercased() == "true"
            default: break
            }
        }

        return sp
    }

    private func parseWorkspaceConfig(key: String, value: String, config: inout ConfigModel) {
        // workspace.1.name = Dev
        let parts = key.split(separator: ".")
        guard parts.count == 3,
              let wsID = Int(parts[1]) else { return }

        var wsConfig = config.workspaceConfig[wsID] ?? ConfigModel.WorkspaceConfig()
        let prop = String(parts[2])

        switch prop {
        case "name": wsConfig.name = value
        case "layout": wsConfig.layout = value.lowercased()
        case "type": wsConfig.type = value.lowercased()
        case "master_ratio": wsConfig.masterRatio = CGFloat(Double(value) ?? 0.55)
        case "master_count": wsConfig.masterCount = Int(value)
        case "gaps_in": wsConfig.gapsIn = CGFloat(Double(value) ?? 5)
        case "gaps_out": wsConfig.gapsOut = CGFloat(Double(value) ?? 10)
        case "monitor": wsConfig.monitor = Int(value)
        case "startup": wsConfig.startupActions.append(value)
        default: break
        }

        config.workspaceConfig[wsID] = wsConfig
    }
}
