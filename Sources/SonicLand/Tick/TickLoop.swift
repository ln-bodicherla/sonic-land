import Foundation

/// 60Hz update loop for detecting external window changes and maintaining layout.
final class TickLoop {
    private var timer: DispatchSourceTimer?
    private let onTick: () -> Void
    private let interval: TimeInterval

    init(fps: Double = 60, onTick: @escaping () -> Void) {
        self.interval = 1.0 / fps
        self.onTick = onTick
    }

    func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.onTick()
        }
        timer.resume()
        self.timer = timer

        NSLog("[SonicLand] Tick loop started at \(Int(1.0 / interval)) Hz.")
    }

    func stop() {
        timer?.cancel()
        timer = nil
        NSLog("[SonicLand] Tick loop stopped.")
    }
}
