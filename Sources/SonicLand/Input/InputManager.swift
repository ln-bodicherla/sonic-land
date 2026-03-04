import AppKit
import CoreGraphics

final class InputManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var bindings: [KeyBinding] = []
    private var healthCheckTimer: Timer?

    var actionHandler: ((KeyAction) -> Void)?

    init(config: ConfigModel) {
        loadBindings(from: config)
    }

    func updateConfig(_ config: ConfigModel) {
        loadBindings(from: config)
    }

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            NSLog("[SonicLand] Failed to create event tap. Make sure accessibility permission is granted.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        // Health check timer — re-enable if system disables the tap
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkTapHealth()
        }

        NSLog("[SonicLand] Event tap created. Listening for keyboard shortcuts.")
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        NSLog("[SonicLand] Event tap stopped.")
    }

    // MARK: - Event Handling

    func handleKeyEvent(_ event: CGEvent) -> CGEvent? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))

        for binding in bindings {
            if binding.matches(keyCode: keyCode, modifiers: flags) {
                DispatchQueue.main.async { [weak self] in
                    self?.actionHandler?(binding.action)
                }
                return nil // Suppress the event
            }
        }

        return event // Pass through unmatched events
    }

    // MARK: - Private

    private func checkTapHealth() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            NSLog("[SonicLand] Event tap was disabled. Re-enabling...")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func loadBindings(from config: ConfigModel) {
        bindings = []

        for bindConfig in config.bindings {
            guard let keys = KeyBinding.parseKeys(bindConfig.keys),
                  let action = KeyAction.from(string: bindConfig.action) else {
                NSLog("[SonicLand] Invalid binding: \(bindConfig.keys) = \(bindConfig.action)")
                continue
            }
            bindings.append(KeyBinding(modifiers: keys.modifiers, keyCode: keys.keyCode, action: action))
        }

        // Add default bindings if none configured
        if bindings.isEmpty {
            loadDefaultBindings()
        }

        NSLog("[SonicLand] Loaded \(bindings.count) keybindings.")
    }

    private func loadDefaultBindings() {
        let defaults: [(String, KeyAction)] = [
            // Focus
            ("cmd+alt+h", .focusLeft),
            ("cmd+alt+l", .focusRight),
            ("cmd+alt+j", .focusDown),
            ("cmd+alt+k", .focusUp),
            // Move
            ("cmd+alt+shift+h", .moveLeft),
            ("cmd+alt+shift+l", .moveRight),
            ("cmd+alt+shift+j", .moveDown),
            ("cmd+alt+shift+k", .moveUp),
            // Workspaces
            ("cmd+alt+1", .switchWorkspace(1)),
            ("cmd+alt+2", .switchWorkspace(2)),
            ("cmd+alt+3", .switchWorkspace(3)),
            ("cmd+alt+4", .switchWorkspace(4)),
            ("cmd+alt+5", .switchWorkspace(5)),
            ("cmd+alt+6", .switchWorkspace(6)),
            ("cmd+alt+7", .switchWorkspace(7)),
            ("cmd+alt+8", .switchWorkspace(8)),
            ("cmd+alt+9", .switchWorkspace(9)),
            // Move to workspace
            ("cmd+alt+shift+1", .moveToWorkspace(1)),
            ("cmd+alt+shift+2", .moveToWorkspace(2)),
            ("cmd+alt+shift+3", .moveToWorkspace(3)),
            ("cmd+alt+shift+4", .moveToWorkspace(4)),
            ("cmd+alt+shift+5", .moveToWorkspace(5)),
            ("cmd+alt+shift+6", .moveToWorkspace(6)),
            ("cmd+alt+shift+7", .moveToWorkspace(7)),
            ("cmd+alt+shift+8", .moveToWorkspace(8)),
            ("cmd+alt+shift+9", .moveToWorkspace(9)),
            // Toggle
            ("cmd+alt+f", .toggleFloat),
            ("cmd+alt+space", .toggleLayoutDirection),
            ("cmd+alt+r", .reloadConfig),
        ]

        for (keyStr, action) in defaults {
            if let keys = KeyBinding.parseKeys(keyStr) {
                bindings.append(KeyBinding(modifiers: keys.modifiers, keyCode: keys.keyCode, action: action))
            }
        }
    }
}

// MARK: - C Callback

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passRetained(event) }

    // Handle tap disabled by timeout
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        _ = Unmanaged<InputManager>.fromOpaque(refcon).takeUnretainedValue()
        NSLog("[SonicLand] Event tap disabled by system. Will re-enable on next health check.")
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<InputManager>.fromOpaque(refcon).takeUnretainedValue()
    if let result = manager.handleKeyEvent(event) {
        return Unmanaged.passRetained(result)
    }
    return nil // Event was consumed
}
