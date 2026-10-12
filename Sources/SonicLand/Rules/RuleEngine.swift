import Foundation

/// Evaluates window rules and applies matching actions.
final class RuleEngine {
    private var rules: [WindowRule] = []
    private var contextRules: [ContextRule] = []
    private var lastContextEval: Date = .distantPast
    private let contextEvalInterval: TimeInterval = 30  // Evaluate context every 30s

    init(config: ConfigModel) {
        loadRules(from: config)
    }

    func updateConfig(_ config: ConfigModel) {
        loadRules(from: config)
    }

    var allRules: [WindowRule] { rules }
    var allContextRules: [ContextRule] { contextRules }

    /// Apply all matching rules to a window.
    func applyRules(to window: WindowNode, workspaceManager: WorkspaceManager) {
        let sortedRules = rules.sorted { $0.priority > $1.priority }

        for rule in sortedRules {
            guard rule.matches(appName: window.appName, bundleID: window.bundleID, title: window.title) else {
                continue
            }

            EventLog.shared.log(.ruleMatched,
                "Rule matched for \(window.appName): \(rule.action)",
                details: ["windowID": "\(window.windowID)", "title": window.title ?? ""])

            switch rule.action {
            case .setFloating:
                window.isFloating = true
                window.alwaysFloat = true

            case .assignWorkspace(let id):
                window.workspaceID = id
                workspaceManager.addWindow(window.windowID, to: id)

            case .setOpacity:
                break // Requires private APIs

            case .moveToMonitor:
                break // Handled during layout

            case .pinToMaster:
                window.isPinned = true

            case .setGeometry(let x, let y, let w, let h):
                window.isFloating = true
                window.floatGeometry = CGRect(x: x, y: y, width: w, height: h)

            case .setFloatSize(let w, let h):
                window.isFloating = true
                window.floatGeometry = CGRect(x: 0, y: 0, width: w, height: h)

            case .hide:
                window.isFloating = true
                AccessibilityWrapper.setWindowPosition(window.axElement, position: CGPoint(x: -10000, y: -10000))

            case .ignore:
                window.isFloating = true

            case .makeSticky:
                window.isSticky = true

            case .assignTag(let tag):
                window.tags.insert(tag)

            case .centerOnOpen:
                window.centerOnOpen = true
                window.isFloating = true

            case .alwaysOnTop:
                window.isFloating = true

            case .setLayout:
                break // Handled at workspace level
            }
        }
    }

    /// Evaluate context rules periodically.
    func evaluateContextRules(monitorManager: MonitorManager) -> [ContextAction] {
        let now = Date()
        guard now.timeIntervalSince(lastContextEval) >= contextEvalInterval else { return [] }
        lastContextEval = now

        var actions: [ContextAction] = []
        let sorted = contextRules.sorted { $0.priority > $1.priority }

        for rule in sorted {
            if rule.evaluate(monitorManager: monitorManager) {
                actions.append(contentsOf: rule.actions)
                EventLog.shared.log(.ruleMatched, "Context rule matched: \(rule.name)")
            }
        }

        return actions
    }

    /// Force re-evaluate context rules now.
    func forceContextEvaluation(monitorManager: MonitorManager) -> [ContextAction] {
        lastContextEval = .distantPast
        return evaluateContextRules(monitorManager: monitorManager)
    }

    private func loadRules(from config: ConfigModel) {
        rules = config.windowRules.compactMap { WindowRule.parse($0) }
        contextRules = config.contextRules.compactMap { ContextRule.parse($0) }
        EventLog.shared.log(.configReloaded,
            "Loaded \(rules.count) window rules, \(contextRules.count) context rules")
    }
}
