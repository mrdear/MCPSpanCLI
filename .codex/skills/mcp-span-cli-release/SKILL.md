---
name: "mcp-span-cli-release"
description: "Release MCPSpanCLI by reading Sources/MCPSpanCLI/BuildInfo.swift, validating the matching v<version> tag, building, tagging, pushing, and checking the GitHub release workflow."
---

# MCPSpanCLI Release Skill

Use this skill when the user wants to release MCPSpanCLI, publish a new GitHub Release, or tag a version based on the project version.

## Release source of truth

`Sources/MCPSpanCLI/BuildInfo.swift` is the version source of truth.

Read it before publishing. The release tag must be:

```text
v<BuildInfo.version>
```

Example:

```swift
static let version = "0.1.4"
```

publishes tag `v0.1.4`.

## Workflow

1. Check the current version:

   ```bash
   sed -n '1,80p' Sources/MCPSpanCLI/BuildInfo.swift
   ```

2. Check release docs and installer assumptions when the release touches README, install instructions, archive names, or version text:

   ```bash
   sed -n '1,220p' .github/workflows/release.yml
   sed -n '1,220p' scripts/install.sh
   ```

3. Build before tagging:

   ```bash
   swift build
   ```

4. Run the bundled release script:

   ```bash
   skills/mcp-span-cli-release/scripts/release_from_build_info.sh --dry-run
   skills/mcp-span-cli-release/scripts/release_from_build_info.sh
   ```

5. After pushing the tag, check the release workflow:

   ```bash
   gh run list --workflow Release --limit 3
   ```

   If needed, inspect the newest run:

   ```bash
   gh run view <RUN_ID> --log-failed
   ```

## Rules

- Do not invent the version from the latest tag. Use `BuildInfo.swift`.
- Do not publish with a dirty working tree.
- Do not reuse an existing local or remote tag.
- Push the current branch before pushing the tag.
- The GitHub Actions workflow publishes the release archive after the tag is pushed.

