#!/usr/bin/env bash
# require-state-and-communication.sh
# Enhanced with Ralph Wiggum continuous loop pattern
#
# DUAL BEHAVIOR:
#   Part 1 (Agent sessions): Validate current-state.md + thread communication
#   Part 2-4 (Board sessions, org-run mode): Ralph Wiggum loop — cycle until quiescent
#   Part 5 (Board sessions, NOT org-run mode): Allow exit normally
#
# Fires on: Stop event (registered in .claude/settings.json)

AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
LOOP_STATE="$ORG_DIR/.loop-state.md"

# ========================================
# PART 1: Agent state validation (non-board sessions only)
# ========================================
if [[ "$AGENT" != "board" ]]; then
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

  # Agent sessions: exit normally after validation
  exit 0
fi

# ========================================
# PART 2: Board session — check if org-run mode is active
# ========================================
if [[ ! -f "$LOOP_STATE" ]]; then
  # Not in org-run mode — normal board exit
  exit 0
fi

# ========================================
# PART 3: Ralph Wiggum loop — read state and check limits
# ========================================

# Read loop state
ITERATION=$(grep "^iteration:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "0")
MAX_ITERATIONS=$(grep "^max_iterations:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "10")
STALE_COUNT=$(grep "^stale_count:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "0")
PREV_PENDING=$(grep "^prev_pending:" "$LOOP_STATE" 2>/dev/null | sed 's/^prev_pending: *//' || echo "")

# Safety check: max iterations reached
if [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  echo "Max iterations ($MAX_ITERATIONS) reached. Organisation loop ending." >&2
  rm -f "$LOOP_STATE"
  exit 0
fi

# Check for completion promise in Claude's last output
INPUT=$(cat)
ASSISTANT_OUTPUT=$(echo "$INPUT" | jq -r '
  if type == "object" then
    (.transcript // [])[-1].content // ""
  else
    ""
  end
' 2>/dev/null || echo "")

if echo "$ASSISTANT_OUTPUT" | grep -q '<promise>ORG_IDLE</promise>'; then
  rm -f "$LOOP_STATE"
  exit 0  # Clean exit — org is quiescent
fi

# ========================================
# PART 4: Check for pending work across the org
# ========================================

UNREAD_COUNT=0
PENDING_APPROVALS=0
RECENT_TASKS=0

# Check 1: Unread notifications in any agent's inbox
for inbox_dir in "$ORG_DIR"/agents/*/inbox/; do
  if [[ -d "$inbox_dir" ]]; then
    UNREAD=$(grep -rl "read: false" "$inbox_dir" 2>/dev/null | wc -l)
    UNREAD_COUNT=$((UNREAD_COUNT + UNREAD))
  fi
done

# Check 2: Pending approvals
if [[ -d "$ORG_DIR/board/approvals" ]]; then
  PENDING_APPROVALS=$(grep -rl "status: pending" "$ORG_DIR/board/approvals/" 2>/dev/null | wc -l)
fi

# Check 3: Recently created backlog tasks (last 10 minutes)
for backlog_dir in "$ORG_DIR"/agents/*/tasks/backlog/; do
  if [[ -d "$backlog_dir" ]]; then
    RECENT=$(find "$backlog_dir" -name "*.md" -mmin -10 2>/dev/null | wc -l)
    RECENT_TASKS=$((RECENT_TASKS + RECENT))
  fi
done

# ========================================
# PART 5: Stale loop detection
# ========================================

CURRENT_PENDING="${UNREAD_COUNT}-${PENDING_APPROVALS}-${RECENT_TASKS}"
TOTAL_PENDING=$((UNREAD_COUNT + PENDING_APPROVALS + RECENT_TASKS))

if [[ "$CURRENT_PENDING" == "$PREV_PENDING" && "$TOTAL_PENDING" -gt 0 ]]; then
  # Same pending work as last cycle — no progress made
  NEW_STALE=$((STALE_COUNT + 1))
  if [[ "$NEW_STALE" -ge 3 ]]; then
    echo "Loop stale for 3 cycles — pending work is not being resolved. Stopping." >&2
    rm -f "$LOOP_STATE"
    exit 0
  fi
else
  # Progress was made — reset stale counter
  NEW_STALE=0
fi

# ========================================
# PART 6: Decision — block or allow
# ========================================

if [[ "$TOTAL_PENDING" -gt 0 ]]; then
  # Increment iteration and update state file
  NEW_ITERATION=$((ITERATION + 1))
  cat > "$LOOP_STATE" <<STATEEOF
---
iteration: $NEW_ITERATION
max_iterations: $MAX_ITERATIONS
started: $(grep "^started:" "$LOOP_STATE" 2>/dev/null | sed 's/^started: *//' || date -u +"%Y-%m-%dT%H:%M:%S")
mode: continuous
stale_count: $NEW_STALE
prev_pending: $CURRENT_PENDING
---
STATEEOF

  # Build pending work description
  WORK_DESC=""
  [[ "$UNREAD_COUNT" -gt 0 ]] && WORK_DESC="${WORK_DESC}${UNREAD_COUNT} unread notifications. "
  [[ "$PENDING_APPROVALS" -gt 0 ]] && WORK_DESC="${WORK_DESC}${PENDING_APPROVALS} pending approvals. "
  [[ "$RECENT_TASKS" -gt 0 ]] && WORK_DESC="${WORK_DESC}${RECENT_TASKS} recent backlog tasks. "

  # Block exit and re-inject prompt (Ralph Wiggum pattern)
  REASON="Organisation cycle $NEW_ITERATION of $MAX_ITERATIONS. Pending work detected: ${WORK_DESC}Run the next heartbeat cycle: bash scripts/heartbeat.sh. After the heartbeat completes, assess the org state. Check for pending approvals and present them to the user. Check for unread notifications and recent tasks. If ALL inboxes are empty, ALL approvals processed, and NO new tasks were created, output <promise>ORG_IDLE</promise> to end the loop. If pending approvals exist, present them to the user and wait for their decision before ending your response."

  # Output JSON decision for Claude Code Stop hook
  printf '{"decision":"block","reason":"%s"}' "$(echo "$REASON" | sed 's/"/\\"/g')"
  exit 2
fi

# No pending work — org is quiescent
rm -f "$LOOP_STATE"
exit 0
