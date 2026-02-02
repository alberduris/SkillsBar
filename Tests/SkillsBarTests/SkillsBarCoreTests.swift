import Foundation
import Testing
@testable import SkillsBarCore

// MARK: - Agent Tests

@Suite("Agent Tests")
struct AgentTests {
    @Test("Agent paths are correctly constructed")
    func agentPaths() {
        let agent = Agent(
            id: "test",
            displayName: "Test Agent",
            configDirName: ".test",
            supportsPlugins: true
        )

        let home = FileManager.default.homeDirectoryForCurrentUser
        #expect(agent.globalSkillsPath == home.appendingPathComponent(".test/skills"))
        #expect(agent.pluginsPath == home.appendingPathComponent(".test/plugins"))
        #expect(agent.installedPluginsPath == home.appendingPathComponent(".test/plugins/installed_plugins.json"))
    }

    @Test("Agent without plugins support has no plugins path")
    func noPluginsPath() {
        let agent = Agent(
            id: "noplugins",
            displayName: "No Plugins Agent",
            configDirName: ".noplugins",
            supportsPlugins: false
        )

        #expect(agent.pluginsPath == nil)
        #expect(agent.installedPluginsPath == nil)
    }
}

// MARK: - AgentRegistry Tests

@Suite("AgentRegistry Tests")
struct AgentRegistryTests {
    @Test("Supported agents includes Claude Code")
    func supportedAgents() {
        let supported = AgentRegistry.supported
        #expect(!supported.isEmpty)
        #expect(supported.contains { $0.id == "claude" })
    }

    @Test("Default agent is Claude Code")
    func defaultAgent() {
        let defaultAgent = AgentRegistry.defaultAgent
        #expect(defaultAgent.id == "claude")
        #expect(defaultAgent.displayName == "Claude Code")
    }

    @Test("Agent lookup by ID works")
    func agentLookup() {
        let claude = AgentRegistry.agent(withID: "claude")
        #expect(claude != nil)
        #expect(claude?.displayName == "Claude Code")

        let unknown = AgentRegistry.agent(withID: "unknown")
        #expect(unknown == nil)
    }
}

// MARK: - SkillSource Tests

@Suite("SkillSource Tests")
struct SkillSourceTests {
    @Test("SkillSource has correct display names")
    func displayNames() {
        #expect(SkillSource.global.displayName == "Global")
        #expect(SkillSource.plugin.displayName == "Plugin")
        #expect(SkillSource.project.displayName == "Project")
    }

    @Test("SkillSource sort order prioritizes project")
    func sortOrder() {
        #expect(SkillSource.project.sortOrder < SkillSource.plugin.sortOrder)
        #expect(SkillSource.plugin.sortOrder < SkillSource.global.sortOrder)
    }
}

// MARK: - SKILLMDParser Tests

@Suite("SKILLMDParser Tests")
struct SKILLMDParserTests {
    @Test("Parse content with frontmatter")
    func parseWithFrontmatter() throws {
        let content = """
        ---
        name: test-skill
        description: A test skill
        version: 1.0.0
        author: Test Author
        ---
        # Test Skill

        This is the body.
        """

        let result = try SKILLMDParser.parse(content: content, fallbackName: "fallback")
        #expect(result.name == "test-skill")
        #expect(result.description == "A test skill")
        #expect(result.metadata.version == "1.0.0")
        #expect(result.metadata.author == "Test Author")
    }

    @Test("Parse content without frontmatter uses fallback")
    func parseWithoutFrontmatter() throws {
        let content = """
        # My Skill

        This is a skill without frontmatter.
        """

        let result = try SKILLMDParser.parse(content: content, fallbackName: "my-fallback")
        #expect(result.name == "my-fallback")
        #expect(result.description.contains("This is a skill"))
    }

    @Test("Parse metadata flags")
    func parseMetadataFlags() throws {
        let content = """
        ---
        name: private-skill
        disable_model_invocation: true
        user_invocable: false
        ---
        Private skill content.
        """

        let result = try SKILLMDParser.parse(content: content, fallbackName: "test")
        #expect(result.metadata.disableModelInvocation == true)
        #expect(result.metadata.userInvocable == false)
    }
}

// MARK: - Skill Tests

@Suite("Skill Tests")
struct SkillTests {
    @Test("Skills are comparable by source then name")
    func skillComparable() {
        let agent = AgentRegistry.defaultAgent

        let globalSkill = Skill(
            id: "1",
            name: "zebra",
            description: "",
            agent: agent,
            source: .global,
            path: URL(fileURLWithPath: "/test")
        )

        let projectSkill = Skill(
            id: "2",
            name: "alpha",
            description: "",
            agent: agent,
            source: .project,
            path: URL(fileURLWithPath: "/test")
        )

        // Project skills should come before global skills
        #expect(projectSkill < globalSkill)
    }

    @Test("Skill user invocable defaults to true")
    func skillUserInvocable() {
        let agent = AgentRegistry.defaultAgent
        let skill = Skill(
            id: "1",
            name: "test",
            description: "",
            agent: agent,
            source: .global,
            path: URL(fileURLWithPath: "/test"),
            metadata: nil
        )

        #expect(skill.isUserInvocable == true)
    }
}
