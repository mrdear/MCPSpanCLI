import ArgumentParser
import Foundation

struct DiscoverCmd: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "discover",
        abstract: "List configured MCP servers or search by keyword."
    )

    @OptionGroup
    var globalOptions: GlobalOptions

    @Argument(help: "Optional server name keyword.")
    var keyword: String?

    func run() async throws {
        let configService = MCPConfigService()
        let config = try configService.loadConfigOrDefault(path: globalOptions.configPath)
        let allServers = config.servers.sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }

        if allServers.isEmpty {
            print("No servers found in \(configService.expand(path: globalOptions.configPath))")
            return
        }

        let filteredServers = filter(servers: allServers, keyword: keyword)

        guard !filteredServers.isEmpty else {
            print("No servers matched '\(keyword ?? "")'")
            return
        }

        for (index, entry) in filteredServers.enumerated() {
            print("\(index + 1). \(entry.key)")
            print("   \(transportSummary(for: entry.value))")
        }
    }

    private func filter(
        servers: [(key: String, value: MCPServerConfig)],
        keyword: String?
    ) -> [(key: String, value: MCPServerConfig)] {
        guard let keyword, !keyword.isEmpty else {
            return servers
        }

        return servers.filter { entry in
            entry.key.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func transportSummary(for server: MCPServerConfig) -> String {
        switch server.transport {
        case let .stdio(command, arguments, _, currentDirectoryPath):
            var parts = ["stdio", "command=\(command)"]

            if !arguments.isEmpty {
                parts.append("args=\(arguments.joined(separator: " "))")
            }

            if let currentDirectoryPath, !currentDirectoryPath.isEmpty {
                parts.append("cwd=\(currentDirectoryPath)")
            }

            return parts.joined(separator: " | ")

        case let .http(url, streaming):
            let type = server.type?.rawValue ?? "http"
            let streamingText = streaming.map { $0 ? "true" : "false" } ?? "default"
            return "\(type) | url=\(url.absoluteString) | streaming=\(streamingText)"
        }
    }
}
