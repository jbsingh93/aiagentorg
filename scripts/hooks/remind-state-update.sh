#!/usr/bin/env bash
# remind-state-update.sh — Periodic reminder to update state and communicate
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then exit 0; fi

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
ACTIVITY_FILE="$ORG_DIR/agents/$AGENT/activity/$TODAY.md"

# Count write operations so far
WRITE_COUNT=0
if [[ -f "$ACTIVITY_FILE" ]]; then
  WRITE_COUNT=$(grep -c "|.*Write\|Edit" "$ACTIVITY_FILE" 2>/dev/null || echo "0")
fi

# Every 5th write, inject a reminder
if [[ "$WRITE_COUNT" -gt 0 ]] && (( WRITE_COUNT % 5 == 0 )); then
  # Check if current-state.md was updated in the last 2 minutes
  STATE_FILE="$ORG_DIR/agents/$AGENT/activity/current-state.md"
  STALE=false

  if [[ ! -f "$STATE_FILE" ]]; then
    STALE=true
  else
    if command -v stat &>/dev/null; then
      LAST_MOD=$(stat -c %Y "$STATE_FILE" 2>/dev/null || stat -f %m "$STATE_FILE" 2>/dev/null || echo "0")
      NOW=$(date +%s)
      DIFF=$((NOW - LAST_MOD))
      if [[ $DIFF -gt 120 ]]; then STALE=true; fi
    fi
  fi

  if [[ "$STALE" == "true" ]]; then
    # Output reminder as JSON with reason (shown to Claude as warning)
    echo '{"hookSpecificOutput":{"reason":"REMINDER: Update your current-state.md with current task, step, files in use, and next actions. If you made progress or decisions, report in the relevant thread in org/threads/."}}'
    exit 1  # Warn (non-blocking, message shown to agent)
  fi
fi

exit 0
