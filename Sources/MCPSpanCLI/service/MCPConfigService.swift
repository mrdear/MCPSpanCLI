import ArgumentParser
import Foundation

struct MCPConfigService {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()

    func loadConfig(path: String) throws -> MCPSpanCLIConfig {
        let expandedPath = expand(path: path)
        let url = URL(fileURLWithPath: expandedPath)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError(
                "Config file not found at \(url.path)"
            )
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        do {
            return try decoder.decode(MCPSpanCLIConfig.self, from: data)
        } catch {
            throw ValidationError(
                "Failed to parse config file at \(url.path): \(error.localizedDescription)"
            )
        }
    }

    func loadConfigOrDefault(path: String) throws -> MCPSpanCLIConfig {
        let expandedPath = expand(path: path)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return MCPSpanCLIConfig()
        }

        return try loadConfig(path: path)
    }

    func saveConfig(_ config: MCPSpanCLIConfig, path: String) throws {
        let expandedPath = expand(path: path)
        let url = URL(fileURLWithPath: expandedPath)
        let directoryURL = url.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let data = try encoder.encode(config)
        var text = String(decoding: data, as: UTF8.self)
        text.append("\n")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    func mergeImportedServers(
        from jsonText: String,
        into config: MCPSpanCLIConfig
    ) throws -> (config: MCPSpanCLIConfig, addedServerNames: [String], updatedServerNames: [String]) {
        let importedServers = try parseImportedServers(jsonText: jsonText)
        let updatedServerNames = importedServers.keys
            .filter { config.servers[$0] != nil }
            .sorted()
        let addedServerNames = importedServers.keys
            .filter { config.servers[$0] == nil }
            .sorted()

        var updatedConfig = config

        for serverName in importedServers.keys.sorted() {
            updatedConfig.servers[serverName] = importedServers[serverName]
        }

        return (updatedConfig, addedServerNames, updatedServerNames)
    }

    func expand(path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func parseImportedServers(jsonText: String) throws -> [String: MCPServerConfig] {
        let trimmedText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw ValidationError(
                "No JSON was provided. Paste the MCP server JSON and finish with Ctrl-D."
            )
        }

        let data = Data(trimmedText.utf8)
        let decoder = JSONDecoder()
        let rawJSON: Any

        do {
            rawJSON = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ValidationError(
                "Invalid JSON syntax: \(error.localizedDescription)"
            )
        }

        guard let object = rawJSON as? [String: Any] else {
            throw ValidationError(
                "Invalid add input: top-level JSON must be an object, for example { \"mcpServers\": { \"name\": { ... } } }."
            )
        }

        let wrapperKey = ["mcpServers", "servers"].first { object[$0] != nil }

        if let wrapperKey {
            let payload: ImportedConfigPayload

            do {
                payload = try decoder.decode(ImportedConfigPayload.self, from: data)
            } catch {
                throw ValidationError(
                    "Invalid '\(wrapperKey)' config: \(formatDecodingError(error))"
                )
            }

            if wrapperKey == "mcpServers", let servers = payload.mcpServers {
                guard !servers.isEmpty else {
                    throw ValidationError("'mcpServers' must contain at least one server.")
                }

                return try normalizeImportedServers(servers)
            }

            if wrapperKey == "servers", let servers = payload.servers {
                guard !servers.isEmpty else {
                    throw ValidationError("'servers' must contain at least one server.")
                }

                return try normalizeImportedServers(servers)
            }

            throw ValidationError(
                "'\(wrapperKey)' must be an object whose keys are server names."
            )
        }

        if isSingleNamedServerObject(object) {
            do {
                let namedServer = try decoder.decode(ImportedNamedServer.self, from: data)
                return [
                    namedServer.name: namedServer.server
                ]
            } catch {
                throw ValidationError(
                    "Invalid named server config: \(formatDecodingError(error))"
                )
            }
        }

        do {
            let servers = try decoder.decode([String: MCPServerConfig].self, from: data)
            guard !servers.isEmpty else {
                throw ValidationError("Server map must contain at least one server.")
            }

            return try normalizeImportedServers(servers)
        } catch let error as ValidationError {
            throw error
        } catch {
            throw ValidationError(
                "Invalid server map config: \(formatDecodingError(error))"
            )
        }
    }

    private func normalizeImportedServers(_ servers: [String: MCPServerConfig]) throws
        -> [String: MCPServerConfig]
    {
        var normalizedServers: [String: MCPServerConfig] = [:]

        for (serverName, serverConfig) in servers {
            normalizedServers[serverName] = serverConfig
        }

        return normalizedServers
    }

    private func isSingleNamedServerObject(_ object: [String: Any]) -> Bool {
        guard object["name"] is String else {
            return false
        }

        let serverConfigKeys: Set<String> = [
            "transport",
            "type",
            "command",
            "arguments",
            "args",
            "environment",
            "env",
            "currentDirectoryPath",
            "cwd",
            "url",
            "streaming"
        ]

        return object.keys.contains { serverConfigKeys.contains($0) }
    }

    private func formatDecodingError(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return error.localizedDescription
        }

        switch decodingError {
        case let .keyNotFound(key, context):
            return "missing required key '\(pathDescription(context.codingPath + [key]))'."
        case let .typeMismatch(type, context):
            return "expected \(type) at '\(pathDescription(context.codingPath))'. \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "missing value for \(type) at '\(pathDescription(context.codingPath))'."
        case let .dataCorrupted(context):
            return "invalid value at '\(pathDescription(context.codingPath))'. \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }

    private func pathDescription(_ path: [CodingKey]) -> String {
        guard !path.isEmpty else {
            return "$"
        }

        return path.map(\.stringValue).joined(separator: ".")
    }
}

private struct ImportedConfigPayload: Decodable {
    let servers: [String: MCPServerConfig]?
    let mcpServers: [String: MCPServerConfig]?
}

private struct ImportedNamedServer: Decodable {
    let name: String
    let server: MCPServerConfig

    private enum CodingKeys: String, CodingKey {
        case name
        case transport
        case type
        case command
        case arguments
        case args
        case environment
        case env
        case currentDirectoryPath
        case cwd
        case url
        case streaming
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        server = try MCPServerConfig(from: decoder)
    }
}
