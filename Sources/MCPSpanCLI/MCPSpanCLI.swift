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

        Command guide:

          add
            Paste MCP server JSON from stdin and merge it into the config file.
            Supports mcpServers, servers, a plain server map, or a single named server.

            Examples:
              pbpaste | mcp-span-cli add
              mcp-span-cli add

          discover [keyword]
            List configured servers, optionally filtered by server name.

            Examples:
              mcp-span-cli discover
              mcp-span-cli discover fetch

          list-tools --server <name>
            List tools exposed by one configured MCP server.

            Example:
              mcp-span-cli list-tools --server fetch

          call --server <name> --tool <name> [--args <json>]
            Call one tool with a JSON object argument.

            Example:
              mcp-span-cli call --server fetch --tool fetch --args '<json>'

          gen-skill --server <name> [--tool <name> ...]
            Generate SKILL.md content for a configured server.

            Examples:
              mcp-span-cli gen-skill --server fetch
              mcp-span-cli gen-skill --server fetch --tool fetch

        Config notes:
          - Default config path: ~/.config/mcp-span-cli/config.json
          - New writes use mcpServers.
          - HTTP aliases: omitted type, http, streamable_http, streamable-http.
          - Legacy SSE uses type sse.
          - Stdio servers use command with optional args, env, and cwd.
        """,
        version: BuildInfo.version,
        subcommands: [
            AddCmd.self,
            DiscoverCmd.self,
            GenSkillCmd.self,
            ListToolsCmd.self,
            CallCmd.self
        ]
    )

}
