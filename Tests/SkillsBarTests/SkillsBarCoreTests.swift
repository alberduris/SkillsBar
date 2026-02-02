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
        #expect(agent.pluginsCachePath == home.appendingPathComponent(".test/plugins/cache"))
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
        #expect(agent.pluginsCachePath == nil)
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

// MARK: - MCPServer Tests

@Suite("MCPServer Tests")
struct MCPServerTests {
    @Test("MCPServers are comparable by source then name")
    func mcpServerComparable() {
        let globalServer = MCPServer(
            id: "mcp:global:notion",
            name: "notion",
            transport: .http,
            url: "https://mcp.notion.com/mcp",
            source: .global
        )

        let projectServer = MCPServer(
            id: "mcp:project:myapp:vercel",
            name: "vercel",
            transport: .http,
            url: "https://mcp.vercel.com",
            source: .project,
            projectName: "myapp"
        )

        // Project servers should come before global servers
        #expect(projectServer < globalServer)
    }

    @Test("MCPServer equality is based on ID")
    func mcpServerEquality() {
        let server1 = MCPServer(
            id: "mcp:global:test",
            name: "test",
            transport: .http,
            source: .global
        )

        let server2 = MCPServer(
            id: "mcp:global:test",
            name: "different-name",
            transport: .stdio,
            source: .project
        )

        #expect(server1 == server2)
    }

    @Test("MCPTransport has correct descriptions")
    func transportDescription() {
        #expect(MCPTransport.http.description == "HTTP")
        #expect(MCPTransport.sse.description == "SSE")
        #expect(MCPTransport.stdio.description == "stdio")
    }
}

// MARK: - MCPSource Tests

@Suite("MCPSource Tests")
struct MCPSourceTests {
    @Test("MCPSource has correct display names")
    func displayNames() {
        #expect(MCPSource.global.displayName == "Global")
        #expect(MCPSource.project.displayName == "Project")
        #expect(MCPSource.builtIn.displayName == "Built-in")
    }

    @Test("MCPSource sort order prioritizes project, then global, then builtIn")
    func sortOrder() {
        #expect(MCPSource.project.sortOrder < MCPSource.global.sortOrder)
        #expect(MCPSource.global.sortOrder < MCPSource.builtIn.sortOrder)
    }

    @Test("MCPSource has correct SF symbols")
    func sfSymbols() {
        #expect(MCPSource.global.sfSymbolName == "globe")
        #expect(MCPSource.project.sfSymbolName == "folder")
        #expect(MCPSource.builtIn.sfSymbolName == "shippingbox")
    }
}

// MARK: - MCPConfigParser Tests

@Suite("MCPConfigParser Tests")
struct MCPConfigParserTests {
    @Test("Parse global servers from JSON")
    func parseGlobalServers() throws {
        let json = """
        {
            "mcpServers": {
                "context7": {
                    "type": "http",
                    "url": "https://mcp.context7.com/mcp"
                },
                "myserver": {
                    "command": "node",
                    "args": ["server.js"],
                    "env": {
                        "API_KEY": "secret123"
                    }
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_global_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: configURL) }

        let servers = MCPConfigParser.parseGlobalServers(from: configURL)

        #expect(servers.count == 2)

        let httpServer = servers.first { $0.name == "context7" }
        #expect(httpServer != nil)
        #expect(httpServer?.transport == .http)
        #expect(httpServer?.url == "https://mcp.context7.com/mcp")
        #expect(httpServer?.source == .global)
        #expect(httpServer?.isEnabled == true)

        let stdioServer = servers.first { $0.name == "myserver" }
        #expect(stdioServer != nil)
        #expect(stdioServer?.transport == .stdio)
        #expect(stdioServer?.command == "node")
        #expect(stdioServer?.args == ["server.js"])
        #expect(stdioServer?.envKeys == ["API_KEY"])
    }

    @Test("Parse project servers with disabled list")
    func parseProjectServers() throws {
        let json = """
        {
            "projects": {
                "/tmp/testproject": {
                    "mcpServers": {
                        "linear": {
                            "type": "sse",
                            "url": "https://mcp.linear.app/sse"
                        },
                        "notion": {
                            "type": "http",
                            "url": "https://mcp.notion.com/mcp"
                        }
                    },
                    "disabledMcpServers": ["notion"]
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_project_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: configURL) }

        let projectPath = URL(fileURLWithPath: "/tmp/testproject")
        let servers = MCPConfigParser.parseProjectServers(from: configURL, projectPaths: [projectPath])

        #expect(servers.count == 2)

        let linearServer = servers.first { $0.name == "linear" }
        #expect(linearServer != nil)
        #expect(linearServer?.transport == .sse)
        #expect(linearServer?.isEnabled == true)
        #expect(linearServer?.projectName == "testproject")

        let notionServer = servers.first { $0.name == "notion" }
        #expect(notionServer != nil)
        #expect(notionServer?.isEnabled == false)
    }

    @Test("Parse .mcp.json format")
    func parseMcpJsonFile() throws {
        let json = """
        {
            "mcpServers": {
                "context7": {
                    "type": "http",
                    "url": "https://mcp.context7.com/mcp"
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcptest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let mcpJsonURL = tempDir.appendingPathComponent(".mcp.json")
        try json.data(using: .utf8)!.write(to: mcpJsonURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let servers = MCPConfigParser.parseMcpJsonFile(at: tempDir, disabledNames: [])

        #expect(servers.count == 1)
        #expect(servers.first?.name == "context7")
        #expect(servers.first?.transport == .http)
        #expect(servers.first?.isEnabled == true)
    }

    @Test("Parse .mcp.json with disabled names")
    func parseMcpJsonFileDisabled() throws {
        let json = """
        {
            "mcpServers": {
                "context7": {
                    "type": "http",
                    "url": "https://mcp.context7.com/mcp"
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("mcptest_disabled_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let mcpJsonURL = tempDir.appendingPathComponent(".mcp.json")
        try json.data(using: .utf8)!.write(to: mcpJsonURL)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let servers = MCPConfigParser.parseMcpJsonFile(at: tempDir, disabledNames: ["context7"])

        #expect(servers.count == 1)
        #expect(servers.first?.isEnabled == false)
    }

    @Test("Handle missing JSON gracefully")
    func handleMissingJSON() {
        let nonExistentURL = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).json")
        let servers = MCPConfigParser.parseGlobalServers(from: nonExistentURL)
        #expect(servers.isEmpty)
    }

    @Test("Handle malformed JSON gracefully")
    func handleMalformedJSON() throws {
        let badJSON = "{ this is not valid json }"

        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_bad_\(UUID().uuidString).json")
        try badJSON.data(using: .utf8)!.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: configURL) }

        let servers = MCPConfigParser.parseGlobalServers(from: configURL)
        #expect(servers.isEmpty)
    }

    @Test("Env and header keys extracted without values")
    func envAndHeaderKeysExtracted() throws {
        let json = """
        {
            "mcpServers": {
                "secure-server": {
                    "type": "http",
                    "url": "https://example.com/mcp",
                    "env": {
                        "API_KEY": "secret-value-123",
                        "DB_PASSWORD": "another-secret"
                    },
                    "headers": {
                        "Authorization": "Bearer token123",
                        "X-Custom": "value"
                    }
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_env_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: configURL) }

        let servers = MCPConfigParser.parseGlobalServers(from: configURL)
        #expect(servers.count == 1)

        let server = servers.first!
        #expect(server.envKeys.contains("API_KEY"))
        #expect(server.envKeys.contains("DB_PASSWORD"))
        #expect(server.headerKeys.contains("Authorization"))
        #expect(server.headerKeys.contains("X-Custom"))
    }

    @Test("Transport inference: command implies stdio")
    func transportInferStdio() throws {
        let json = """
        {
            "mcpServers": {
                "myserver": {
                    "command": "uvx",
                    "args": ["mcp-server-thing"]
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_infer_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: configURL) }

        let servers = MCPConfigParser.parseGlobalServers(from: configURL)
        #expect(servers.count == 1)
        #expect(servers.first?.transport == .stdio)
    }

    @Test("Transport inference: url implies http")
    func transportInferHTTP() throws {
        let json = """
        {
            "mcpServers": {
                "myserver": {
                    "url": "https://example.com/mcp"
                }
            }
        }
        """

        let tempDir = FileManager.default.temporaryDirectory
        let configURL = tempDir.appendingPathComponent("test_infer_http_\(UUID().uuidString).json")
        try json.data(using: .utf8)!.write(to: configURL)
        defer { try? FileManager.default.removeItem(at: configURL) }

        let servers = MCPConfigParser.parseGlobalServers(from: configURL)
        #expect(servers.count == 1)
        #expect(servers.first?.transport == .http)
    }

    @Test("Claude in Chrome enabled flag parsed correctly")
    func chromeEnabledFlag() throws {
        let jsonEnabled = """
        {
            "claudeInChromeDefaultEnabled": true,
            "mcpServers": {}
        }
        """

        let jsonDisabled = """
        {
            "claudeInChromeDefaultEnabled": false,
            "mcpServers": {}
        }
        """

        let jsonMissing = """
        {
            "mcpServers": {}
        }
        """

        let tempDir = FileManager.default.temporaryDirectory

        let enabledURL = tempDir.appendingPathComponent("test_chrome_en_\(UUID().uuidString).json")
        try jsonEnabled.data(using: .utf8)!.write(to: enabledURL)
        defer { try? FileManager.default.removeItem(at: enabledURL) }
        #expect(MCPConfigParser.isClaudeInChromeEnabled(from: enabledURL) == true)

        let disabledURL = tempDir.appendingPathComponent("test_chrome_dis_\(UUID().uuidString).json")
        try jsonDisabled.data(using: .utf8)!.write(to: disabledURL)
        defer { try? FileManager.default.removeItem(at: disabledURL) }
        #expect(MCPConfigParser.isClaudeInChromeEnabled(from: disabledURL) == false)

        let missingURL = tempDir.appendingPathComponent("test_chrome_miss_\(UUID().uuidString).json")
        try jsonMissing.data(using: .utf8)!.write(to: missingURL)
        defer { try? FileManager.default.removeItem(at: missingURL) }
        #expect(MCPConfigParser.isClaudeInChromeEnabled(from: missingURL) == false)
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
