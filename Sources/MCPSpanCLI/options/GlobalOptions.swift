import ArgumentParser
import Foundation

struct GlobalOptions: ParsableArguments {
    static let defaultConfigPath =
        FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/mcp-span-cli/config.json")
        .path

    @Option(
        name: [.customLong("config"), .customShort("c")],
        help: "Path to the mcp-span-cli configuration file."
    )
    var configPath: String = GlobalOptions.defaultConfigPath

    @Flag(
        name: .long,
        help: "Print verbose logs."
    )
    var verbose: Bool = false

    @Flag(
        name: .long,
        help: "Suppress non-essential output."
    )
    var quiet: Bool = false

}
