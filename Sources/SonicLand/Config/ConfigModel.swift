import Foundation

/// Typed configuration model.
struct ConfigModel {
    var general = GeneralConfig()
    var animation = AnimationConfig()
    var bindings: [BindingConfig] = []
    var windowRules: [String] = []

    struct GeneralConfig {
        var gapsIn: CGFloat = 5
        var gapsOut: CGFloat = 10
        var borderSize: CGFloat = 2
        var monitor: String = "all"  // "all", "built-in", "external", or monitor name substring
    }

    struct AnimationConfig {
        var enabled: Bool = true
        var duration: Double = 200 // milliseconds
        var curve: EasingCurve = .easeOut
    }

    struct BindingConfig {
        var keys: String   // e.g., "cmd+alt+h"
        var action: String // e.g., "focus_left"
    }
}
