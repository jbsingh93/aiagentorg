#!/usr/bin/env bash
# memory-size-check.sh — Warn if MEMORY.md exceeds 200 lines after a write
# Fires on: PostToolUse (Write|Edit) to */MEMORY.md
# Exit codes: 0 = ok, 1 = warn (non-blocking)

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Only check writes to MEMORY.md files
if [[ "$TARGET" != *"MEMORY.md" ]]; then
  exit 0
fi

# Check if the file exists and count lines
if [[ -f "$TARGET" ]]; then
  LINE_COUNT=$(wc -l < "$TARGET")
  MAX_LINES=200

  if [[ "$LINE_COUNT" -gt "$MAX_LINES" ]]; then
    echo "{\"hookSpecificOutput\":{\"reason\":\"MEMORY SIZE WARNING: $TARGET has $LINE_COUNT lines (max: $MAX_LINES). Run /consolidate-memory to prune and archive old entries.\"}}" >&2
    exit 1
  fi
fi

exit 0
