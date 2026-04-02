#!/usr/bin/env bash
# OrgAgent Heartbeat — Multi-phase org cycle
set -euo pipefail

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
SINGLE_AGENT="${1:-}"

# Common flags for all agent invocations
CLAUDE_FLAGS="--output-format json --max-budget-usd 5.00"

# Agents that always run regardless of pending work (org-wide responsibilities)
ALWAYS_RUN_AGENTS="ceo cao alignment-board"

# ============================================================================
# Selective invocation: check if agent has pending work before invoking
# ============================================================================
has_pending_work() {
  local agent="$1"
  local agent_dir="$ORG_DIR/agents/$agent"

  # Agents in ALWAYS_RUN list always have "work" (org-wide duties)
  if echo "$ALWAYS_RUN_AGENTS" | grep -qw "$agent"; then
    return 0
  fi

  # Check 1: Unread inbox notifications
  if [[ -d "$agent_dir/inbox" ]]; then
    if find "$agent_dir/inbox/" -name "*.md" -exec grep -l "read: false" {} \; 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  fi

  # Check 2: Tasks in backlog
  if [[ -d "$agent_dir/tasks/backlog" ]]; then
    if find "$agent_dir/tasks/backlog/" -name "*.md" 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  fi

  # Check 3: Active tasks (need continuation)
  if [[ -d "$agent_dir/tasks/active" ]]; then
    if find "$agent_dir/tasks/active/" -name "*.md" 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  fi

  # Check 4: Pending approvals (for executive agents)
  if [[ "$agent" == "ceo" || "$agent" == "cao" || "$agent" == "alignment-board" ]]; then
    if [[ -d "$ORG_DIR/board/approvals" ]]; then
      if find "$ORG_DIR/board/approvals/" -name "*.md" -exec grep -l "status: pending" {} \; 2>/dev/null | head -1 | grep -q .; then
        return 0
      fi
    fi
  fi

  return 1  # No pending work
}

# Circuit breaker: check if agent is in OPEN state (too many consecutive failures)
FAILURE_THRESHOLD=3
RECOVERY_TIMEOUT=300  # 5 minutes

check_circuit_breaker() {
  local agent_name="$1"
  local breaker_file="$ORG_DIR/agents/$agent_name/.circuit-breaker"
  if [[ ! -f "$breaker_file" ]]; then echo "CLOSED"; return; fi

  local state failures last_fail
  state=$(cut -d: -f1 "$breaker_file")
  failures=$(cut -d: -f2 "$breaker_file")
  last_fail=$(cut -d: -f3 "$breaker_file")
  local now
  now=$(date +%s)

  if [[ "$state" == "OPEN" ]]; then
    if (( now - last_fail > RECOVERY_TIMEOUT )); then
      echo "HALF_OPEN"
    else
      echo "OPEN"
    fi
  elif [[ "${failures:-0}" -ge "$FAILURE_THRESHOLD" ]]; then
    echo "OPEN"
  else
    echo "CLOSED"
  fi
}

record_failure() {
  local agent_name="$1"
  local breaker_file="$ORG_DIR/agents/$agent_name/.circuit-breaker"
  local now
  now=$(date +%s)
  local failures=0
  if [[ -f "$breaker_file" ]]; then
    failures=$(cut -d: -f2 "$breaker_file")
  fi
  failures=$((failures + 1))
  local state="CLOSED"
  if [[ "$failures" -ge "$FAILURE_THRESHOLD" ]]; then
    state="OPEN"
  fi
  echo "$state:$failures:$now" > "$breaker_file"
}

record_success() {
  local agent_name="$1"
  local breaker_file="$ORG_DIR/agents/$agent_name/.circuit-breaker"
  rm -f "$breaker_file"
}

# Helper: run one agent's heartbeat with error handling and retry
run_agent() {
  local agent_name="$1"

  # Pre-check: skip if agent definition is missing
  if [[ ! -f ".claude/agents/$agent_name.md" ]]; then
    echo "WARNING: Agent definition missing for $agent_name — skipping" >&2
    echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | SYSTEM | error | $agent_name | Agent definition missing |" >> "$ORG_DIR/board/audit-log.md" 2>/dev/null
    return 1
  fi

  # Circuit breaker check
  local breaker_state
  breaker_state=$(check_circuit_breaker "$agent_name")
  if [[ "$breaker_state" == "OPEN" ]]; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] CIRCUIT OPEN: Skipping $agent_name (too many consecutive failures)" >&2
    return 1
  fi

  local model
  model=$(grep "model:" "$ORG_DIR/agents/$agent_name/IDENTITY.md" 2>/dev/null | head -1 | awk '{print $2}')

  # Extract tools from IDENTITY.md (fixed: state-machine approach)
  local tools
  tools=$(awk '/^tools:/{p=1;next} /^[a-z]/{p=0} p' "$ORG_DIR/agents/$agent_name/IDENTITY.md" 2>/dev/null | \
    grep '^ *-' | sed 's/^ *- *//' | tr '\n' ',' | sed 's/,$//')

  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Starting heartbeat: $agent_name ($model)"

  export ORGAGENT_CURRENT_AGENT="$agent_name"
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1

  local result exit_code=0
  result=$(claude --agent "$agent_name" -p "Run your heartbeat cycle. Today is $(date +%Y-%m-%d)." \
    $CLAUDE_FLAGS --model "${model:-sonnet}" \
    --allowedTools "${tools:-Read,Write,Edit,Glob,Grep}" \
    2>&1) || exit_code=$?

  if [[ "$exit_code" -ne 0 ]]; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] FAILED: $agent_name (exit code $exit_code)" >&2

    # Retry once after 5 seconds (only for CLOSED or HALF_OPEN)
    if [[ "$breaker_state" != "HALF_OPEN" ]]; then
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Retrying $agent_name in 5s..." >&2
      sleep 5
      exit_code=0  # Reset before retry
      result=$(claude --agent "$agent_name" -p "Run your heartbeat cycle. Today is $(date +%Y-%m-%d)." \
        $CLAUDE_FLAGS --model "${model:-sonnet}" \
        --allowedTools "${tools:-Read,Write,Edit,Glob,Grep}" \
        2>&1) || exit_code=$?
    fi

    if [[ "$exit_code" -ne 0 ]]; then
      record_failure "$agent_name"
      echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | $agent_name | heartbeat | FAILED | exit code $exit_code |" >> "$ORG_DIR/board/audit-log.md" 2>/dev/null
      return 1
    fi
  fi

  # Success — reset circuit breaker
  record_success "$agent_name"

  # Extract and log cost
  local cost
  cost=$(echo "$result" | jq -r '.cost_usd // "0.00"' 2>/dev/null || echo "0.00")
  local running_total
  running_total=$(tail -1 "$ORG_DIR/budgets/spending-log.md" 2>/dev/null | awk -F'|' '{gsub(/[$ ]/, "", $6); print $6+0}' 2>/dev/null || echo "0")
  local new_total
  new_total=$(awk "BEGIN {printf \"%.2f\", $running_total + $cost}")
  echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | $agent_name | heartbeat | \$$cost | \$$new_total |" >> "$ORG_DIR/budgets/spending-log.md" 2>/dev/null

  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Completed heartbeat: $agent_name (cost: \$$cost)"
  return 0
}

# Track phase failures for cascading failure detection
PHASE_FAILURES=0
CASCADE_THRESHOLD=2

# If single agent specified, run just that one
if [[ -n "$SINGLE_AGENT" ]]; then
  run_agent "$SINGLE_AGENT"
  exit 0
fi

# Parse orgchart to determine agents and hierarchy
# Depth 1 = CEO (Phase 1), Depth 2 = Managers/CAO (Phase 2/4), Depth 3+ = Workers (Phase 3)
parse_orgchart() {
  local depth="$1"
  grep -E "^$( printf '  %.0s' $(seq 1 $depth) )- \*\*" "$ORG_DIR/orgchart.md" | \
    grep "(active" | \
    grep -o '@[a-z0-9-]*' | sed 's/@//' || true
}

CEO_AGENTS=$(parse_orgchart 1)
MANAGER_AGENTS=$(parse_orgchart 2 | grep -v "cao" || true)
WORKER_AGENTS=$(parse_orgchart 3)
# Add deeper workers (depth 4+)
for d in 4 5 6; do
  MORE=$(parse_orgchart $d)
  [[ -n "$MORE" ]] && WORKER_AGENTS="$WORKER_AGENTS $MORE"
done

echo "=== OrgAgent Heartbeat Cycle — $(date -u +"%Y-%m-%dT%H:%M:%S") ==="
echo "Phase 0 (Alignment Board): alignment-board"
echo "Phase 1 (CEO): $CEO_AGENTS"
echo "Phase 2 (Managers): $MANAGER_AGENTS"
echo "Phase 3 (Workers): $WORKER_AGENTS"
echo "Phase 4 (CAO): cao"
echo ""

# Phase 0: Alignment Board (sequential, runs FIRST — governance review)
echo "--- Phase 0: Alignment Board ---"
if [[ -f ".claude/agents/alignment-board.md" ]] && [[ -d "$ORG_DIR/agents/alignment-board" ]]; then
  run_agent "alignment-board" || echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] WARNING: Alignment Board heartbeat failed"
else
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Alignment Board not yet created — skipping Phase 0"
fi

# Phase 1: CEO (sequential)
echo "--- Phase 1: CEO ---"
for agent in $CEO_AGENTS; do
  run_agent "$agent" || echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] WARNING: $agent heartbeat failed"
done

# Phase 2: Managers (parallel, selective invocation)
echo "--- Phase 2: Managers ---"
pids=()
PHASE_FAILURES=0
if [[ -n "$MANAGER_AGENTS" ]]; then
  for agent in $MANAGER_AGENTS; do
    if has_pending_work "$agent"; then
      run_agent "$agent" &
      pids+=($!)
    else
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Skipping $agent — no pending work"
    fi
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || PHASE_FAILURES=$((PHASE_FAILURES + 1))
  done
  if [[ $PHASE_FAILURES -ge $CASCADE_THRESHOLD ]]; then
    echo "CASCADING FAILURE: $PHASE_FAILURES managers failed in Phase 2. Halting." >&2
    echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | SYSTEM | CASCADE | Phase 2 | $PHASE_FAILURES failures |" >> "$ORG_DIR/board/audit-log.md" 2>/dev/null
    touch "$ORG_DIR/.stop-org" 2>/dev/null
  fi
fi

# Phase 3: Workers (parallel) — skip if cascading failure detected
echo "--- Phase 3: Workers ---"
pids=()
PHASE_FAILURES=0
if [[ -n "$WORKER_AGENTS" ]] && [[ ! -f "$ORG_DIR/.stop-org" ]]; then
  for agent in $WORKER_AGENTS; do
    if has_pending_work "$agent"; then
      run_agent "$agent" &
      pids+=($!)
    else
      echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Skipping $agent — no pending work"
    fi
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || PHASE_FAILURES=$((PHASE_FAILURES + 1))
  done
  if [[ $PHASE_FAILURES -ge $CASCADE_THRESHOLD ]]; then
    echo "CASCADING FAILURE: $PHASE_FAILURES workers failed in Phase 3. Halting." >&2
    echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | SYSTEM | CASCADE | Phase 3 | $PHASE_FAILURES failures |" >> "$ORG_DIR/board/audit-log.md" 2>/dev/null
    touch "$ORG_DIR/.stop-org" 2>/dev/null
  fi
elif [[ -f "$ORG_DIR/.stop-org" ]]; then
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Skipping Phase 3 — stop signal detected"
fi

# Phase 4: CAO (sequential, always last)
echo "--- Phase 4: CAO ---"
run_agent "cao" || echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] WARNING: CAO heartbeat failed"

echo ""
echo "=== Heartbeat cycle complete — $(date -u +"%Y-%m-%dT%H:%M:%S") ==="
