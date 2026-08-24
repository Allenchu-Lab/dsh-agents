#!/bin/bash
# Compatibility shortcut. The main manager owns all start behavior.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/agents.sh" start "${1:-all}"
