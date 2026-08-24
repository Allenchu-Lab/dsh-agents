#!/bin/bash
# Install the pinned Harness runtime and recreate all registered agents.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"
RUNTIME_ROOT="$HOME/.local/share/deepseek-harness-runtime"

command -v node >/dev/null 2>&1 || { echo 'Node.js is required.' >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo 'npm is required.' >&2; exit 1; }
[[ "$(uname -s)" == "Darwin" ]] || { echo 'This installer currently supports macOS only.' >&2; exit 1; }

echo "Installing DeepSeek Harness $VERSION..."
npm install --prefix "$RUNTIME_ROOT" "@deepseek-ai/dsh@$VERSION"

chmod 711 "$SCRIPT_DIR/agents.sh" "$SCRIPT_DIR/start-agents.sh"
"$SCRIPT_DIR/agents.sh" stop all
"$SCRIPT_DIR/agents.sh" install all
"$SCRIPT_DIR/agents.sh" start all
"$SCRIPT_DIR/agents.sh" status all

echo 'Installation complete. Configure model credentials separately in each Agent.'
