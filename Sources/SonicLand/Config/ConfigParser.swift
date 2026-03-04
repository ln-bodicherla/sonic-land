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

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Parse key = value
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

                // Animation
                case "animation.enabled":
                    config.animation.enabled = value.lowercased() == "true"
                case "animation.duration":
                    config.animation.duration = Double(value) ?? 200
                case "animation.curve":
                    config.animation.curve = EasingCurve(rawValue: value.lowercased()) ?? .easeOut

                // Keybindings: bind = cmd+alt+h, focus_left
                case "bind":
                    let parts = value.split(separator: ",", maxSplits: 1)
                    if parts.count == 2 {
                        let keys = parts[0].trimmingCharacters(in: .whitespaces)
                        let action = parts[1].trimmingCharacters(in: .whitespaces)
                        config.bindings.append(ConfigModel.BindingConfig(keys: keys, action: action))
                    }

                // Window rules: windowrule = float, app:Spotify
                case "windowrule":
                    config.windowRules.append(value)

                default:
                    NSLog("[SonicLand] Unknown config key: \(key)")
                }
            }
        }

        NSLog("[SonicLand] Config loaded: \(config.bindings.count) bindings, \(config.windowRules.count) rules")
        return config
    }
}
