import Foundation

/// Evaluates window rules and applies matching actions.
final class RuleEngine {
    private var rules: [WindowRule] = []

    init(config: ConfigModel) {
        loadRules(from: config)
    }

    func updateConfig(_ config: ConfigModel) {
        loadRules(from: config)
    }

    /// Apply all matching rules to a window.
    func applyRules(to window: WindowNode, workspaceManager: WorkspaceManager) {
        for rule in rules {
            guard rule.matches(appName: window.appName, bundleID: window.bundleID, title: window.title) else {
                continue
            }

            switch rule.action {
            case .setFloating:
                window.isFloating = true
                NSLog("[SonicLand] Rule: Set \(window.appName) as floating")

            case .assignWorkspace(let id):
                window.workspaceID = id
                workspaceManager.addWindow(window.windowID, to: id)
                NSLog("[SonicLand] Rule: Assigned \(window.appName) to workspace \(id)")

            case .setOpacity:
                // Opacity requires private APIs — log for now
                NSLog("[SonicLand] Rule: Opacity for \(window.appName) (not yet implemented)")

            case .moveToMonitor:
                NSLog("[SonicLand] Rule: Move \(window.appName) to monitor (not yet implemented)")
            }
        }
    }

    private func loadRules(from config: ConfigModel) {
        rules = config.windowRules.compactMap { WindowRule.parse($0) }
        NSLog("[SonicLand] Loaded \(rules.count) window rules.")
    }
}
