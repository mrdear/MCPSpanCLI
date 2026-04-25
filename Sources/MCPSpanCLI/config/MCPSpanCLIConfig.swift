import Foundation

struct MCPSpanCLIConfig: Codable, Sendable {
    var global: GlobalConfig
    var servers: [String: MCPServerConfig]

    init(
        global: GlobalConfig = GlobalConfig(),
        servers: [String: MCPServerConfig] = [:]
    ) {
        self.global = global
        self.servers = servers
    }

    private enum CodingKeys: String, CodingKey {
        case global
        case servers
        case mcpServers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        global = try container.decodeIfPresent(GlobalConfig.self, forKey: .global) ?? GlobalConfig()

        if let servers = try container.decodeIfPresent([String: MCPServerConfig].self, forKey: .servers)
        {
            self.servers = servers
        } else {
            self.servers =
                try container.decodeIfPresent([String: MCPServerConfig].self, forKey: .mcpServers)
                ?? [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(global, forKey: .global)
        try container.encode(servers, forKey: .servers)
    }
}

struct GlobalConfig: Codable, Sendable {
    var outputFormat: OutputFormat
    var httpStreaming: Bool

    init(
        outputFormat: OutputFormat = .text,
        httpStreaming: Bool = true
    ) {
        self.outputFormat = outputFormat
        self.httpStreaming = httpStreaming
    }
}

enum OutputFormat: String, Codable, Sendable {
    case text
    case json
}

struct MCPServerConfig: Codable, Sendable {
    var transport: MCPServerTransportConfig

    func endpoint(defaultHTTPStreaming: Bool) -> MCPClientEndpoint {
        switch transport {
        case let .stdio(command, arguments, environment, currentDirectoryPath):
            return .stdio(
                command: command,
                arguments: arguments,
                environment: environment,
                currentDirectoryPath: currentDirectoryPath
            )

        case let .http(url, streaming):
            return .http(
                url: url,
                streaming: streaming ?? defaultHTTPStreaming
            )
        }
    }
}

enum MCPServerTransportConfig: Codable, Sendable {
    case stdio(
        command: String,
        arguments: [String],
        environment: [String: String],
        currentDirectoryPath: String?
    )
    case http(url: URL, streaming: Bool?)

    private enum CodingKeys: String, CodingKey {
        case type
        case command
        case arguments
        case environment
        case currentDirectoryPath
        case url
        case streaming
    }

    private enum TransportType: String, Codable {
        case stdio
        case http
        case streamableHTTP = "streamable_http"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TransportType.self, forKey: .type)

        switch type {
        case .stdio:
            let command = try container.decode(String.self, forKey: .command)
            let arguments = try container.decodeIfPresent([String].self, forKey: .arguments) ?? []
            let environment =
                try container.decodeIfPresent([String: String].self, forKey: .environment) ?? [:]
            let currentDirectoryPath = try container.decodeIfPresent(
                String.self,
                forKey: .currentDirectoryPath
            )

            self = .stdio(
                command: command,
                arguments: arguments,
                environment: environment,
                currentDirectoryPath: currentDirectoryPath
            )

        case .http, .streamableHTTP:
            let url = try container.decode(URL.self, forKey: .url)
            let streaming = try container.decodeIfPresent(Bool.self, forKey: .streaming)
            self = .http(url: url, streaming: streaming)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .stdio(command, arguments, environment, currentDirectoryPath):
            try container.encode(TransportType.stdio, forKey: .type)
            try container.encode(command, forKey: .command)
            try container.encode(arguments, forKey: .arguments)
            try container.encode(environment, forKey: .environment)
            try container.encodeIfPresent(currentDirectoryPath, forKey: .currentDirectoryPath)

        case let .http(url, streaming):
            try container.encode(TransportType.http, forKey: .type)
            try container.encode(url, forKey: .url)
            try container.encodeIfPresent(streaming, forKey: .streaming)
        }
    }
}
