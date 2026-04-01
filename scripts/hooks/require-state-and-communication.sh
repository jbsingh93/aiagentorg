#!/usr/bin/env bash
# require-state-and-communication.sh
# Fires on: Stop event
#
# Validates that agents update their current-state.md and communicate
# in threads before ending their session. BLOCKS exit if they forget.
#
# NOTE: The continuous loop is handled by scripts/run-org.sh (a bash loop),
# NOT by this hook. This hook is purely for agent state validation.

AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)

# Board sessions always exit normally
if [[ "$AGENT" == "board" ]]; then
  exit 0
fi

STATE_FILE="$ORG_DIR/agents/$AGENT/activity/current-state.md"
ACTIVITY_FILE="$ORG_DIR/agents/$AGENT/activity/$TODAY.md"
ERRORS=""

# Check 1: current-state.md exists and is current
if [[ ! -f "$STATE_FILE" ]]; then
  ERRORS="${ERRORS}current-state.md does NOT exist. Create it at: $STATE_FILE. "
elif ! grep -q "$TODAY" "$STATE_FILE" 2>/dev/null; then
  ERRORS="${ERRORS}current-state.md is stale (no entry for $TODAY). Update it. "
fi

# Check 2: If tasks were modified, threads must have been used too
if [[ -f "$ACTIVITY_FILE" ]]; then
  TASK_WRITES=$(grep -c "tasks/" "$ACTIVITY_FILE" 2>/dev/null || echo "0")
  THREAD_WRITES=$(grep -c "threads/" "$ACTIVITY_FILE" 2>/dev/null || echo "0")
  if [[ "$TASK_WRITES" -gt 0 && "$THREAD_WRITES" -eq 0 ]]; then
    ERRORS="${ERRORS}Tasks modified without thread communication. Report in relevant thread. "
  fi
fi

# Check 3: Status should not be "working" or "blocked" at session end
if [[ -f "$STATE_FILE" ]]; then
  STATUS=$(grep "^status:" "$STATE_FILE" | head -1 | awk '{print $2}')
  if [[ "$STATUS" == "working" || "$STATUS" == "blocked" ]]; then
    ERRORS="${ERRORS}current-state.md status is '$STATUS'. Update to 'idle' or 'completing'. "
  fi
fi

if [[ -n "$ERRORS" ]]; then
  echo "SESSION BLOCKED: $ERRORS" >&2
  exit 2
fi

exit 0
