import AppKit

/// Actions that can be triggered by keybindings.
enum KeyAction: Equatable {
    // Focus
    case focusLeft
    case focusRight
    case focusUp
    case focusDown
    case focusRecent          // Most recently focused window
    case focusParent          // Parent container in BSP tree
    case focusMaster          // Focus master window

    // Move
    case moveLeft
    case moveRight
    case moveUp
    case moveDown
    case moveToMaster         // Move focused to master area
    case pullToTile           // Pull floating window into tile tree
    case ejectToFloat         // Eject tiled window to floating

    // Resize
    case growWidth
    case shrinkWidth
    case growHeight
    case shrinkHeight
    case normalizeSize        // Reset all ratios to equal
    case increaseMasterRatio
    case decreaseMasterRatio
    case increaseMasterCount
    case decreaseMasterCount

    // Workspace
    case switchWorkspace(Int)
    case moveToWorkspace(Int)
    case nextWorkspace
    case previousWorkspace
    case recentWorkspace

    // Layout
    case toggleFloat
    case toggleLayoutDirection
    case cycleLayout          // BSP -> Master-Stack -> Columns -> ...
    case setLayout(String)    // Set specific layout mode
    case rotateClockwise
    case rotateCounterClockwise

    // Fullscreen
    case togglePseudoFullscreen
    case toggleMonocle

    // Scratchpad
    case toggleScratchpad(String)

    // System
    case reloadConfig
    case toggleGaps
    case toggleOverlay

    /// Parse an action from a config string.
    static func from(string: String) -> KeyAction? {
        let parts = string.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
        let command = String(parts[0]).lowercased()

        switch command {
        // Focus
        case "focus_left": return .focusLeft
        case "focus_right": return .focusRight
        case "focus_up": return .focusUp
        case "focus_down": return .focusDown
        case "focus_recent": return .focusRecent
        case "focus_parent": return .focusParent
        case "focus_master": return .focusMaster

        // Move
        case "move_left": return .moveLeft
        case "move_right": return .moveRight
        case "move_up": return .moveUp
        case "move_down": return .moveDown
        case "move_to_master": return .moveToMaster
        case "pull_to_tile": return .pullToTile
        case "eject_to_float": return .ejectToFloat

        // Resize
        case "grow_width": return .growWidth
        case "shrink_width": return .shrinkWidth
        case "grow_height": return .growHeight
        case "shrink_height": return .shrinkHeight
        case "normalize": return .normalizeSize
        case "increase_master_ratio": return .increaseMasterRatio
        case "decrease_master_ratio": return .decreaseMasterRatio
        case "increase_master_count": return .increaseMasterCount
        case "decrease_master_count": return .decreaseMasterCount

        // Layout
        case "toggle_float": return .toggleFloat
        case "toggle_layout": return .toggleLayoutDirection
        case "cycle_layout": return .cycleLayout
        case "rotate_cw": return .rotateClockwise
        case "rotate_ccw": return .rotateCounterClockwise
        case "toggle_fullscreen": return .togglePseudoFullscreen
        case "toggle_monocle": return .toggleMonocle

        // Workspace
        case "workspace":
            guard parts.count > 1, let id = Int(parts[1]) else { return nil }
            return .switchWorkspace(id)
        case "move_to_workspace":
            guard parts.count > 1, let id = Int(parts[1]) else { return nil }
            return .moveToWorkspace(id)
        case "next_workspace": return .nextWorkspace
        case "previous_workspace": return .previousWorkspace
        case "recent_workspace": return .recentWorkspace

        // Scratchpad
        case "scratchpad":
            guard parts.count > 1 else { return nil }
            return .toggleScratchpad(String(parts[1]))

        // Layout mode
        case "layout":
            guard parts.count > 1 else { return nil }
            return .setLayout(String(parts[1]))

        // System
        case "reload_config": return .reloadConfig
        case "toggle_gaps": return .toggleGaps
        case "toggle_overlay": return .toggleOverlay

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

    func matches(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .shift, .control]
        return self.keyCode == keyCode &&
               self.modifiers.intersection(relevantFlags) == modifiers.intersection(relevantFlags)
    }

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
