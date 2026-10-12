import Foundation

/// Event types for the event log.
enum EventType: String, Codable {
    case windowCreated
    case windowDestroyed
    case windowMoved
    case windowFloated
    case windowTiled
    case windowSwapped
    case ruleMatched
    case ruleSkipped
    case workspaceSwitched
    case workspaceCreated
    case workspaceRenamed
    case layoutChanged
    case profileActivated
    case sessionRestored
    case sessionSaved
    case scratchpadToggled
    case monitorConnected
    case monitorDisconnected
    case configReloaded
    case error
}

/// A single event log entry.
struct EventEntry: Codable {
    let timestamp: Date
    let type: EventType
    let message: String
    let details: [String: String]?

    init(type: EventType, message: String, details: [String: String]? = nil) {
        self.timestamp = Date()
        self.type = type
        self.message = message
        self.details = details
    }
}

/// Event logging system for observability.
final class EventLog {
    static let shared = EventLog()

    private var entries: [EventEntry] = []
    private let maxEntries = 1000
    private let queue = DispatchQueue(label: "com.sonicland.eventlog")

    private init() {}

    func log(_ type: EventType, _ message: String, details: [String: String]? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let entry = EventEntry(type: type, message: message, details: details)
            self.entries.append(entry)
            if self.entries.count > self.maxEntries {
                self.entries.removeFirst(self.entries.count - self.maxEntries)
            }
        }
        NSLog("[SonicLand] [\(type.rawValue)] \(message)")
    }

    func recentEntries(count: Int = 50) -> [EventEntry] {
        queue.sync {
            Array(entries.suffix(count))
        }
    }

    func entries(ofType type: EventType, count: Int = 50) -> [EventEntry] {
        queue.sync {
            Array(entries.filter { $0.type == type }.suffix(count))
        }
    }

    func clear() {
        queue.async { [weak self] in
            self?.entries.removeAll()
        }
    }

    func allEntries() -> [EventEntry] {
        queue.sync { entries }
    }
}
