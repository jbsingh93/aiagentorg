#!/usr/bin/env bash
# activity-logger.sh — Log every file operation to agent's activity stream + audit log
# Also writes to a LIVE FEED file that the GUI WebSocket watches for real-time display.
INPUT=$(cat)
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%H:%M:%S)
FULL_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

# Determine agent: from env var, OR auto-detect from the session's agent name
AGENT="${ORGAGENT_CURRENT_AGENT:-}"
if [[ -z "$AGENT" ]]; then
  # Try to detect from Claude Code's session context (agent name in tool input paths)
  TARGET_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)
  DETECTED=$(echo "$TARGET_PATH" | grep -o 'org/agents/[^/]*' | head -1 | sed 's|org/agents/||')
  if [[ -n "$DETECTED" && -d "$ORG_DIR/agents/$DETECTED" ]]; then
    AGENT="$DETECTED"
  else
    AGENT="board"
  fi
fi

# Determine target and action based on tool type
case "$TOOL" in
  Read)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    ACTION="read"
    SUMMARY="Read file"
    ;;
  Write)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    ACTION="create"
    # Extract a summary from the content (first 80 chars of first non-frontmatter line)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.content // ""' | grep -v '^---' | grep -v '^$' | head -1 | cut -c1-80)
    [[ -z "$SUMMARY" ]] && SUMMARY="File written"
    ;;
  Edit)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    ACTION="update"
    SUMMARY="File edited"
    ;;
  Glob)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.pattern // "unknown"')
    ACTION="search"
    SUMMARY="File pattern search"
    ;;
  Grep)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.pattern // "unknown"')
    ACTION="search"
    SUMMARY="Content search"
    ;;
  Bash)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.command // "unknown"' | cut -c1-80)
    ACTION="exec"
    SUMMARY="Command executed"
    ;;
  *)
    TARGET="—"
    ACTION="$TOOL"
    SUMMARY="Tool used"
    ;;
esac

# === Write to agent's activity stream ===
if [[ "$AGENT" != "board" ]]; then
  ACTIVITY_DIR="$ORG_DIR/agents/$AGENT/activity"
  ACTIVITY_FILE="$ACTIVITY_DIR/$TODAY.md"

  # Create activity directory and file header if needed
  mkdir -p "$ACTIVITY_DIR"
  if [[ ! -f "$ACTIVITY_FILE" ]]; then
    echo "# Activity Stream — $AGENT — $TODAY" > "$ACTIVITY_FILE"
    echo "" >> "$ACTIVITY_FILE"
    echo "| Time | Tool | Action | Target | Summary |" >> "$ACTIVITY_FILE"
    echo "|------|------|--------|--------|---------|" >> "$ACTIVITY_FILE"
  fi

  # Append activity entry
  echo "| $TIMESTAMP | $TOOL | $ACTION | $TARGET | $SUMMARY |" >> "$ACTIVITY_FILE"
fi

# === Write to org-wide audit log ===
AUDIT_FILE="$ORG_DIR/board/audit-log.md"
if [[ -f "$AUDIT_FILE" ]]; then
  echo "| $FULL_TIMESTAMP | $AGENT | $ACTION | $TARGET | $SUMMARY |" >> "$AUDIT_FILE"
fi

# === Write to live feed file (watched by GUI WebSocket) ===
# This is a single shared file that the chokidar watcher detects instantly.
# The GUI reads the last line and displays it in the Live Feed tab.
LIVE_FEED="$ORG_DIR/.live-feed.log"
mkdir -p "$(dirname "$LIVE_FEED")"
echo "| $TIMESTAMP | $AGENT | $TOOL | $ACTION | $TARGET | $SUMMARY |" >> "$LIVE_FEED"

# Keep live feed file from growing too large (last 200 lines)
if [[ -f "$LIVE_FEED" ]] && [[ $(wc -l < "$LIVE_FEED") -gt 300 ]]; then
  tail -200 "$LIVE_FEED" > "$LIVE_FEED.tmp" && mv "$LIVE_FEED.tmp" "$LIVE_FEED"
fi

exit 0
