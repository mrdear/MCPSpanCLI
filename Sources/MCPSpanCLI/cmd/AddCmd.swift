import ArgumentParser
import Darwin
import Foundation

struct AddCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add MCP server config from pasted JSON."
    )

    @OptionGroup
    var globalOptions: GlobalOptions

    func run() async throws {
        if isInteractiveInput {
            print(
                """
                Paste MCP server JSON, then press Ctrl-D when finished.
                Accepted formats: full config with mcpServers/servers, a server map, or a single named server.

                """,
                terminator: ""
            )
        }

        let inputData = FileHandle.standardInput.readDataToEndOfFile()

        guard let jsonText = String(data: inputData, encoding: .utf8) else {
            throw ValidationError("Failed to read UTF-8 JSON from stdin.")
        }

        let configService = MCPConfigService()
        let currentConfig = try configService.loadConfigOrDefault(path: globalOptions.configPath)
        let result = try configService.mergeImportedServers(
            from: jsonText,
            into: currentConfig
        )

        try configService.saveConfig(result.config, path: globalOptions.configPath)

        print("Added servers: \(result.addedServerNames.joined(separator: ", "))")
        print("Config updated: \(configService.expand(path: globalOptions.configPath))")
    }

    private var isInteractiveInput: Bool {
        isatty(STDIN_FILENO) == 1
    }
}
