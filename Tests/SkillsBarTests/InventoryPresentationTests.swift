import Foundation
import Testing
@testable import SkillsBar
@testable import SkillsBarCore

@Suite("Inventory Presentation Tests")
struct InventoryPresentationTests {
    private let defaultAgent = AgentRegistry.defaultAgent

    @Test("Skill maps to inventory item with toggle and reveal actions")
    func skillMapping() {
        let skill = Skill(
            id: "skill:test",
            name: "test-skill",
            description: "A test skill",
            agent: defaultAgent,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/test-skill"),
            metadata: SkillMetadata(userInvocable: false),
            isEnabled: true,
            toggleCapability: .symlink,
            canonicalPath: URL(fileURLWithPath: "/tmp/.agents/skills/test-skill")
        )

        let item = InventoryItem.from(skill: skill)

        #expect(item.kind == .skill)
        #expect(item.title == "test-skill")
        #expect(item.availableActions.contains(.toggleEnabled))
        #expect(item.availableActions.contains(.revealInFinder))
        #expect(item.availableActions.contains(.copyPath))
        #expect(item.primaryAction == .toggleEnabled)
        #expect(item.isUserInvocable == false)
    }

    @Test("Non-toggleable skill exposes info action")
    func nonToggleableSkillMapping() {
        let skill = Skill(
            id: "skill:direct",
            name: "direct-skill",
            description: "",
            agent: defaultAgent,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/direct-skill"),
            isEnabled: true,
            toggleCapability: .none
        )

        let item = InventoryItem.from(skill: skill)

        #expect(item.availableActions.contains(.showInfo))
        #expect(!item.availableActions.contains(.toggleEnabled))
        #expect(item.infoMessage != nil)
    }

    @Test("MCP maps to inventory item with URL action")
    func mcpMapping() {
        let server = MCPServer(
            id: "mcp:global:context7",
            name: "context7",
            transport: .http,
            url: "https://mcp.example.com",
            source: .global
        )

        let item = InventoryItem.from(server: server)

        #expect(item.kind == .mcp)
        #expect(item.primaryAction == .openURL)
        #expect(item.availableActions.contains(.openURL))
        #expect(item.availableActions.contains(.copyPath))
        #expect(item.copyText == "https://mcp.example.com")
        #expect(item.badges.contains { $0.text == "HTTP" })
    }

    @Test("Agent maps to inventory item with reveal action")
    func agentMapping() {
        let agent = AgentProfile(
            id: "agent:test",
            name: "reviewer",
            description: "Reviews code",
            model: "sonnet",
            source: .plugin,
            path: URL(fileURLWithPath: "/tmp/reviewer.md"),
            pluginName: "qa",
            pluginScope: .project,
            isEnabled: true
        )

        let item = InventoryItem.from(agent: agent)

        #expect(item.kind == .agent)
        #expect(item.primaryAction == .revealInFinder)
        #expect(item.availableActions.contains(.revealInFinder))
        #expect(item.availableActions.contains(.copyPath))
        #expect(item.copyText == "/tmp/reviewer.md")
        #expect(item.badges.contains { $0.text == "Plugin" })
    }

    @MainActor
    @Test("View model selection tracks selected visible item")
    func viewModelSelection() throws {
        let store = SkillsStore()
        let skill = Skill(
            id: "skill:selected",
            name: "selected-skill",
            description: "",
            agent: defaultAgent,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/selected-skill"),
            isEnabled: true,
            toggleCapability: .symlink
        )
        store.replaceContentsForTesting(skills: [skill], mcpServers: [], agents: [])

        let viewModel = InventoryViewModel(skillsStore: store)

        #expect(viewModel.selectedItem == nil)
        #expect(viewModel.sections.count == 1)

        let item = try #require(viewModel.sections.first?.items.first)
        viewModel.select(item)

        #expect(viewModel.selectedItemID == item.id)
        #expect(viewModel.selectedItem?.id == item.id)
    }

    @MainActor
    @Test("View model clears selection when selected item is no longer visible")
    func viewModelSelectionPruning() throws {
        let store = SkillsStore()
        let skill = Skill(
            id: "skill:selected",
            name: "selected-skill",
            description: "",
            agent: defaultAgent,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/selected-skill"),
            isEnabled: true,
            toggleCapability: .symlink
        )
        let server = MCPServer(
            id: "mcp:global:server",
            name: "server",
            transport: .http,
            url: "https://example.com",
            source: .global
        )
        store.replaceContentsForTesting(skills: [skill], mcpServers: [server], agents: [])

        let viewModel = InventoryViewModel(skillsStore: store)
        let item = try #require(viewModel.sections.first?.items.first)
        viewModel.select(item)

        viewModel.selectedTab = .mcps

        #expect(viewModel.selectedItemID == nil)
        #expect(viewModel.selectedItem == nil)
    }

    @MainActor
    @Test("View model filter rebuild preserves selection when item stays visible")
    func viewModelFilterSelectionPersistence() throws {
        let store = SkillsStore()
        let projectRoot = URL(fileURLWithPath: "/work/apps/demo")
        let skill = Skill(
            id: "skill:project",
            name: "project-skill",
            description: "",
            agent: defaultAgent,
            source: .project,
            path: projectRoot.appendingPathComponent(".claude/skills/project-skill"),
            projectRoot: projectRoot,
            isEnabled: true,
            toggleCapability: .symlink
        )
        store.replaceContentsForTesting(skills: [skill], mcpServers: [], agents: [])

        let viewModel = InventoryViewModel(skillsStore: store)
        let item = try #require(viewModel.sections.first?.items.first)
        viewModel.select(item)
        viewModel.filterText = "apps/demo"

        #expect(viewModel.selectedItemID == item.id)
        #expect(viewModel.selectedItem?.id == item.id)
    }

    @Test("Skills sections preserve global and project grouping")
    func skillsSectionsGrouping() {
        let globalSkill = Skill(
            id: "skill:global",
            name: "global-skill",
            description: "",
            agent: defaultAgent,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/global-skill"),
            isEnabled: true,
            toggleCapability: .symlink
        )
        let projectRoot = URL(fileURLWithPath: "/work/apps/demo")
        let projectSkill = Skill(
            id: "skill:project",
            name: "project-skill",
            description: "",
            agent: defaultAgent,
            source: .project,
            path: projectRoot.appendingPathComponent(".claude/skills/project-skill"),
            projectRoot: projectRoot,
            isEnabled: false,
            toggleCapability: .move,
            canonicalPath: projectRoot.appendingPathComponent(".claude/skills/.disabled/project-skill")
        )

        let content = InventorySectionsBuilder.buildContent(
            for: .skills,
            snapshot: InventorySnapshot(skills: [globalSkill, projectSkill], mcpServers: [], agents: []),
            filterText: ""
        )

        #expect(content.sections.count == 2)
        #expect(content.sections[0].title == "All Projects")
        #expect(content.sections[1].title == "apps/demo")
        #expect(content.sections[1].trailingText == "(0/1)")
    }

    @Test("Skills filtering preserves global section and no-match state")
    func skillsFilteringNoMatches() {
        let globalSkill = Skill(
            id: "skill:global",
            name: "global-skill",
            description: "",
            agent: defaultAgent,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/global-skill"),
            isEnabled: true,
            toggleCapability: .symlink
        )

        let content = InventorySectionsBuilder.buildContent(
            for: .skills,
            snapshot: InventorySnapshot(skills: [globalSkill], mcpServers: [], agents: []),
            filterText: "missing-project"
        )

        #expect(content.sections.count == 1)
        #expect(content.sections[0].title == "All Projects")
        #expect(content.showsNoMatchesState == true)
    }

    @Test("MCP sections group project entries and preserve built-in note")
    func mcpSectionsGrouping() {
        let globalServer = MCPServer(
            id: "mcp:global:notion",
            name: "notion",
            transport: .http,
            url: "https://mcp.notion.com",
            source: .global
        )
        let projectServer = MCPServer(
            id: "mcp:project:demo:vercel",
            name: "vercel",
            transport: .stdio,
            command: "npx",
            args: ["vercel-mcp"],
            source: .project,
            projectName: "demo"
        )
        let builtInServer = MCPServer(
            id: "mcp:builtin:chrome",
            name: "claude-in-chrome",
            transport: .stdio,
            source: .builtIn
        )

        let content = InventorySectionsBuilder.buildContent(
            for: .mcps,
            snapshot: InventorySnapshot(skills: [], mcpServers: [globalServer, projectServer, builtInServer], agents: []),
            filterText: ""
        )

        #expect(content.sections.count == 3)
        #expect(content.sections.contains { $0.title == "All Projects" })
        #expect(content.sections.contains { $0.title == "demo" })
        #expect(content.sections.contains { $0.note?.contains("Runtime MCPs") == true })
    }

    @Test("Agents sections preserve global and project grouping")
    func agentsSectionsGrouping() {
        let globalAgent = AgentProfile(
            id: "agent:global",
            name: "global-agent",
            description: "",
            model: nil,
            source: .global,
            path: URL(fileURLWithPath: "/tmp/global-agent.md")
        )
        let projectRoot = URL(fileURLWithPath: "/work/tools/monorepo")
        let projectAgent = AgentProfile(
            id: "agent:project",
            name: "project-agent",
            description: "",
            model: nil,
            source: .project,
            path: projectRoot.appendingPathComponent(".claude/agents/project-agent.md"),
            projectRoot: projectRoot,
            isEnabled: false
        )

        let content = InventorySectionsBuilder.buildContent(
            for: .agents,
            snapshot: InventorySnapshot(skills: [], mcpServers: [], agents: [globalAgent, projectAgent]),
            filterText: ""
        )

        #expect(content.sections.count == 2)
        #expect(content.sections[0].title == "All Projects")
        #expect(content.sections[1].title == "tools/monorepo")
    }
}
