import AppKit

/// Actions that can be triggered by keybindings.
enum KeyAction: Equatable {
    case focusLeft
    case focusRight
    case focusUp
    case focusDown
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case switchWorkspace(Int)
    case moveToWorkspace(Int)
    case toggleFloat
    case toggleLayoutDirection
    case reloadConfig

    /// Parse an action from a config string like "focus_left" or "workspace 3".
    static func from(string: String) -> KeyAction? {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
        let command = String(parts[0]).lowercased()

        switch command {
        case "focus_left": return .focusLeft
        case "focus_right": return .focusRight
        case "focus_up": return .focusUp
        case "focus_down": return .focusDown
        case "move_left": return .moveLeft
        case "move_right": return .moveRight
        case "move_up": return .moveUp
        case "move_down": return .moveDown
        case "toggle_float": return .toggleFloat
        case "toggle_layout": return .toggleLayoutDirection
        case "reload_config": return .reloadConfig
        case "workspace":
            guard parts.count > 1, let id = Int(parts[1]) else { return nil }
            return .switchWorkspace(id)
        case "move_to_workspace":
            guard parts.count > 1, let id = Int(parts[1]) else { return nil }
            return .moveToWorkspace(id)
        default:
            return nil
        }
    }
}

/// A keybinding mapping a modifier+key combo to an action.
struct KeyBinding {
    let modifiers: NSEvent.ModifierFlags
    let keyCode: UInt16
    let action: KeyAction

    /// Check if this binding matches the given event.
    func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        return self.keyCode == keyCode &&
               self.modifiers.intersection(relevantFlags) == modifiers.intersection(relevantFlags)
    }

    /// Parse a binding from config format: "cmd+alt+h" -> modifiers + keyCode
    static func parseKeys(_ keyString: String) -> (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)? {
        let parts = keyString.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        var keyName = ""

        for part in parts {
            switch part {
            case "cmd", "command", "super":
                modifiers.insert(.command)
            case "alt", "option", "opt":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            case "ctrl", "control":
                modifiers.insert(.control)
            default:
                keyName = part
            }
        }

        guard let keyCode = KeyCodes.nameToKeyCode[keyName] else { return nil }
        return (modifiers, keyCode)
    }
}
