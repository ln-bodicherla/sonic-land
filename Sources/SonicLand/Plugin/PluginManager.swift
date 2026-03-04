import AppKit
import CoreGraphics

/// Manages plugin lifecycle and event dispatch.
final class PluginManager {
    private var plugins: [SonicLandPlugin] = []

    func register(_ plugin: SonicLandPlugin) {
        plugins.append(plugin)
        plugin.onLoad()
        NSLog("[SonicLand] Plugin loaded: \(plugin.name)")
    }

    func unregisterAll() {
        for plugin in plugins {
            plugin.onUnload()
        }
        plugins.removeAll()
    }

    // MARK: - Event Dispatch

    func onWindowCreated(window: WindowNode) {
        for plugin in plugins {
            plugin.onWindowCreated(window: window)
        }
    }

    func onWindowDestroyed(windowID: CGWindowID) {
        for plugin in plugins {
            plugin.onWindowDestroyed(windowID: windowID)
        }
    }

    func onWorkspaceChanged(from: Int, to: Int) {
        for plugin in plugins {
            plugin.onWorkspaceChanged(from: from, to: to)
        }
    }

    func onLayoutComputed(workspaceID: Int, frames: [CGWindowID: CGRect]) {
        for plugin in plugins {
            plugin.onLayoutComputed(workspaceID: workspaceID, frames: frames)
        }
    }

    func onTick() {
        for plugin in plugins {
            plugin.onTick()
        }
    }
}
