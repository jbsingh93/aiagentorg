#!/usr/bin/env bash
# require-state-and-communication.sh — Block session end if state is stale
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then exit 0; fi

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
STATE_FILE="$ORG_DIR/agents/$AGENT/activity/current-state.md"
ACTIVITY_FILE="$ORG_DIR/agents/$AGENT/activity/$TODAY.md"

ERRORS=""

# Check 1: current-state.md exists and contains today's date
if [[ ! -f "$STATE_FILE" ]]; then
  ERRORS="${ERRORS}\n- current-state.md does NOT exist. Create it at: $STATE_FILE"
elif ! grep -q "$TODAY" "$STATE_FILE" 2>/dev/null; then
  ERRORS="${ERRORS}\n- current-state.md is STALE (no entry for $TODAY). Update it."
fi

# Check 2: If agent wrote to tasks/, it must also have written to threads/
if [[ -f "$ACTIVITY_FILE" ]]; then
  TASK_WRITES=$(grep -c "tasks/" "$ACTIVITY_FILE" 2>/dev/null | grep -c "Write\|create" || echo "0")
  THREAD_WRITES=$(grep -c "threads/" "$ACTIVITY_FILE" 2>/dev/null | grep -c "Write\|Edit\|update\|append" || echo "0")

  if [[ "$TASK_WRITES" -gt 0 && "$THREAD_WRITES" -eq 0 ]]; then
    ERRORS="${ERRORS}\n- You modified TASKS but did NOT communicate in any THREAD. Report your task actions in the relevant thread."
  fi
fi

# Check 3: current-state.md should indicate session is ending
if [[ -f "$STATE_FILE" ]]; then
  STATUS=$(grep "^status:" "$STATE_FILE" | head -1 | awk '{print $2}')
  if [[ "$STATUS" == "working" || "$STATUS" == "blocked" ]]; then
    ERRORS="${ERRORS}\n- current-state.md status is '$STATUS'. Update to 'idle' or 'completing' before ending session."
  fi
fi

if [[ -n "$ERRORS" ]]; then
  echo "SESSION END BLOCKED. Before finishing, fix these issues:$ERRORS" >&2
  exit 2  # Block
fi

exit 0
