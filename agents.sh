#!/bin/bash
# Manage isolated DeepSeek Harness web agents.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGISTRY="$SCRIPT_DIR/agents.tsv"
RUNTIME_ROOT="$HOME/.local/share/deepseek-harness-runtime"
NODE_BIN="${NODE_BIN:-$(command -v node 2>/dev/null || true)}"
DSH_BIN="$RUNTIME_ROOT/node_modules/@deepseek-ai/dsh/lib/bin.js"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs"
DOMAIN="gui/$(id -u)"

require_runtime() {
  if [[ ! -x "$NODE_BIN" || ! -f "$DSH_BIN" ]]; then
    echo "Harness stable runtime is missing: $DSH_BIN" >&2
    exit 1
  fi
}

lookup() {
  local wanted="$1"
  awk -F '\t' -v wanted="$wanted" '$1 == wanted { print; found=1 } END { if (!found) exit 1 }' "$REGISTRY"
}

each_target() {
  local target="$1"
  if [[ "$target" == "all" ]]; then
    grep -v '^[[:space:]]*#' "$REGISTRY" | sed '/^[[:space:]]*$/d'
  else
    lookup "$target"
  fi
}

plist_path() {
  printf '%s/com.allenchu.dsh-%s.plist' "$LAUNCH_DIR" "$1"
}

home_for() {
  printf '%s/.dsh-%s' "$HOME" "$1"
}

write_profile() {
  local slug="$1" home="$2"
  local profile="$home/profiles/$slug"
  mkdir -p "$profile"
  printf '%s\n' '[]' > "$profile/cordis.yml"
  printf '%s\n' '[]' > "$profile/cordis.patch.yml"
  printf '%s\n' 'packages:' '  - .' > "$profile/pnpm-workspace.yaml"
  printf '%s\n' \
    '{' \
    "  \"name\": \"dsh-profile-$slug\"," \
    '  "private": true,' \
    '  "dependencies": {},' \
    '  "dsh": {' \
    '    "profile": {' \
    '      "bundles": [' \
    '        "@deepseek-ai/dsh-base",' \
    '        "@deepseek-ai/dsh-web-app"' \
    '      ]' \
    '    }' \
    '  }' \
    '}' > "$profile/package.json"
}

write_plist() {
  local slug="$1" port="$2" home="$3" label="com.allenchu.dsh-$1"
  local plist
  plist="$(plist_path "$slug")"
  {
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
    printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    printf '%s\n' '<plist version="1.0"><dict>'
    printf '  <key>Label</key><string>%s</string>\n' "$label"
    printf '  <key>ProgramArguments</key><array><string>%s</string><string>%s</string><string>--profile</string><string>%s</string><string>--port</string><string>%s</string></array>\n' "$NODE_BIN" "$DSH_BIN" "$slug" "$port"
    printf '  <key>WorkingDirectory</key><string>%s</string>\n' "$HOME"
    printf '  <key>EnvironmentVariables</key><dict><key>HOME</key><string>%s</string><key>DSH_HOME</key><string>%s</string><key>PATH</key><string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin</string></dict>\n' "$HOME" "$home"
    printf '  <key>StandardOutPath</key><string>%s/dsh-%s.log</string>\n' "$LOG_DIR" "$slug"
    printf '  <key>StandardErrorPath</key><string>%s/dsh-%s.err.log</string>\n' "$LOG_DIR" "$slug"
    printf '%s\n' '  <key>RunAtLoad</key><true/><key>KeepAlive</key><true/>'
    printf '%s\n' '</dict></plist>'
  } > "$plist"
  chmod 600 "$plist"
  plutil -lint "$plist" >/dev/null
}

start_one() {
  local slug="$1" label="com.allenchu.dsh-$1" plist
  plist="$(plist_path "$slug")"
  if launchctl print "$DOMAIN/$label" >/dev/null 2>&1; then
    launchctl kickstart -k "$DOMAIN/$label"
  else
    launchctl bootstrap "$DOMAIN" "$plist"
  fi
  echo "Started $slug"
}

stop_one() {
  local slug="$1" label="com.allenchu.dsh-$1"
  if launchctl print "$DOMAIN/$label" >/dev/null 2>&1; then
    launchctl bootout "$DOMAIN/$label"
    echo "Stopped $slug"
  else
    echo "$slug is not running"
  fi
}

status_one() {
  local slug="$1" port="$2" name="$3" label="com.allenchu.dsh-$1" home
  local state="stopped" http="000"
  home="$(home_for "$slug")"
  launchctl print "$DOMAIN/$label" >/dev/null 2>&1 && state="loaded"
  http="$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "http://127.0.0.1:$port/" || true)"
  printf '%-18s port=%-5s service=%-7s http=%-3s home=%s\n' "$name" "$port" "$state" "$http" "$home"
}

create_agent() {
  local slug="${1:-}" port="${2:-}" name="${3:-}"
  [[ "$slug" =~ ^[a-z][a-z0-9-]*$ ]] || { echo 'Slug must use lowercase letters, numbers, and hyphens.' >&2; exit 1; }
  [[ "$port" =~ ^[0-9]+$ ]] || { echo 'Port must be numeric.' >&2; exit 1; }
  [[ -n "$name" ]] || { echo 'Display name is required.' >&2; exit 1; }
  if lookup "$slug" >/dev/null 2>&1; then echo "Agent already exists: $slug" >&2; exit 1; fi
  if awk -F '\t' -v port="$port" '$2 == port { found=1 } END { exit !found }' "$REGISTRY"; then echo "Port already registered: $port" >&2; exit 1; fi
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then echo "Port is already in use: $port" >&2; exit 1; fi

  local home
  home="$(home_for "$slug")"
  write_profile "$slug" "$home"
  write_plist "$slug" "$port" "$home"
  printf '%s\t%s\t%s\n' "$slug" "$port" "$name" >> "$REGISTRY"
  start_one "$slug"
  echo "Open http://127.0.0.1:$port/"
}

install_one() {
  local slug="$1" port="$2" name="$3" home
  home="$(home_for "$slug")"
  write_profile "$slug" "$home"
  write_plist "$slug" "$port" "$home"
  echo "Installed $name ($slug)"
}

require_runtime
COMMAND="${1:-status}"
TARGET="${2:-all}"

case "$COMMAND" in
  create)
    create_agent "${2:-}" "${3:-}" "${4:-}"
    ;;
  install)
    while IFS=$'\t' read -r slug port name; do install_one "$slug" "$port" "$name"; done < <(each_target "$TARGET")
    ;;
  list|status)
    while IFS=$'\t' read -r slug port name; do status_one "$slug" "$port" "$name"; done < <(each_target "$TARGET")
    ;;
  start)
    while IFS=$'\t' read -r slug port name; do start_one "$slug"; done < <(each_target "$TARGET")
    ;;
  stop)
    while IFS=$'\t' read -r slug port name; do stop_one "$slug"; done < <(each_target "$TARGET")
    ;;
  restart)
    while IFS=$'\t' read -r slug port name; do start_one "$slug"; done < <(each_target "$TARGET")
    ;;
  *)
    echo "Usage: $0 status [slug|all] | install|start|stop|restart [slug|all] | create <slug> <port> <display-name>" >&2
    exit 1
    ;;
esac
