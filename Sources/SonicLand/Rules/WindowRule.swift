import Foundation

/// A rule that matches windows and applies actions to them.
struct WindowRule {
    let conditions: [RuleCondition]
    let action: RuleAction

    func matches(appName: String, bundleID: String, title: String?) -> Bool {
        return conditions.allSatisfy { condition in
            condition.matches(appName: appName, bundleID: bundleID, title: title)
        }
    }
}

/// Conditions for matching windows.
enum RuleCondition {
    case app(String)          // Match by app name (case-insensitive)
    case bundleID(String)     // Match by bundle identifier
    case title(String)        // Match by title (regex pattern)

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
        }
    }
}

/// Actions to apply when a rule matches.
enum RuleAction {
    case setFloating
    case assignWorkspace(Int)
    case setOpacity(Double)
    case moveToMonitor(Int)
}

extension WindowRule {
    /// Parse a rule from config format: "float, app:Spotify" or "workspace 3, title:.*Terminal.*"
    static func parse(_ line: String) -> WindowRule? {
        let parts = line.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }

        // Parse action
        let actionStr = parts[0].lowercased()
        let action: RuleAction
        if actionStr == "float" {
            action = .setFloating
        } else if actionStr.hasPrefix("workspace ") {
            guard let id = Int(actionStr.dropFirst("workspace ".count)) else { return nil }
            action = .assignWorkspace(id)
        } else if actionStr.hasPrefix("opacity ") {
            guard let val = Double(actionStr.dropFirst("opacity ".count)) else { return nil }
            action = .setOpacity(val)
        } else if actionStr.hasPrefix("monitor ") {
            guard let id = Int(actionStr.dropFirst("monitor ".count)) else { return nil }
            action = .moveToMonitor(id)
        } else {
            return nil
        }

        // Parse condition
        let condStr = parts[1]
        var conditions: [RuleCondition] = []
        if condStr.hasPrefix("app:") {
            conditions.append(.app(String(condStr.dropFirst("app:".count))))
        } else if condStr.hasPrefix("bundle:") {
            conditions.append(.bundleID(String(condStr.dropFirst("bundle:".count))))
        } else if condStr.hasPrefix("title:") {
            conditions.append(.title(String(condStr.dropFirst("title:".count))))
        } else {
            return nil
        }

        return WindowRule(conditions: conditions, action: action)
    }
}
