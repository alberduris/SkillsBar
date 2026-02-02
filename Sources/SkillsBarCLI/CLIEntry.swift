import Commander
import Foundation
import SkillsBarCore
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

@main
enum SkillsBarCLI {
    static func main() async {
        let rawArgv = Array(CommandLine.arguments.dropFirst())
        let argv = effectiveArgv(rawArgv)
        let outputPreferences = CLIOutputPreferences.from(argv: argv)

        // Fast path: global help/version
        if argv.contains("-h") || argv.contains("--help") {
            printHelp()
        }
        if argv.contains("-V") || argv.contains("--version") {
            printVersion()
        }

        let program = Program(descriptors: commandDescriptors())

        do {
            let invocation = try program.resolve(argv: argv)
            bootstrapLogging(values: invocation.parsedValues)

            switch invocation.path {
            case ["list"]:
                await runList(invocation.parsedValues)
            case ["agents"]:
                runAgents(invocation.parsedValues)
            default:
                exit(code: .failure, message: "Unknown command", output: outputPreferences)
            }
        } catch let error as CommanderProgramError {
            exit(code: .failure, message: error.description, output: outputPreferences)
        } catch {
            exit(code: .failure, message: error.localizedDescription, output: outputPreferences)
        }
    }

    private static func commandDescriptors() -> [CommandDescriptor] {
        let listSignature = CommandSignature.describe(ListOptions())
        let agentsSignature = CommandSignature.describe(AgentsOptions())

        return [
            CommandDescriptor(
                name: "list",
                abstract: "List discovered skills",
                discussion: nil,
                signature: listSignature),
            CommandDescriptor(
                name: "agents",
                abstract: "List supported agents",
                discussion: nil,
                signature: agentsSignature),
        ]
    }

    // MARK: - Commands

    private static func runList(_ values: ParsedValues) async {
        let options = ListOptions()
        options.apply(values)

        let outputPrefs = CLIOutputPreferences.from(values: values)
        let isJSON = outputPrefs.jsonOutput || outputPrefs.jsonOnly

        // Determine enabled agents
        let agents: [Agent]
        if let agentID = options.agent {
            if let agent = AgentRegistry.agent(withID: agentID) {
                agents = [agent]
            } else {
                exit(code: .failure, message: "Unknown agent: \(agentID)", output: outputPrefs)
            }
        } else {
            agents = AgentRegistry.supported
        }

        // Build discovery options
        var discoveryOptions = SkillsDiscovery.Options()
        // If --global or --plugins specified, use those; otherwise include all
        let hasFilter = options.global || options.plugins || options.project != nil
        discoveryOptions.includeGlobal = hasFilter ? options.global : true
        discoveryOptions.includePlugins = hasFilter ? options.plugins : true
        discoveryOptions.includeProject = options.project != nil
        if let projectPath = options.project {
            discoveryOptions.projectPaths = [URL(fileURLWithPath: projectPath)]
        }

        // Discover skills
        let discovery = SkillsDiscovery(enabledAgents: agents)
        let skills = await discovery.discoverAll(options: discoveryOptions)

        if isJSON {
            outputJSON(skills: skills)
        } else {
            outputText(skills: skills)
        }
    }

    private static func runAgents(_ values: ParsedValues) {
        let outputPrefs = CLIOutputPreferences.from(values: values)
        let isJSON = outputPrefs.jsonOutput || outputPrefs.jsonOnly

        if isJSON {
            let payload = AgentRegistry.all.map { agent in
                [
                    "id": agent.id,
                    "displayName": agent.displayName,
                    "tagline": agent.tagline,
                    "configDir": agent.configDirName,
                    "supportsPlugins": agent.supportsPlugins ? "true" : "false",
                    "status": agent.status.rawValue,
                    "websiteURL": agent.websiteURL ?? "",
                ]
            }
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        } else {
            // Active agents
            print("Supported Agents:")
            print()
            for agent in AgentRegistry.supported {
                print("  ✓ \(agent.displayName) (\(agent.id))")
                if !agent.tagline.isEmpty {
                    print("    \(agent.tagline)")
                }
                print("    Config: \(agent.configDirName)/")
                print("    Plugins: \(agent.supportsPlugins ? "yes" : "no")")
                print()
            }

            // Coming soon
            if !AgentRegistry.planned.isEmpty {
                print("Coming Soon:")
                print()
                for agent in AgentRegistry.planned {
                    print("  ○ \(agent.displayName) (\(agent.id))")
                    if !agent.tagline.isEmpty {
                        print("    \(agent.tagline)")
                    }
                }
                print()
            }
        }
    }

    // MARK: - Output

    private static func outputJSON(skills: [Skill]) {
        let payload = skills.map { skill -> [String: Any] in
            var dict: [String: Any] = [
                "id": skill.id,
                "name": skill.name,
                "description": skill.description,
                "agent": skill.agent.id,
                "source": skill.source.rawValue,
                "path": skill.path.path,
                "userInvocable": skill.isUserInvocable,
                "isEnabled": skill.isEnabled,
            ]
            if let pluginName = skill.pluginName {
                dict["pluginName"] = pluginName
            }
            if let marketplaceName = skill.marketplaceName {
                dict["marketplaceName"] = marketplaceName
            }
            if let marketplaceRepo = skill.marketplaceRepo {
                dict["marketplaceRepo"] = marketplaceRepo
            }
            return dict
        }

        if let data = try? JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted),
           let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    private static func outputText(skills: [Skill]) {
        if skills.isEmpty {
            print("No skills found.")
            return
        }

        // Group by source
        let bySource = Dictionary(grouping: skills, by: \.source)

        for source in SkillSource.allCases {
            guard let sourceSkills = bySource[source], !sourceSkills.isEmpty else { continue }

            print("\(source.displayName) Skills (\(sourceSkills.count)):")
            print(String(repeating: "-", count: 50))

            for skill in sourceSkills {
                let status = skill.isEnabled ? "✓" : "○"
                var label = skill.name
                // Prefer repo (user/repo) over internal marketplace name
                if let repo = skill.marketplaceRepo {
                    label += " @\(repo)"
                } else if let marketplace = skill.marketplaceName {
                    label += " @\(shortenMarketplace(marketplace))"
                }
                print("  \(status) \(label)")
                if !skill.description.isEmpty {
                    let truncated = skill.description.prefix(55)
                    print("    \(truncated)\(skill.description.count > 55 ? "..." : "")")
                }
            }
            print()
        }

        let enabledCount = skills.filter(\.isEnabled).count
        print("Total: \(skills.count) skills (\(enabledCount) enabled)")
    }

    private static func shortenMarketplace(_ name: String) -> String {
        let shortenings: [String: String] = [
            "claude-plugins-official": "official",
            "claude-code-plugins": "cc-plugins",
        ]
        return shortenings[name] ?? name.replacingOccurrences(of: "-marketplace", with: "")
    }

    // MARK: - Helpers

    private static func bootstrapLogging(values: ParsedValues) {
        let isJSON = values.flags.contains("jsonOutput") || values.flags.contains("jsonOnly")
        let verbose = values.flags.contains("verbose")
        let level: SkillsBarLog.Level = verbose ? .debug : .error
        SkillsBarLog.bootstrapIfNeeded(.init(destination: .stderr, level: level, json: isJSON))
    }

    static func effectiveArgv(_ argv: [String]) -> [String] {
        guard let first = argv.first else { return ["list"] }
        if first.hasPrefix("-") { return ["list"] + argv }
        return argv
    }

    private static func printHelp() -> Never {
        print("""
        skillsbar - Visualize skills for AI coding agents

        USAGE:
          skillsbar [command] [options]

        COMMANDS:
          list      List discovered skills (default)
          agents    List supported agents

        OPTIONS:
          --agent <id>     Filter by agent (e.g., "claude")
          --global         Include global skills only
          --plugins        Include plugin skills only
          --project <path> Include project skills from path
          --json           Output as JSON
          -v, --verbose    Verbose output
          -h, --help       Show help
          -V, --version    Show version

        EXAMPLES:
          skillsbar list
          skillsbar list --agent claude
          skillsbar list --project /path/to/project
          skillsbar list --json
          skillsbar agents
        """)
        Darwin.exit(0)
    }

    private static func printVersion() -> Never {
        print("skillsbar 1.0.0")
        Darwin.exit(0)
    }

    private static func exit(code: CLIExitCode, message: String, output: CLIOutputPreferences) -> Never {
        if output.jsonOutput || output.jsonOnly {
            let error = ["error": message]
            if let data = try? JSONSerialization.data(withJSONObject: error, options: .prettyPrinted),
               let json = String(data: data, encoding: .utf8) {
                fputs(json + "\n", stderr)
            }
        } else {
            fputs("Error: \(message)\n", stderr)
        }
        Darwin.exit(code.rawValue)
    }
}
