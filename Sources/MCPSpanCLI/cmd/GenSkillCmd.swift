import ArgumentParser
import Foundation
import MCP

struct GenSkillCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gen-skill",
        abstract: "Generate SKILL.md content from a configured MCP server."
    )

    @OptionGroup
    var globalOptions: GlobalOptions

    @Option(name: .long, help: "Server name defined in the config file.")
    var server: String

    @Option(name: .long, parsing: .upToNextOption, help: "Only include the specified tool names.")
    var tool: [String] = []

    func run() async throws {
        let configService = MCPConfigService()
        let config = try configService.loadConfig(path: globalOptions.configPath)

        guard let serverConfig = config.servers[server] else {
            throw ValidationError(
                "Server '\(server)' was not found in \(configService.expand(path: globalOptions.configPath))"
            )
        }

        let endpoint = serverConfig.endpoint(defaultHTTPStreaming: config.global.httpStreaming)
        let clientService = MCPClientService()
        let snapshot = try await clientService.fetchServerSnapshot(endpoint: endpoint)
        let markdown = renderSkillMarkdown(
            serverKey: server,
            serverConfig: serverConfig,
            snapshot: snapshot
        )

        print(markdown)
    }

    private func renderSkillMarkdown(
        serverKey: String,
        serverConfig: MCPServerConfig,
        snapshot: MCPServerSnapshot
    ) -> String {
        let serverInfo = snapshot.initializeResult.serverInfo
        let title = serverInfo.title ?? serverInfo.name
        let description =
            serverInfo.description
            ?? snapshot.initializeResult.instructions
            ?? "Use the \(title) MCP server through mcp-span-cli."

        var lines: [String] = []
        lines.append("---")
        lines.append("name: \(yamlString(serverKey))")
        lines.append("description: \(yamlString(description))")
        lines.append("---")
        lines.append("")
        lines.append("# \(title)")
        lines.append("")
        lines.append(description)
        lines.append("")
        lines.append("## Current Server")
        lines.append("")
        lines.append("- Config key: `\(serverKey)`")
        lines.append("- Server name: `\(serverInfo.name)`")
        lines.append("- Title: \(serverInfo.title.map { "`\($0)`" } ?? "N/A")")
        lines.append("- Version: `\(serverInfo.version)`")
        lines.append("- Protocol version: `\(snapshot.initializeResult.protocolVersion)`")
        lines.append("- Description: \(serverInfo.description ?? "N/A")")
        lines.append("- Website: \(serverInfo.websiteUrl ?? "N/A")")

        if let instructions = snapshot.initializeResult.instructions, !instructions.isEmpty {
            lines.append("")
            lines.append("## Server Instructions")
            lines.append("")
            lines.append(instructions)
        }

        lines.append("")
        lines.append("## Tools")

        let selectedTools = filterTools(snapshot.tools)

        if selectedTools.isEmpty {
            lines.append("")
            lines.append("No tools matched the requested filter.")
            return lines.joined(separator: "\n")
        }

        for tool in selectedTools {
            lines.append("")
            lines.append("### `\(tool.name)`")
            lines.append("")
            lines.append(tool.description ?? "No description provided.")
            lines.append("")
            lines.append("Call example:")
            lines.append("")
            lines.append("```bash")
            lines.append(exampleCommand(serverKey: serverKey, tool: tool))
            lines.append("```")
            lines.append("")
            lines.append("Input parameters:")
            lines.append("")

            let parameterLines = renderInputParameters(tool: tool)
            if parameterLines.isEmpty {
                lines.append("- None")
            } else {
                lines.append(contentsOf: parameterLines)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func renderInputParameters(tool: Tool) -> [String] {
        guard let schemaObject = tool.inputSchema.objectValue else {
            return ["- Schema: `\(tool.inputSchema.description)`"]
        }

        let properties = schemaObject["properties"]?.objectValue ?? [:]
        let required = Set(schemaObject["required"]?.arrayValue?.compactMap(\.stringValue) ?? [])

        if properties.isEmpty {
            return []
        }

        return properties.keys.sorted(by: parameterComparator(required: required)).map { key in
            let schema = properties[key] ?? .null
            let typeName = schemaTypeName(schema)
            let requirement = required.contains(key) ? "required" : "optional"
            let description = schemaDescription(schema) ?? "No description provided."
            let defaultValue = schema.objectValue?["default"].map(renderValueInline)
            let enumValues = schema.objectValue?["enum"]?.arrayValue?.map(renderValueInline)

            var line = "- `\(key)` (\(typeName), \(requirement)): \(description)"

            if let defaultValue {
                line += " Default: `\(defaultValue)`."
            }

            if let enumValues, !enumValues.isEmpty {
                line += " Allowed: `\(enumValues.joined(separator: "`, `"))`."
            }

            return line
        }
    }

    private func filterTools(_ tools: [Tool]) -> [Tool] {
        if tool.isEmpty {
            return tools
        }

        let selectedNames = Set(tool)
        return tools.filter { selectedNames.contains($0.name) }
    }

    private func parameterComparator(required: Set<String>) -> (String, String) -> Bool {
        { left, right in
            let leftRequired = required.contains(left)
            let rightRequired = required.contains(right)

            if leftRequired != rightRequired {
                return leftRequired && !rightRequired
            }

            return left < right
        }
    }

    private func exampleCommand(serverKey: String, tool: Tool) -> String {
        let argsPlaceholder = hasInputParameters(tool: tool) ? "<JSON_ARGS>" : "{}"
        return
            "mcp-span-cli call --server \(serverKey) --tool \(tool.name) --args '\(argsPlaceholder)'"
    }

    private func hasInputParameters(tool: Tool) -> Bool {
        guard let schemaObject = tool.inputSchema.objectValue else {
            return false
        }

        let properties = schemaObject["properties"]?.objectValue ?? [:]
        return !properties.isEmpty
    }

    private func schemaTypeName(_ schema: Value) -> String {
        guard let object = schema.objectValue else {
            return "unknown"
        }

        if let type = object["type"]?.stringValue {
            return type
        }

        if object["enum"] != nil {
            return "enum"
        }

        return "unknown"
    }

    private func schemaDescription(_ schema: Value) -> String? {
        schema.objectValue?["description"]?.stringValue
    }

    private func renderValueInline(_ value: Value) -> String {
        switch value {
        case .null:
            return "null"
        case .bool(let value):
            return value ? "true" : "false"
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .string(let value):
            return value
        case .data:
            return "<data>"
        case .array, .object:
            guard
                let data = try? JSONEncoder().encode(value),
                let json = String(data: data, encoding: .utf8)
            else {
                return value.description
            }

            return json
        }
    }

    private func yamlString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
