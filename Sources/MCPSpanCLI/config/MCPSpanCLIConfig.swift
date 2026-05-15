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
        try container.encode(servers, forKey: .mcpServers)
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

struct MCPServerConfig: Sendable {
    var type: MCPServerType?
    var command: String?
    var arguments: [String]
    var environment: [String: String]
    var currentDirectoryPath: String?
    var url: URL?
    var headers: [String: String]
    var streaming: Bool?

    init(
        type: MCPServerType? = nil,
        command: String? = nil,
        arguments: [String] = [],
        environment: [String: String] = [:],
        currentDirectoryPath: String? = nil,
        url: URL? = nil,
        headers: [String: String] = [:],
        streaming: Bool? = nil
    ) {
        self.type = type
        self.command = command
        self.arguments = arguments
        self.environment = environment
        self.currentDirectoryPath = currentDirectoryPath
        self.url = url
        self.headers = headers
        self.streaming = streaming
    }

    var transport: MCPServerTransportConfig {
        if let command {
            return .stdio(
                command: command,
                arguments: arguments,
                environment: environment,
                currentDirectoryPath: currentDirectoryPath
            )
        }

        return .http(url: url!, streaming: streaming, headers: headers)
    }

    func endpoint(defaultHTTPStreaming: Bool) -> MCPClientEndpoint {
        if let command {
            return .stdio(
                command: command,
                arguments: arguments,
                environment: environment,
                currentDirectoryPath: currentDirectoryPath
            )
        }

        if let url {
            if type == .sse {
                return .sse(url: url, headers: headers)
            }

            return .http(
                url: url,
                streaming: streaming ?? defaultHTTPStreaming,
                headers: headers
            )
        }

        preconditionFailure("MCPServerConfig must define command or url.")
    }
}

extension MCPServerConfig: Codable {
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
        case headers
        case streaming
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let transport = try container.decodeIfPresent(
            MCPServerTransportConfig.self,
            forKey: .transport
        ) {
            self = MCPServerConfig(transport: transport)
            return
        }

        type = try container.decodeIfPresent(MCPServerType.self, forKey: .type)
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
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
        streaming = try container.decodeIfPresent(Bool.self, forKey: .streaming)

        if command == nil, url == nil {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Server must define command for stdio or url for HTTP/SSE."
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let type {
            try container.encode(type, forKey: .type)
        } else if url != nil {
            try container.encode(MCPServerType.http, forKey: .type)
        }

        try container.encodeIfPresent(command, forKey: .command)

        if !arguments.isEmpty {
            try container.encode(arguments, forKey: .args)
        }

        if !environment.isEmpty {
            try container.encode(environment, forKey: .env)
        }

        try container.encodeIfPresent(currentDirectoryPath, forKey: .cwd)
        try container.encodeIfPresent(url?.absoluteString, forKey: .url)

        if !headers.isEmpty {
            try container.encode(headers, forKey: .headers)
        }

        try container.encodeIfPresent(streaming, forKey: .streaming)
    }

    private init(transport: MCPServerTransportConfig) {
        switch transport {
        case let .stdio(command, arguments, environment, currentDirectoryPath):
            self.init(
                type: .stdio,
                command: command,
                arguments: arguments,
                environment: environment,
                currentDirectoryPath: currentDirectoryPath
            )

        case let .http(url, streaming, headers):
            self.init(
                type: .http,
                url: url,
                headers: headers,
                streaming: streaming
            )
        }
    }
}

enum MCPServerType: String, Sendable {
    case stdio
    case http
    case sse
}

extension MCPServerType: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        switch rawValue {
        case "stdio":
            self = .stdio
        case "http", "streamable_http", "streamable-http":
            self = .http
        case "sse":
            self = .sse
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Unsupported MCP server type '\(rawValue)'. Expected stdio, http, sse, streamable_http, or streamable-http."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum MCPServerTransportConfig: Codable, Sendable {
    case stdio(
        command: String,
        arguments: [String],
        environment: [String: String],
        currentDirectoryPath: String?
    )
    case http(url: URL, streaming: Bool?, headers: [String: String])

    private enum CodingKeys: String, CodingKey {
        case type
        case command
        case arguments
        case args
        case environment
        case env
        case currentDirectoryPath
        case cwd
        case url
        case headers
        case streaming
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MCPServerType.self, forKey: .type)

        switch type {
        case .stdio:
            let command = try container.decode(String.self, forKey: .command)
            let decodedArguments = try container.decodeIfPresent([String].self, forKey: .arguments)
            let decodedArgs = try container.decodeIfPresent([String].self, forKey: .args)
            let arguments = decodedArguments ?? decodedArgs ?? []

            let decodedEnvironment = try container.decodeIfPresent(
                [String: String].self,
                forKey: .environment
            )
            let decodedEnv = try container.decodeIfPresent([String: String].self, forKey: .env)
            let environment = decodedEnvironment ?? decodedEnv ?? [:]

            let decodedCurrentDirectoryPath = try container.decodeIfPresent(
                String.self,
                forKey: .currentDirectoryPath
            )
            let decodedCWD = try container.decodeIfPresent(String.self, forKey: .cwd)
            let currentDirectoryPath = decodedCurrentDirectoryPath ?? decodedCWD

            self = .stdio(
                command: command,
                arguments: arguments,
                environment: environment,
                currentDirectoryPath: currentDirectoryPath
            )

        case .http, .sse:
            let url = try container.decode(URL.self, forKey: .url)
            let headers = try container.decodeIfPresent([String: String].self, forKey: .headers) ?? [:]
            let streaming = try container.decodeIfPresent(Bool.self, forKey: .streaming)
            self = .http(url: url, streaming: streaming, headers: headers)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .stdio(command, arguments, environment, currentDirectoryPath):
            try container.encode(MCPServerType.stdio, forKey: .type)
            try container.encode(command, forKey: .command)
            try container.encode(arguments, forKey: .arguments)
            try container.encode(environment, forKey: .environment)
            try container.encodeIfPresent(currentDirectoryPath, forKey: .currentDirectoryPath)

        case let .http(url, streaming, headers):
            try container.encode(MCPServerType.http, forKey: .type)
            try container.encode(url.absoluteString, forKey: .url)

            if !headers.isEmpty {
                try container.encode(headers, forKey: .headers)
            }

            try container.encodeIfPresent(streaming, forKey: .streaming)
        }
    }
}
