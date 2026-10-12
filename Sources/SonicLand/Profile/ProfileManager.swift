import Foundation

/// A user profile storing desktop behavior preferences.
struct Profile: Codable {
    var name: String
    var workspaceNames: [Int: String]
    var workspaceLayouts: [Int: String]  // LayoutMode rawValue
    var gapsInner: CGFloat?
    var gapsOuter: CGFloat?
    var animationEnabled: Bool?
    var animationDuration: Double?
    var windowRules: [String]
    var scratchpads: [Scratchpad]
    var monitorProfile: String?  // "docked", "undocked", "clamshell"

    init(name: String) {
        self.name = name
        self.workspaceNames = [:]
        self.workspaceLayouts = [:]
        self.windowRules = []
        self.scratchpads = []
    }
}

/// Manages profile loading, saving, and switching.
final class ProfileManager {
    private var profiles: [String: Profile] = [:]
    private(set) var activeProfile: String?
    private let profilesDir: URL

    init() {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sonicland/profiles")
        self.profilesDir = configDir

        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        loadAllProfiles()
    }

    func allProfiles() -> [Profile] {
        Array(profiles.values).sorted { $0.name < $1.name }
    }

    func profile(named name: String) -> Profile? {
        profiles[name]
    }

    func saveProfile(_ profile: Profile) {
        profiles[profile.name] = profile

        let fileURL = profilesDir.appendingPathComponent("\(profile.name).json")
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: fileURL)
            EventLog.shared.log(.profileActivated, "Saved profile: \(profile.name)")
        }
    }

    func deleteProfile(named name: String) {
        profiles.removeValue(forKey: name)
        let fileURL = profilesDir.appendingPathComponent("\(name).json")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func activateProfile(_ name: String) -> Profile? {
        guard let profile = profiles[name] else { return nil }
        activeProfile = name
        UserDefaults.standard.set(name, forKey: "SonicLandActiveProfile")
        EventLog.shared.log(.profileActivated, "Activated profile: \(name)")
        return profile
    }

    func captureCurrentState(
        name: String,
        workspaceManager: WorkspaceManager,
        layoutEngine: LayoutEngine,
        config: ConfigModel,
        scratchpadManager: ScratchpadManager
    ) -> Profile {
        var profile = Profile(name: name)

        for ws in workspaceManager.allWorkspaces {
            profile.workspaceNames[ws.id] = ws.name
            profile.workspaceLayouts[ws.id] = ws.layoutMode.rawValue
        }

        profile.gapsInner = config.general.gapsIn
        profile.gapsOuter = config.general.gapsOut
        profile.animationEnabled = config.animation.enabled
        profile.animationDuration = config.animation.duration
        profile.windowRules = config.windowRules
        profile.scratchpads = scratchpadManager.allScratchpads()

        saveProfile(profile)
        return profile
    }

    private func loadAllProfiles() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: profilesDir, includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let profile = try? JSONDecoder().decode(Profile.self, from: data) else { continue }
            profiles[profile.name] = profile
        }

        NSLog("[SonicLand] Loaded \(profiles.count) profile(s)")

        if let lastActive = UserDefaults.standard.string(forKey: "SonicLandActiveProfile") {
            activeProfile = lastActive
        }
    }
}
