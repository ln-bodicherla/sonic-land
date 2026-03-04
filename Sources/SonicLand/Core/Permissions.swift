import AppKit
import ApplicationServices

enum Permissions {
    /// Check if accessibility permission is granted, prompting the user if not.
    /// Returns true if permission is already granted.
    static func ensureAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            NSLog("[SonicLand] Accessibility permission not yet granted. A system dialog should appear.")
            NSLog("[SonicLand] Please grant accessibility access in System Settings > Privacy & Security > Accessibility")

            // Show a helpful alert
            let alert = NSAlert()
            alert.messageText = "SonicLand Needs Accessibility Permission"
            alert.informativeText = "SonicLand requires accessibility access to manage windows. Please grant access in System Settings, then relaunch SonicLand."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }

        return trusted
    }

    /// Check accessibility without prompting.
    static func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }
}
