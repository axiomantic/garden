#!/usr/bin/env bash
# scripts/launch_tmux_swarm.sh
# Provisions a dedicated tmux session for a Garden worker swarm, registers identities
# on the Rhizo Redis bus, arms listeners, and opens a visible terminal viewer (Ghostty/Terminal.app).

set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --session-name <name>    tmux session name (default: garden-<dirname>)
  --project-dir <path>     Target project working directory (default: current directory)
  --swarm-file <path>      Path to garden-swarm.json manifest
  --terminal-app <app>     Terminal viewer app: Ghostty | Terminal | iTerm | none (default: auto)
  --force                  Kill existing tmux session if running
  --help                   Show this help message
EOF
  exit 0
}

SESSION_NAME=""
PROJECT_DIR="$(pwd)"
SWARM_FILE=""
TERMINAL_APP="auto"
FORCE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-name)
      SESSION_NAME="$2"
      shift 2
      ;;
    --project-dir)
      PROJECT_DIR="$(cd "$2" && pwd)"
      shift 2
      ;;
    --swarm-file)
      SWARM_FILE="$2"
      shift 2
      ;;
    --terminal-app)
      TERMINAL_APP="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

# Prerequisite Checks
if ! command -v tmux >/dev/null 2>&1; then
  echo "Error: tmux is required but not found in PATH." >&2
  echo "Install via Homebrew: brew install tmux" >&2
  exit 1
fi

if ! command -v rhizo >/dev/null 2>&1 && ! command -v locu >/dev/null 2>&1 && ! command -v locutus >/dev/null 2>&1; then
  echo "Error: rhizo (or locu) is required but not found in PATH." >&2
  echo "Install via npm: npm install -g @axiomantic/rhizo" >&2
  exit 1
fi

RHIZO_BIN="$(command -v rhizo || command -v locu || command -v locutus)"

if [[ -z "$SESSION_NAME" ]]; then
  PROJECT_BASE="$(basename "$PROJECT_DIR" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '_')"
  SESSION_NAME="garden-${PROJECT_BASE}"
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  if [[ $FORCE -eq 1 ]]; then
    echo "[garden] Killing existing tmux session: $SESSION_NAME"
    tmux kill-session -t "$SESSION_NAME"
  else
    echo "Error: tmux session '$SESSION_NAME' already exists. Use --force to recreate." >&2
    exit 1
  fi
fi

# Parse swarm workers from JSON manifest or default trio
declare -a WORKER_NAMES=()
declare -a WORKER_TAGS=()
declare -a WORKER_COMMANDS=()

if [[ -z "$SWARM_FILE" ]]; then
  if [[ -f "$PROJECT_DIR/garden-swarm.json" ]]; then
    SWARM_FILE="$PROJECT_DIR/garden-swarm.json"
  elif [[ -f "$PROJECT_DIR/agora-swarm.json" ]]; then
    SWARM_FILE="$PROJECT_DIR/agora-swarm.json"
  fi
fi

if [[ -n "$SWARM_FILE" && -f "$SWARM_FILE" ]]; then
  if ! command -v jq >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 or jq is required to parse $SWARM_FILE" >&2
    exit 1
  fi

  # Parse JSON using python3 into tab-separated lines: name <tab> tags <tab> command
  PARSED_LINES=$(python3 -c "
import json, sys
with open('$SWARM_FILE', 'r') as f:
    data = json.load(f)
workers = data.get('workers', [])
for w in workers:
    name = w.get('name', 'worker')
    tags = ','.join(w.get('tags', []))
    cmd = w.get('startup_command', '')
    print(f'{name}\t{tags}\t{cmd}')
")

  while IFS=$'\t' read -r wname wtags wcmd; do
    [[ -z "$wname" ]] && continue
    WORKER_NAMES+=("$wname")
    WORKER_TAGS+=("$wtags")
    WORKER_COMMANDS+=("$wcmd")
  done <<< "$PARSED_LINES"
fi

# Fallback default trio if no manifest was provided
if [[ ${#WORKER_NAMES[@]} -eq 0 ]]; then
  WORKER_NAMES=("architect" "auditor" "implementer")
  WORKER_TAGS=("systems,architecture" "qa,audit,review" "dev,devex,build")
  WORKER_COMMANDS=("" "" "")
fi

echo "[garden] Provisioning tmux session: $SESSION_NAME for project: $PROJECT_DIR"

# 1. Create first worker window (index 0)
FIRST_NAME="${WORKER_NAMES[0]}"
FIRST_TAGS="${WORKER_TAGS[0]}"
FIRST_CMD="${WORKER_COMMANDS[0]}"

tmux new-session -d -s "$SESSION_NAME" -n "$FIRST_NAME" -c "$PROJECT_DIR"
tmux send-keys -t "$SESSION_NAME:0" "cd $(printf %q "$PROJECT_DIR")" C-m
tmux send-keys -t "$SESSION_NAME:0" "export RHIZO_AGENT_NAME=$(printf %q "$FIRST_NAME") LOCUTUS_AGENT_NAME=$(printf %q "$FIRST_NAME")" C-m
tmux send-keys -t "$SESSION_NAME:0" "$RHIZO_BIN open $(printf %q "$FIRST_NAME") $(printf %q "$FIRST_TAGS")" C-m

if [[ -n "$FIRST_CMD" ]]; then
  tmux send-keys -t "$SESSION_NAME:0" "$FIRST_CMD" C-m
else
  tmux send-keys -t "$SESSION_NAME:0" "$RHIZO_BIN listen $(printf %q "$FIRST_NAME")" C-m
fi

# 2. Create subsequent worker windows
for (( i=1; i<${#WORKER_NAMES[@]}; i++ )); do
  WNAME="${WORKER_NAMES[$i]}"
  WTAGS="${WORKER_TAGS[$i]}"
  WCMD="${WORKER_COMMANDS[$i]}"

  tmux new-window -t "$SESSION_NAME" -n "$WNAME" -c "$PROJECT_DIR"
  tmux send-keys -t "$SESSION_NAME:$i" "cd $(printf %q "$PROJECT_DIR")" C-m
  tmux send-keys -t "$SESSION_NAME:$i" "export RHIZO_AGENT_NAME=$(printf %q "$WNAME") LOCUTUS_AGENT_NAME=$(printf %q "$WNAME")" C-m
  tmux send-keys -t "$SESSION_NAME:$i" "$RHIZO_BIN open $(printf %q "$WNAME") $(printf %q "$WTAGS")" C-m

  if [[ -n "$WCMD" ]]; then
    tmux send-keys -t "$SESSION_NAME:$i" "$WCMD" C-m
  else
    tmux send-keys -t "$SESSION_NAME:$i" "$RHIZO_BIN listen $(printf %q "$WNAME")" C-m
  fi
done

# Select window 0 initially
tmux select-window -t "$SESSION_NAME:0"

echo "[garden] Spawned ${#WORKER_NAMES[@]} worker windows in tmux session '$SESSION_NAME'."

# 3. Launch OS-level Terminal Viewer
if [[ "$TERMINAL_APP" == "auto" ]]; then
  if [[ -d "/Applications/Ghostty.app" ]]; then
    TERMINAL_APP="Ghostty"
  elif [[ -d "/Applications/iTerm.app" ]]; then
    TERMINAL_APP="iTerm"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    TERMINAL_APP="Terminal"
  else
    TERMINAL_APP="none"
  fi
fi

if [[ "$TERMINAL_APP" != "none" && "$(uname -s)" == "Darwin" ]]; then
  echo "[garden] Launching viewer in $TERMINAL_APP..."
  case "$TERMINAL_APP" in
    Ghostty|ghostty)
      # Launch Ghostty with attach command
      open -a Ghostty --args -e tmux attach-session -t "$SESSION_NAME" || true
      ;;
    iTerm|iterm)
      osascript -e "
        tell application \"iTerm\"
          activate
          set newWindow to (create window with default profile)
          tell current session of newWindow
            write text \"tmux attach-session -t $SESSION_NAME\"
          end tell
        end tell
      " >/dev/null 2>&1 || true
      ;;
    Terminal|terminal)
      osascript -e "
        tell application \"Terminal\"
          activate
          do script \"tmux attach-session -t $SESSION_NAME\"
        end tell
      " >/dev/null 2>&1 || true
      ;;
    *)
      echo "[garden] Unknown terminal app '$TERMINAL_APP'; skipping auto-launch." >&2
      ;;
  esac
fi

# Output JSON summary for caller agents / orchestrator
cat <<EOF
{
  "status": "ready",
  "session_name": "$SESSION_NAME",
  "project_dir": "$PROJECT_DIR",
  "terminal_app": "$TERMINAL_APP",
  "workers": [
$(for (( i=0; i<${#WORKER_NAMES[@]}; i++ )); do
    echo "    {\"window\": $i, \"name\": \"${WORKER_NAMES[$i]}\", \"tags\": \"${WORKER_TAGS[$i]}\"}$(if [[ $i -lt $((${#WORKER_NAMES[@]} - 1)) ]]; then echo ","; fi)"
  done)
  ]
}
EOF
