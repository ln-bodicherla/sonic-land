import AppKit
import CoreGraphics

/// Represents a physical display.
struct Monitor {
    let id: UInt32            // CGDirectDisplayID
    let name: String
    let frame: CGRect         // Full frame (top-left origin, AX coordinates)
    let visibleFrame: CGRect  // Frame minus menu bar and dock (AX coordinates)

    init(screen: NSScreen) {
        let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32 ?? 0
        self.id = displayID
        self.name = screen.localizedName

        // Convert NSScreen coordinates (bottom-left origin) to AX coordinates (top-left origin)
        let primaryScreen = NSScreen.screens.first!
        let primaryHeight = primaryScreen.frame.height

        // Full frame in AX coordinates
        let nsFrame = screen.frame
        self.frame = CGRect(
            x: nsFrame.origin.x,
            y: primaryHeight - nsFrame.origin.y - nsFrame.height,
            width: nsFrame.width,
            height: nsFrame.height
        )

        // Visible frame (excludes menu bar and dock) in AX coordinates
        let nsVisible = screen.visibleFrame
        self.visibleFrame = CGRect(
            x: nsVisible.origin.x,
            y: primaryHeight - nsVisible.origin.y - nsVisible.height,
            width: nsVisible.width,
            height: nsVisible.height
        )
    }
}
