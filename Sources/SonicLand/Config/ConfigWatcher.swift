import Foundation

/// Watches the config file for changes and triggers hot reload.
final class ConfigWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private let configPath: String
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.configPath = NSString("~/.config/sonicland/sonicland.conf").expandingTildeInPath
        self.onChange = onChange
    }

    func start() {
        // Ensure config directory exists
        let configDir = (configPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)

        // Create config file if it doesn't exist
        if !FileManager.default.fileExists(atPath: configPath) {
            FileManager.default.createFile(atPath: configPath, contents: nil)
        }

        watchFile()
        NSLog("[SonicLand] Watching config file: \(configPath)")
    }

    func stop() {
        source?.cancel()
        source = nil
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
    }

    private func watchFile() {
        fileDescriptor = open(configPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            NSLog("[SonicLand] Failed to open config file for watching.")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            if flags.contains(.delete) || flags.contains(.rename) {
                // File was replaced — re-watch
                self.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.start()
                }
            }
            NSLog("[SonicLand] Config file changed. Reloading...")
            self.onChange()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        source.resume()
        self.source = source
    }
}
