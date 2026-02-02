import AppKit
import Observation
import ServiceManagement
import SkillsBarCore

@MainActor
@Observable
final class SettingsStore {
    // MARK: - User Defaults Keys

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let autoUpdate = "autoUpdateEnabled"
        static let showGlobalSkills = "showGlobalSkills"
        static let showPluginSkills = "showPluginSkills"
        static let showProjectSkills = "showProjectSkills"
        static let projectPath = "projectPath"
        static let recursiveProjectPath = "recursiveProjectPath"
        static let showGlobalMCPs = "showGlobalMCPs"
        static let showProjectMCPs = "showProjectMCPs"
        static let showBuiltInMCPs = "showBuiltInMCPs"
        static let enabledAgentIDs = "enabledAgentIDs"
        static let debugLogLevel = "debugLogLevel"
    }

    // MARK: - Defaults

    @ObservationIgnored private let userDefaults: UserDefaults

    // MARK: - Settings Properties

    var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var autoUpdateEnabled: Bool {
        didSet {
            userDefaults.set(autoUpdateEnabled, forKey: Keys.autoUpdate)
        }
    }

    var showGlobalSkills: Bool {
        didSet {
            userDefaults.set(showGlobalSkills, forKey: Keys.showGlobalSkills)
        }
    }

    var showPluginSkills: Bool {
        didSet {
            userDefaults.set(showPluginSkills, forKey: Keys.showPluginSkills)
        }
    }

    var showProjectSkills: Bool {
        didSet {
            userDefaults.set(showProjectSkills, forKey: Keys.showProjectSkills)
        }
    }

    var showGlobalMCPs: Bool {
        didSet {
            userDefaults.set(showGlobalMCPs, forKey: Keys.showGlobalMCPs)
        }
    }

    var showProjectMCPs: Bool {
        didSet {
            userDefaults.set(showProjectMCPs, forKey: Keys.showProjectMCPs)
        }
    }

    var showBuiltInMCPs: Bool {
        didSet {
            userDefaults.set(showBuiltInMCPs, forKey: Keys.showBuiltInMCPs)
        }
    }

    var projectPaths: [URL] {
        didSet {
            let paths = projectPaths.map(\.path)
            userDefaults.set(paths, forKey: Keys.projectPath)
        }
    }

    var recursiveProjectPaths: [URL] {
        didSet {
            let paths = recursiveProjectPaths.map(\.path)
            userDefaults.set(paths, forKey: Keys.recursiveProjectPath)
        }
    }

    var enabledAgentIDs: Set<String> {
        didSet {
            userDefaults.set(Array(enabledAgentIDs), forKey: Keys.enabledAgentIDs)
        }
    }

    var debugLogLevel: SkillsBarLog.Level {
        didSet {
            userDefaults.set(debugLogLevel.rawValue, forKey: Keys.debugLogLevel)
            SkillsBarLog.setLogLevel(debugLogLevel)
        }
    }

    // MARK: - Computed Properties

    var enabledAgents: [Agent] {
        AgentRegistry.supported.filter { enabledAgentIDs.contains($0.id) }
    }

    // MARK: - Initialization

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load saved values or defaults
        launchAtLogin = userDefaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        autoUpdateEnabled = userDefaults.object(forKey: Keys.autoUpdate) as? Bool ?? true

        showGlobalSkills = userDefaults.object(forKey: Keys.showGlobalSkills) as? Bool ?? true
        showPluginSkills = userDefaults.object(forKey: Keys.showPluginSkills) as? Bool ?? true
        showProjectSkills = userDefaults.object(forKey: Keys.showProjectSkills) as? Bool ?? true

        showGlobalMCPs = userDefaults.object(forKey: Keys.showGlobalMCPs) as? Bool ?? true
        showProjectMCPs = userDefaults.object(forKey: Keys.showProjectMCPs) as? Bool ?? true
        showBuiltInMCPs = userDefaults.object(forKey: Keys.showBuiltInMCPs) as? Bool ?? true

        // Load project paths - support both old single path and new array format
        if let pathStrings = userDefaults.stringArray(forKey: Keys.projectPath) {
            projectPaths = pathStrings.map { URL(fileURLWithPath: $0) }
        } else if let pathString = userDefaults.string(forKey: Keys.projectPath) {
            // Migration from old single-path format
            projectPaths = [URL(fileURLWithPath: pathString)]
        } else {
            projectPaths = []
        }

        // Load recursive project paths (repos folders)
        if let pathStrings = userDefaults.stringArray(forKey: Keys.recursiveProjectPath) {
            recursiveProjectPaths = pathStrings.map { URL(fileURLWithPath: $0) }
        } else {
            recursiveProjectPaths = []
        }

        // Default: only Claude Code enabled
        if let savedAgentIDs = userDefaults.stringArray(forKey: Keys.enabledAgentIDs) {
            enabledAgentIDs = Set(savedAgentIDs)
        } else {
            enabledAgentIDs = Set(AgentRegistry.supported.map(\.id))
        }

        let logLevelRaw = userDefaults.string(forKey: Keys.debugLogLevel) ?? SkillsBarLog.Level.info.rawValue
        debugLogLevel = SkillsBarLog.parseLevel(logLevelRaw) ?? .info

        // Apply initial settings
        LaunchAtLoginManager.setEnabled(launchAtLogin)

        // Sync enabled agents to SkillsStore on init
        Task { @MainActor in
            syncSkillsStoreAgents()
        }
    }

    // MARK: - Agent Management

    func isAgentEnabled(_ agent: Agent) -> Bool {
        enabledAgentIDs.contains(agent.id)
    }

    func setAgentEnabled(_ agent: Agent, enabled: Bool) {
        if enabled {
            enabledAgentIDs.insert(agent.id)
        } else {
            enabledAgentIDs.remove(agent.id)
        }
        syncSkillsStoreAgents()
    }

    /// Sync enabled agents to SkillsStore
    private func syncSkillsStoreAgents() {
        let agents = AgentRegistry.supported.filter { enabledAgentIDs.contains($0.id) }
        SkillsStore.shared.enabledAgents = agents
    }

    func toggleAgent(_ agent: Agent) {
        if enabledAgentIDs.contains(agent.id) {
            enabledAgentIDs.remove(agent.id)
        } else {
            enabledAgentIDs.insert(agent.id)
        }
    }
}

// MARK: - Singleton

extension SettingsStore {
    static let shared = SettingsStore()
}
