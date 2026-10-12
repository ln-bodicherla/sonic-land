import Foundation

/// Typed configuration model.
struct ConfigModel {
    var general = GeneralConfig()
    var animation = AnimationConfig()
    var bindings: [BindingConfig] = []
    var windowRules: [String] = []
    var workspaceConfig: [Int: WorkspaceConfig] = [:]
    var scratchpads: [ScratchpadConfig] = []
    var contextRules: [String] = []
    var sessionRestore = SessionConfig()
    var overlay = OverlayConfig()

    struct GeneralConfig {
        var gapsIn: CGFloat = 5
        var gapsOut: CGFloat = 10
        var borderSize: CGFloat = 2
        var monitor: String = "all"
        var defaultLayout: String = "bsp"
        var masterRatio: CGFloat = 0.55
        var masterCount: Int = 1
        var focusFollowsMouse: Bool = false
        var dndMode: Bool = false  // Do not disturb layout
    }

    struct AnimationConfig {
        var enabled: Bool = true
        var duration: Double = 200 // milliseconds
        var curve: EasingCurve = .easeOut
    }

    struct BindingConfig {
        var keys: String
        var action: String
    }

    struct WorkspaceConfig {
        var name: String?
        var layout: String?
        var type: String?
        var masterRatio: CGFloat?
        var masterCount: Int?
        var gapsIn: CGFloat?
        var gapsOut: CGFloat?
        var monitor: Int?
        var startupActions: [String] = []
    }

    struct ScratchpadConfig {
        var name: String
        var app: String?
        var bundleID: String?
        var command: String?
        var width: CGFloat = 800
        var height: CGFloat = 600
        var center: Bool = true
        var autoHide: Bool = false
    }

    struct SessionConfig {
        var enabled: Bool = true
        var restoreApps: Bool = false
        var saveOnQuit: Bool = true
    }

    struct OverlayConfig {
        var showWorkspaceName: Bool = true
        var showLayoutName: Bool = true
        var showFocusRing: Bool = false
        var showWorkspaceMap: Bool = true
    }
}
