// The Swift Programming Language
// https://docs.swift.org/swift-book
import ArgumentParser

@main
struct MCPSpanCLI: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "mcp-span-cli",
        abstract: "Convert MCP server capabilities into mountable agent skills.",
        discussion: """
        mcp-span-cli discovers tools from MCP servers, generates skill bundles,
        and provides a runtime bridge for agents to invoke those skills.
        """,
        version: BuildInfo.version,
        subcommands: [
            GenSkillCmd.self,
            ListToolsCmd.self,
            CallCmd.self
        ]
    )

}
