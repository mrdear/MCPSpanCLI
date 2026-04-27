# MCPSpanCLI

`MCPSpanCLI` is a small Swift command-line tool for turning MCP server capabilities into reusable skill documentation.

It does four things:

- add MCP server config into the local config file
- list the tools exposed by a configured MCP server
- call a tool on a configured MCP server
- generate `SKILL.md` content from a configured MCP server

The generated skill content is written to standard output so the caller can redirect it to any file.

## Install as a skill

This repository now exposes an installable skill at:

```bash
skills/mcp-span-cli/SKILL.md
```

Other users can install it with `npx skills`:

```bash
npx skills add https://github.com/mrdear/MCPSpanCLI --skill mcp-span-cli
```

The `skills` CLI discovers skills from standard locations such as the repository root and `skills/`, so `skills/mcp-span-cli/SKILL.md` follows that expected layout.

## Requirements

- macOS 14+
- Swift 6
- An MCP server reachable through stdio or streamable HTTP

## Install

Install the latest GitHub Release:

```bash
curl -fsSL https://raw.githubusercontent.com/mrdear/MCPSpanCLI/main/scripts/install.sh | bash
```

The installer downloads the correct macOS archive for your CPU and installs `mcp-span-cli` into `~/.local/bin`.

After installation, the normal usage style is:

```bash
mcp-span-cli --help
```

## Build

```bash
swift build
```

You can run the tool through SwiftPM while developing:

```bash
swift run MCPSpanCLI --help
```

Or run the built binary directly:

```bash
./.build/arm64-apple-macosx/debug/MCPSpanCLI --help
```

## Release

GitHub Actions builds a release archive for:

- macOS Apple Silicon

Push a tag such as `v0.1.3` to trigger the release workflow:

```bash
git tag v0.1.3
git push origin v0.1.3
```

The workflow uploads the compiled archives to the GitHub Release page for that tag.

## Config

By default the tool reads config from:

```bash
~/.config/mcp-span-cli/config.json
```

Example config:

```json
{
  "global": {
    "outputFormat": "text",
    "httpStreaming": true
  },
  "mcpServers": {
    "12306-mcp": {
      "transport": {
        "type": "streamable_http",
        "url": "https://mcp.api-inference.modelscope.net/442fe0e45a0148/mcp"
      }
    },
    "filesystem": {
      "transport": {
        "type": "stdio",
        "command": "npx",
        "arguments": [
          "-y",
          "@modelcontextprotocol/server-filesystem",
          "/tmp"
        ],
        "environment": {}
      }
    }
  }
}
```

`servers` and `mcpServers` are both accepted. For HTTP-based MCP servers, `type: "http"` and `type: "streamable_http"` are both supported.

## Commands

### Add config

Paste JSON into stdin and let the CLI merge it into `~/.config/mcp-span-cli/config.json`:

```bash
pbpaste | mcp-span-cli add
```

Or paste directly in the terminal:

```bash
mcp-span-cli add
```

Then paste JSON and finish with `Ctrl-D`.

Accepted input formats include:

- a full config object with `mcpServers`
- a full config object with `servers`
- a plain server map such as `{ "filesystem": { ... } }`

For stdio servers, both `arguments` and the more common `args` are accepted. If the config file does not exist yet, `add` creates it automatically.

### List tools

```bash
mcp-span-cli list-tools --server 12306-mcp
```

### Call a tool

```bash
mcp-span-cli call --server 12306-mcp --tool get-current-date --args '{}'
```

Example with arguments:

```bash
mcp-span-cli call --server 12306-mcp --tool get-tickets --args '{"date":"2026-04-26","fromStation":"北京","toStation":"上海","format":"text"}'
```

### Generate SKILL.md content

Generate the full skill:

```bash
mcp-span-cli gen-skill --server 12306-mcp > SKILL.md
```

Generate only selected tools:

```bash
mcp-span-cli gen-skill --server 12306-mcp --tool get-current-date --tool get-tickets > SKILL.md
```

## Generated output

`gen-skill` produces markdown with:

- skill header metadata
- current MCP server information
- one section per selected tool
- a single-line call example for each tool
- input parameter descriptions with required parameters first

## Notes

- The client layer is stateless by default. Each command connects to the target server, performs the query or call, then releases the connection.
- `gen-skill` does not write files directly. Redirect the output wherever you want.
- Some HTTP environments may print system cache warnings on macOS. Those warnings do not necessarily mean the MCP call failed.
