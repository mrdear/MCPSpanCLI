#!/usr/bin/env bash
set -euo pipefail

dry_run=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      dry_run=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: $0 [--dry-run]" >&2
      exit 2
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
cd "$repo_root"

version_file="Sources/MCPSpanCLI/BuildInfo.swift"

if [[ ! -f "$version_file" ]]; then
  echo "Missing $version_file" >&2
  exit 1
fi

version="$(
  sed -nE 's/.*static let version = "([^"]+)".*/\1/p' "$version_file" | head -n 1
)"

if [[ -z "$version" ]]; then
  echo "Could not read version from $version_file" >&2
  exit 1
fi

tag="v$version"
current_branch="$(git branch --show-current)"

if [[ -z "$current_branch" ]]; then
  echo "Could not determine the current branch" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree is dirty. Commit or stash changes before releasing." >&2
  git status --short >&2
  exit 1
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Local tag already exists: $tag" >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "Remote tag already exists: $tag" >&2
  exit 1
fi

echo "Release version: $version"
echo "Release tag: $tag"
echo "Branch: $current_branch"

echo "Building..."
swift build

if [[ "$dry_run" == "1" ]]; then
  echo "Dry run complete. No tag was created or pushed."
  exit 0
fi

echo "Pushing branch..."
git push origin "$current_branch"

echo "Creating tag..."
git tag "$tag"

echo "Pushing tag..."
git push origin "$tag"

echo "Release started for $tag."
echo "Check progress with: gh run list --workflow Release --limit 3"
