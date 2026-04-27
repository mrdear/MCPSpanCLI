import ArgumentParser
import Foundation

struct MCPConfigService {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
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
    ) throws -> (config: MCPSpanCLIConfig, addedServerNames: [String]) {
        let importedServers = try parseImportedServers(jsonText: jsonText)
        let duplicatedServerNames = importedServers.keys
            .filter { config.servers[$0] != nil }
            .sorted()

        guard duplicatedServerNames.isEmpty else {
            throw ValidationError(
                "Server already exists in config: \(duplicatedServerNames.joined(separator: ", "))"
            )
        }

        var updatedConfig = config

        for serverName in importedServers.keys.sorted() {
            updatedConfig.servers[serverName] = importedServers[serverName]
        }

        return (updatedConfig, importedServers.keys.sorted())
    }

    func expand(path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func parseImportedServers(jsonText: String) throws -> [String: MCPServerConfig] {
        let trimmedText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw ValidationError(
                "No JSON was provided on stdin. Paste the MCP config and finish with Ctrl-D."
            )
        }

        let data = Data(trimmedText.utf8)
        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(ImportedConfigPayload.self, from: data) {
            if let servers = payload.servers, !servers.isEmpty {
                return try normalizeImportedServers(servers)
            }

            if let servers = payload.mcpServers, !servers.isEmpty {
                return try normalizeImportedServers(servers)
            }
        }

        if let servers = try? decoder.decode([String: ImportedServerConfig].self, from: data),
            !servers.isEmpty
        {
            return try normalizeImportedServers(servers)
        }

        if let namedServer = try? decoder.decode(ImportedNamedServer.self, from: data) {
            return [
                namedServer.name: try namedServer.server.toMCPServerConfig()
            ]
        }

        throw ValidationError(
            """
            Unsupported JSON format. Expected one of:
            1. { "mcpServers": { "name": { ... } } }
            2. { "servers": { "name": { ... } } }
            3. { "name": { ... } }
            """
        )
    }

    private func normalizeImportedServers(_ servers: [String: ImportedServerConfig]) throws
        -> [String: MCPServerConfig]
    {
        var normalizedServers: [String: MCPServerConfig] = [:]

        for (serverName, serverConfig) in servers {
            normalizedServers[serverName] = try serverConfig.toMCPServerConfig()
        }

        return normalizedServers
    }
}

private struct ImportedConfigPayload: Decodable {
    let servers: [String: ImportedServerConfig]?
    let mcpServers: [String: ImportedServerConfig]?
}

private struct ImportedNamedServer: Decodable {
    let name: String
    let server: ImportedServerConfig

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
        server = try ImportedServerConfig(from: decoder)
    }
}

private struct ImportedServerConfig: Decodable {
    let transport: MCPServerTransportConfig?
    let type: String?
    let command: String?
    let arguments: [String]
    let environment: [String: String]
    let currentDirectoryPath: String?
    let url: URL?
    let streaming: Bool?

    private enum CodingKeys: String, CodingKey {
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
        transport = try container.decodeIfPresent(MCPServerTransportConfig.self, forKey: .transport)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        let decodedArguments = try container.decodeIfPresent([String].self, forKey: .arguments)
        let decodedArgs = try container.decodeIfPresent([String].self, forKey: .args)
        arguments = decodedArguments ?? decodedArgs ?? []

        let decodedEnvironment = try container.decodeIfPresent(
            [String: String].self,
            forKey: .environment
        )
        let decodedEnv = try container.decodeIfPresent([String: String].self, forKey: .env)
        environment = decodedEnvironment ?? decodedEnv ?? [:]

        let decodedCurrentDirectoryPath = try container.decodeIfPresent(
            String.self,
            forKey: .currentDirectoryPath
        )
        let decodedCWD = try container.decodeIfPresent(String.self, forKey: .cwd)
        currentDirectoryPath = decodedCurrentDirectoryPath ?? decodedCWD
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        streaming = try container.decodeIfPresent(Bool.self, forKey: .streaming)
    }

    func toMCPServerConfig() throws -> MCPServerConfig {
        if let transport {
            return MCPServerConfig(transport: transport)
        }

        if let command {
            return MCPServerConfig(
                transport: .stdio(
                    command: command,
                    arguments: arguments,
                    environment: environment,
                    currentDirectoryPath: currentDirectoryPath
                )
            )
        }

        if let url {
            return MCPServerConfig(
                transport: .http(
                    url: url,
                    streaming: streaming
                )
            )
        }

        throw ValidationError(
            """
            Each imported server must define either:
            - transport
            - command for stdio
            - url for HTTP
            """
        )
    }
}
