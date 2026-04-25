---
name: "mcp-span-cli"
description: "Use the released mcp-span-cli binary to inspect configured MCP servers, call their tools, and generate SKILL.md content for those servers."
---

# MCPSpanCLI Skill

Use this skill when you want to turn a configured MCP server into a reusable `SKILL.md`, inspect the server's tools, or verify a real MCP tool call before generating documentation.

## When to use

- You need to generate a `SKILL.md` from an MCP server that already exists in the local config.
- You want to inspect a configured MCP server before writing a skill.
- You want to validate a real MCP tool call through the installed CLI.

## Inputs

Install the CLI first:

```bash
curl -fsSL https://raw.githubusercontent.com/mrdear/MCPSpanCLI/main/scripts/install.sh | bash
```

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
mcp-span-cli list-tools --server <SERVER_NAME>
```

Call a tool:

```bash
mcp-span-cli call --server <SERVER_NAME> --tool <TOOL_NAME> --args '<JSON_ARGS>'
```

Generate a full skill:

```bash
mcp-span-cli gen-skill --server <SERVER_NAME> > SKILL.md
```

Generate a filtered skill:

```bash
mcp-span-cli gen-skill --server <SERVER_NAME> --tool <TOOL_NAME> > SKILL.md
```

Generate a filtered skill with multiple tools:

```bash
mcp-span-cli gen-skill --server <SERVER_NAME> --tool <TOOL_A> --tool <TOOL_B> > SKILL.md
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
