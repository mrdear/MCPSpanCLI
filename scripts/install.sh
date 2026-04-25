#!/usr/bin/env bash
set -euo pipefail

OWNER="mrdear"
REPO="MCPSpanCLI"
BINARY_NAME="mcp-span-cli"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

uname_s="$(uname -s)"
uname_m="$(uname -m)"

if [[ "$uname_s" != "Darwin" ]]; then
  echo "This installer currently supports macOS only." >&2
  exit 1
fi

case "$uname_m" in
  arm64)
    archive_name="mcp-span-cli-macos-arm64.zip"
    ;;
  x86_64)
    echo "This installer currently publishes Apple Silicon binaries only." >&2
    echo "Please build from source on Intel Macs." >&2
    exit 1
    ;;
  *)
    echo "Unsupported architecture: $uname_m" >&2
    exit 1
    ;;
esac

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

archive_path="$tmp_dir/$archive_name"
download_url="https://github.com/${OWNER}/${REPO}/releases/latest/download/${archive_name}"

echo "Downloading ${archive_name}..."
curl -fsSL "$download_url" -o "$archive_path"

echo "Installing ${BINARY_NAME} to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
unzip -q "$archive_path" -d "$tmp_dir"
cp "$tmp_dir/dist/${BINARY_NAME}" "$INSTALL_DIR/${BINARY_NAME}"
chmod +x "$INSTALL_DIR/${BINARY_NAME}"

echo "Installed to ${INSTALL_DIR}/${BINARY_NAME}"
echo "Make sure ${INSTALL_DIR} is in your PATH."
