import CoreGraphics

/// Protocol for SonicLand plugins.
protocol SonicLandPlugin: AnyObject {
    var name: String { get }

    func onLoad()
    func onUnload()
    func onWindowCreated(window: WindowNode)
    func onWindowDestroyed(windowID: CGWindowID)
    func onWorkspaceChanged(from: Int, to: Int)
    func onLayoutComputed(workspaceID: Int, frames: [CGWindowID: CGRect])
    func onTick()
}

/// Default implementations — all hooks are optional.
extension SonicLandPlugin {
    func onLoad() {}
    func onUnload() {}
    func onWindowCreated(window: WindowNode) {}
    func onWindowDestroyed(windowID: CGWindowID) {}
    func onWorkspaceChanged(from: Int, to: Int) {}
    func onLayoutComputed(workspaceID: Int, frames: [CGWindowID: CGRect]) {}
    func onTick() {}
}
