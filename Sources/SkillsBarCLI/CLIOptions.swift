import Commander
import Foundation
import SkillsBarCore

// MARK: - List Command Options

final class ListOptions: CommanderParsable {
    @Flag(names: [.short("v"), .long("verbose")], help: "Enable verbose logging")
    var verbose: Bool = false

    @Flag(name: .long("json"), help: "Output as JSON")
    var jsonOutput: Bool = false

    @Flag(name: .long("json-only"), help: "Output JSON only (suppress other output)")
    var jsonOnly: Bool = false

    @Option(name: .long("agent"), help: "Filter by agent ID (e.g., \"claude\")")
    var agent: String?

    @Flag(name: .long("global"), help: "Include only global skills")
    var global: Bool = false

    @Flag(name: .long("plugins"), help: "Include only plugin skills")
    var plugins: Bool = false

    @Option(name: .long("project"), help: "Include project skills from path")
    var project: String?

    @Option(name: .long("format"), help: "Output format: text | json")
    var format: OutputFormat?

    init() {}

    func apply(_ values: ParsedValues) {
        verbose = values.flags.contains("verbose")
        jsonOutput = values.flags.contains("jsonOutput") || values.flags.contains("json")
        jsonOnly = values.flags.contains("jsonOnly")
        agent = values.options["agent"]?.last
        global = values.flags.contains("global")
        plugins = values.flags.contains("plugins")
        project = values.options["project"]?.last

        if let formatStr = values.options["format"]?.last {
            format = OutputFormat(argument: formatStr)
        }
    }
}

// MARK: - Agents Command Options

final class AgentsOptions: CommanderParsable {
    @Flag(names: [.short("v"), .long("verbose")], help: "Enable verbose logging")
    var verbose: Bool = false

    @Flag(name: .long("json"), help: "Output as JSON")
    var jsonOutput: Bool = false

    init() {}
}

// MARK: - Output Format

enum OutputFormat: String, Sendable, ExpressibleFromArgument {
    case text
    case json

    init?(argument: String) {
        switch argument.lowercased() {
        case "text": self = .text
        case "json": self = .json
        default: return nil
        }
    }
}
