import Foundation

/// A rule that matches windows and applies actions to them.
struct WindowRule {
    let conditions: [RuleCondition]
    let action: RuleAction
    var priority: Int

    init(conditions: [RuleCondition], action: RuleAction, priority: Int = 0) {
        self.conditions = conditions
        self.action = action
        self.priority = priority
    }

    func matches(appName: String, bundleID: String, title: String?) -> Bool {
        return conditions.allSatisfy { condition in
            condition.matches(appName: appName, bundleID: bundleID, title: title)
        }
    }
}

/// Conditions for matching windows.
enum RuleCondition {
    case app(String)
    case bundleID(String)
    case title(String)
    case role(String)          // Window role (e.g., "AXDialog")
    case titleContains(String) // Simple substring match
    case titleNotContains(String)

    func matches(appName: String, bundleID: String, title: String?) -> Bool {
        switch self {
        case .app(let name):
            return appName.lowercased().contains(name.lowercased())
        case .bundleID(let id):
            return bundleID.lowercased() == id.lowercased()
        case .title(let pattern):
            guard let title = title else { return false }
            return (try? NSRegularExpression(pattern: pattern, options: .caseInsensitive))
                .map { $0.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) != nil }
                ?? false
        case .role:
            return true // Checked separately with AX element
        case .titleContains(let substring):
            guard let title = title else { return false }
            return title.lowercased().contains(substring.lowercased())
        case .titleNotContains(let substring):
            guard let title = title else { return true }
            return !title.lowercased().contains(substring.lowercased())
        }
    }
}

/// Actions to apply when a rule matches.
enum RuleAction {
    case setFloating
    case assignWorkspace(Int)
    case setOpacity(Double)
    case moveToMonitor(Int)
    case pinToMaster
    case setGeometry(CGFloat, CGFloat, CGFloat, CGFloat) // x, y, w, h
    case setFloatSize(CGFloat, CGFloat)  // w, h
    case hide
    case ignore
    case makeSticky
    case assignTag(String)
    case centerOnOpen
    case alwaysOnTop
    case setLayout(String)  // Set workspace layout when this app opens
}

extension WindowRule {
    /// Parse a rule from config format: "float, app:Spotify" or "workspace 3, title:.*Terminal.*"
    static func parse(_ line: String) -> WindowRule? {
        let parts = line.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }

        let actionStr = parts[0]
        let action: RuleAction

        let actionLower = actionStr.lowercased()
        if actionLower == "float" {
            action = .setFloating
        } else if actionLower.hasPrefix("workspace ") {
            guard let id = Int(actionLower.dropFirst("workspace ".count)) else { return nil }
            action = .assignWorkspace(id)
        } else if actionLower.hasPrefix("opacity ") {
            guard let val = Double(actionLower.dropFirst("opacity ".count)) else { return nil }
            action = .setOpacity(val)
        } else if actionLower.hasPrefix("monitor ") {
            guard let id = Int(actionLower.dropFirst("monitor ".count)) else { return nil }
            action = .moveToMonitor(id)
        } else if actionLower == "pin" || actionLower == "pin_master" {
            action = .pinToMaster
        } else if actionLower == "hide" {
            action = .hide
        } else if actionLower == "ignore" {
            action = .ignore
        } else if actionLower == "sticky" {
            action = .makeSticky
        } else if actionLower.hasPrefix("tag ") {
            let tag = String(actionStr.dropFirst("tag ".count))
            action = .assignTag(tag)
        } else if actionLower == "center" {
            action = .centerOnOpen
        } else if actionLower == "always_on_top" {
            action = .alwaysOnTop
        } else if actionLower.hasPrefix("size ") {
            let sizeStr = actionLower.dropFirst("size ".count)
            let dims = sizeStr.split(separator: "x").compactMap { CGFloat(Double($0.trimmingCharacters(in: .whitespaces)) ?? 0) }
            guard dims.count == 2 else { return nil }
            action = .setFloatSize(dims[0], dims[1])
        } else if actionLower.hasPrefix("geometry ") {
            let geoStr = actionLower.dropFirst("geometry ".count)
            let vals = geoStr.split(separator: " ").compactMap { CGFloat(Double($0) ?? 0) }
            guard vals.count == 4 else { return nil }
            action = .setGeometry(vals[0], vals[1], vals[2], vals[3])
        } else if actionLower.hasPrefix("layout ") {
            let layout = String(actionStr.dropFirst("layout ".count))
            action = .setLayout(layout)
        } else {
            return nil
        }

        // Parse condition
        let condStr = parts[1]
        var conditions: [RuleCondition] = []

        // Support multiple conditions separated by &&
        let condParts = condStr.components(separatedBy: "&&").map { $0.trimmingCharacters(in: .whitespaces) }
        for cond in condParts {
            if cond.hasPrefix("app:") {
                conditions.append(.app(String(cond.dropFirst("app:".count))))
            } else if cond.hasPrefix("bundle:") {
                conditions.append(.bundleID(String(cond.dropFirst("bundle:".count))))
            } else if cond.hasPrefix("title:") {
                conditions.append(.title(String(cond.dropFirst("title:".count))))
            } else if cond.hasPrefix("role:") {
                conditions.append(.role(String(cond.dropFirst("role:".count))))
            } else if cond.hasPrefix("title_contains:") {
                conditions.append(.titleContains(String(cond.dropFirst("title_contains:".count))))
            } else if cond.hasPrefix("title_not_contains:") {
                conditions.append(.titleNotContains(String(cond.dropFirst("title_not_contains:".count))))
            } else {
                return nil
            }
        }

        guard !conditions.isEmpty else { return nil }
        return WindowRule(conditions: conditions, action: action)
    }
}
