import ArgumentParser
import Foundation
import MCP

struct CallCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "call",
        abstract: "Call a configured MCP server tool."
    )

    @OptionGroup
    var globalOptions: GlobalOptions

    @Option(name: .long, help: "Server name defined in the config file.")
    var server: String

    @Option(name: .long, help: "Tool name to call.")
    var tool: String

    @Option(name: .long, help: "Tool arguments as a JSON object string.")
    var args: String = "{}"

    func run() async throws {
        let configService = MCPConfigService()
        let config = try configService.loadConfig(path: globalOptions.configPath)

        guard let serverConfig = config.servers[server] else {
            throw ValidationError(
                "Server '\(server)' was not found in \(configService.expand(path: globalOptions.configPath))"
            )
        }

        let endpoint = serverConfig.endpoint(defaultHTTPStreaming: config.global.httpStreaming)
        let arguments = try parseArguments(args)
        let clientService = MCPClientService()
        let result = try await clientService.callTool(
            endpoint: endpoint,
            name: tool,
            arguments: arguments
        )

        try printResult(result, outputFormat: config.global.outputFormat)

        if result.isError == true {
            throw ExitCode.failure
        }
    }

    private func parseArguments(_ rawValue: String) throws -> [String: Value] {
        let data = Data(rawValue.utf8)
        let json = try JSONSerialization.jsonObject(with: data)

        guard let object = json as? [String: Any] else {
            throw ValidationError("The -args value must be a JSON object.")
        }

        return try object.mapValues { try convertToMCPValue($0) }
    }

    private func convertToMCPValue(_ value: Any) throws -> Value {
        switch value {
        case is NSNull:
            return .null
        case let bool as Bool:
            return .bool(bool)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return .bool(number.boolValue)
            }

            let doubleValue = number.doubleValue
            let intValue = number.intValue

            if Double(intValue) == doubleValue {
                return .int(intValue)
            }

            return .double(doubleValue)
        case let string as String:
            return .string(string)
        case let array as [Any]:
            return .array(try array.map(convertToMCPValue))
        case let dictionary as [String: Any]:
            return .object(try dictionary.mapValues(convertToMCPValue))
        default:
            throw ValidationError("Unsupported JSON value in -args.")
        }
    }

    private func printResult(_ result: CallTool.Result, outputFormat: OutputFormat) throws {
        switch outputFormat {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            print(String(decoding: data, as: UTF8.self))

        case .text:
            if let structuredContent = result.structuredContent {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(structuredContent)
                print(String(decoding: data, as: UTF8.self))
            }

            for item in result.content {
                switch item {
                case let .text(text, _, _):
                    print(text)
                case let .image(data, mimeType, _, _):
                    print("[image] mimeType=\(mimeType) bytes=\(data.count)")
                case let .audio(data, mimeType, _, _):
                    print("[audio] mimeType=\(mimeType) bytes=\(data.count)")
                case let .resource(resource, _, _):
                    print(String(describing: resource))
                case let .resourceLink(uri, name, title, description, mimeType, _):
                    var line = "[resource-link] \(name) -> \(uri)"

                    if let title {
                        line += " title=\(title)"
                    }

                    if let description {
                        line += " description=\(description)"
                    }

                    if let mimeType {
                        line += " mimeType=\(mimeType)"
                    }

                    print(line)
                }
            }
        }
    }
}
