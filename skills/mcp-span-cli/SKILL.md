---
name: "mcp-span-cli"
description: "Use the local MCPSpanCLI project to inspect configured MCP servers, call their tools, and generate SKILL.md content for those servers."
---

# MCPSpanCLI Skill

Use this skill when you want to turn a configured MCP server into a reusable `SKILL.md`, inspect the server's tools, or verify a real MCP tool call before generating documentation.

## When to use

- You need to generate a `SKILL.md` from an MCP server that already exists in the local config.
- You want to inspect a configured MCP server before writing a skill.
- You want to validate a real MCP tool call through the local CLI.

## Inputs

The tool reads config from `~/.config/mcp-span-cli/config.json` by default.

The config should define servers under either `servers` or `mcpServers`.

Each server must use one of these transports:

- `stdio`
- `http`
- `streamable_http`

## Workflow

1. Inspect the configured server list in `~/.config/mcp-span-cli/config.json`.
2. Run `list-tools` first when the server's available tools are unknown.
3. Run `call` if you need to validate a specific MCP tool or understand its output.
4. Run `gen-skill` to produce markdown and redirect it to the target file.

## Commands

List tools:

```bash
swift run MCPSpanCLI list-tools --server <SERVER_NAME>
```

Call a tool:

```bash
swift run MCPSpanCLI call --server <SERVER_NAME> --tool <TOOL_NAME> --args '<JSON_ARGS>'
```

Generate a full skill:

```bash
swift run MCPSpanCLI gen-skill --server <SERVER_NAME> > SKILL.md
```

Generate a filtered skill:

```bash
swift run MCPSpanCLI gen-skill --server <SERVER_NAME> --tool <TOOL_NAME> > SKILL.md
```

Generate a filtered skill with multiple tools:

```bash
swift run MCPSpanCLI gen-skill --server <SERVER_NAME> --tool <TOOL_A> --tool <TOOL_B> > SKILL.md
```

## Output expectations

`gen-skill` writes markdown to standard output. The markdown includes:

- skill frontmatter
- current server information
- selected tool sections
- one-line call examples
- input parameter descriptions

Required parameters are listed before optional parameters.

## Good practice

- Prefer `list-tools` before `gen-skill` when the server is new.
- Prefer validating at least one real `call` for unfamiliar servers before trusting the generated skill blindly.
- Use `--tool` to keep generated skills focused when the server exposes many tools.
