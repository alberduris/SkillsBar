import Commander
import Foundation

struct CLIOutputPreferences: Sendable {
    let jsonOutput: Bool
    let jsonOnly: Bool
    let pretty: Bool

    static func from(values: ParsedValues) -> CLIOutputPreferences {
        let jsonOnly = values.flags.contains("jsonOnly")
        let jsonOutput = values.flags.contains("jsonOutput") || values.flags.contains("json") || jsonOnly
        let pretty = values.flags.contains("pretty")
        return CLIOutputPreferences(jsonOutput: jsonOutput, jsonOnly: jsonOnly, pretty: pretty)
    }

    static func from(argv: [String]) -> CLIOutputPreferences {
        var jsonOnly = false
        var jsonOutput = false
        var pretty = false

        for arg in argv {
            switch arg {
            case "--json-only":
                jsonOnly = true
                jsonOutput = true
            case "--json":
                jsonOutput = true
            case "--pretty":
                pretty = true
            default:
                break
            }
        }

        return CLIOutputPreferences(jsonOutput: jsonOutput, jsonOnly: jsonOnly, pretty: pretty)
    }
}
