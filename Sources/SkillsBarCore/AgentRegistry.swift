import Foundation

/// Registry of AI coding agents supported by SkillsBar
public enum AgentRegistry {
    /// All agents with their current support status
    /// Sorted by: active first, then beta, then coming soon (alphabetically within each group)
    public static let all: [Agent] = [
        // MARK: - Active

        Agent(
            id: "claude",
            displayName: "Claude Code",
            tagline: "Anthropic's agentic coding CLI",
            configDirName: ".claude",
            supportsPlugins: true,
            skillFileName: "SKILL.md",
            status: .active,
            iconName: "claude",
            accentColorHex: "#D97757",
            websiteURL: "https://claude.ai/code"
        ),

        // MARK: - Coming Soon (alphabetical)

        Agent(
            id: "aider",
            displayName: "Aider",
            tagline: "AI pair programming in your terminal",
            configDirName: ".aider",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "aider",
            accentColorHex: "#14B8A6",
            websiteURL: "https://aider.chat"
        ),
        Agent(
            id: "cline",
            displayName: "Cline",
            tagline: "Autonomous coding agent for VS Code",
            configDirName: ".cline",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "cline",
            accentColorHex: "#8B5CF6",
            websiteURL: "https://cline.bot"
        ),
        Agent(
            id: "codex",
            displayName: "Codex CLI",
            tagline: "OpenAI's coding assistant",
            configDirName: ".codex",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "codex",
            accentColorHex: "#10A37F",
            websiteURL: "https://openai.com/codex"
        ),
        Agent(
            id: "copilot",
            displayName: "GitHub Copilot",
            tagline: "Your AI pair programmer",
            configDirName: ".github-copilot",
            supportsPlugins: false,
            skillFileName: "copilot-instructions.md",
            status: .comingSoon,
            iconName: "copilot",
            accentColorHex: "#6366F1",
            websiteURL: "https://github.com/features/copilot"
        ),
        Agent(
            id: "cursor",
            displayName: "Cursor",
            tagline: "The AI-first code editor",
            configDirName: ".cursor",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "cursor",
            accentColorHex: "#FBBF24",
            websiteURL: "https://cursor.sh"
        ),
        Agent(
            id: "gemini",
            displayName: "Gemini CLI",
            tagline: "Google's AI coding assistant",
            configDirName: ".gemini",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "gemini",
            accentColorHex: "#4285F4",
            websiteURL: "https://ai.google.dev"
        ),
        Agent(
            id: "opencode",
            displayName: "OpenCode",
            tagline: "Open-source AI coding agent",
            configDirName: ".opencode",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "opencode",
            accentColorHex: "#F97316",
            websiteURL: "https://opencode.ai"
        ),
        Agent(
            id: "windsurf",
            displayName: "Windsurf",
            tagline: "Next-gen agentic IDE by Codeium",
            configDirName: ".windsurf",
            supportsPlugins: false,
            status: .comingSoon,
            iconName: "windsurf",
            accentColorHex: "#06B6D4",
            websiteURL: "https://windsurf.com"
        ),
    ]

    /// Only actively supported agents
    public static var supported: [Agent] {
        all.filter { $0.status == .active }
    }

    /// Agents in beta
    public static var beta: [Agent] {
        all.filter { $0.status == .beta }
    }

    /// Agents planned for future support
    public static var planned: [Agent] {
        all.filter { $0.status == .comingSoon }
    }

    /// Find an agent by ID
    public static func agent(withID id: String) -> Agent? {
        all.first { $0.id == id }
    }

    /// Find an agent by config directory name
    public static func agent(withConfigDir configDir: String) -> Agent? {
        all.first { $0.configDirName == configDir }
    }

    /// Default agent (Claude Code)
    public static var defaultAgent: Agent {
        supported.first ?? all[0]
    }
}
