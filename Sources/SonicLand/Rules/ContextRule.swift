import Foundation
import AppKit
import IOKit.ps

/// Conditions based on environment/context rather than window properties.
enum ContextCondition {
    case externalMonitorConnected
    case noExternalMonitor
    case onBattery
    case onPower
    case monitorCount(Int)
    case timeRange(hour: Int, minute: Int, toHour: Int, toMinute: Int)
    case appRunning(String)  // Bundle ID
    case appNotRunning(String)

    func evaluate(monitorManager: MonitorManager) -> Bool {
        switch self {
        case .externalMonitorConnected:
            return monitorManager.monitors.count > 1

        case .noExternalMonitor:
            return monitorManager.monitors.count <= 1

        case .onBattery:
            return getBatteryState() == .battery

        case .onPower:
            return getBatteryState() == .ac

        case .monitorCount(let count):
            return monitorManager.monitors.count == count

        case .timeRange(let fromH, let fromM, let toH, let toM):
            let cal = Calendar.current
            let now = cal.dateComponents([.hour, .minute], from: Date())
            let currentMinutes = (now.hour ?? 0) * 60 + (now.minute ?? 0)
            let fromMinutes = fromH * 60 + fromM
            let toMinutes = toH * 60 + toM
            if fromMinutes <= toMinutes {
                return currentMinutes >= fromMinutes && currentMinutes < toMinutes
            } else {
                return currentMinutes >= fromMinutes || currentMinutes < toMinutes
            }

        case .appRunning(let bundleID):
            return NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier?.lowercased() == bundleID.lowercased()
            }

        case .appNotRunning(let bundleID):
            return !NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier?.lowercased() == bundleID.lowercased()
            }
        }
    }
}

/// A context-aware rule: when context matches, apply an action.
struct ContextRule {
    let name: String
    let conditions: [ContextCondition]
    let actions: [ContextAction]
    var priority: Int

    func evaluate(monitorManager: MonitorManager) -> Bool {
        conditions.allSatisfy { $0.evaluate(monitorManager: monitorManager) }
    }
}

/// Actions triggered by context rules.
enum ContextAction {
    case activateProfile(String)
    case setLayout(LayoutMode)
    case setGaps(inner: CGFloat, outer: CGFloat)
    case enableDND
    case disableDND
    case moveAppToWorkspace(bundleID: String, workspaceID: Int)
    case hideApp(bundleID: String)
    case showNotification(String)
}

private enum PowerState {
    case ac
    case battery
    case unknown
}

private func getBatteryState() -> PowerState {
    let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
    let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

    for source in sources {
        if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
           let state = info[kIOPSPowerSourceStateKey] as? String {
            if state == kIOPSACPowerValue {
                return .ac
            } else if state == kIOPSBatteryPowerValue {
                return .battery
            }
        }
    }
    return .unknown
}

extension ContextRule {
    static func parse(_ line: String) -> ContextRule? {
        // Format: "context_rule = <name>, <condition>, <action>"
        let parts = line.split(separator: ",", maxSplits: 2).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 else { return nil }

        let name = parts[0]
        let condStr = parts[1].lowercased()
        let actionStr = parts[2]

        let condition: ContextCondition
        if condStr == "external_monitor" {
            condition = .externalMonitorConnected
        } else if condStr == "no_external_monitor" {
            condition = .noExternalMonitor
        } else if condStr == "on_battery" {
            condition = .onBattery
        } else if condStr == "on_power" {
            condition = .onPower
        } else if condStr.hasPrefix("monitors:") {
            guard let count = Int(condStr.dropFirst("monitors:".count)) else { return nil }
            condition = .monitorCount(count)
        } else if condStr.hasPrefix("app_running:") {
            condition = .appRunning(String(condStr.dropFirst("app_running:".count)))
        } else if condStr.hasPrefix("app_not_running:") {
            condition = .appNotRunning(String(condStr.dropFirst("app_not_running:".count)))
        } else {
            return nil
        }

        let action: ContextAction
        let actionLower = actionStr.lowercased()
        if actionLower.hasPrefix("profile ") {
            action = .activateProfile(String(actionStr.dropFirst("profile ".count)))
        } else if actionLower.hasPrefix("layout ") {
            guard let mode = LayoutMode(rawValue: String(actionLower.dropFirst("layout ".count))) else { return nil }
            action = .setLayout(mode)
        } else if actionLower == "dnd_on" {
            action = .enableDND
        } else if actionLower == "dnd_off" {
            action = .disableDND
        } else if actionLower.hasPrefix("notify ") {
            action = .showNotification(String(actionStr.dropFirst("notify ".count)))
        } else {
            return nil
        }

        return ContextRule(name: name, conditions: [condition], actions: [action], priority: 0)
    }
}
