import ArgumentParser
import Foundation

struct ListToolsCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-tools",
        abstract: "List tools from a configured MCP server."
    )

    @OptionGroup
    var globalOptions: GlobalOptions

    @Option(name: .long, help: "Server name defined in the config file.")
    var server: String

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
        let tools = try await clientService.listTools(endpoint: endpoint)

        if config.global.outputFormat == .json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(tools)
            print(String(decoding: data, as: UTF8.self))
            return
        }

        for tool in tools {
            print(tool.name)
            if let description = tool.description, !description.isEmpty {
                print(description)
            }
            print(String(describing: tool.inputSchema))
            print("")
        }
    }
}
