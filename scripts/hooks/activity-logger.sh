#!/usr/bin/env bash
# activity-logger.sh — Log every file operation to agent's activity stream + audit log
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%H:%M:%S)
FULL_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

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

exit 0
