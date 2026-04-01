#!/usr/bin/env bash
# OrgAgent Heartbeat — Multi-phase org cycle
set -euo pipefail

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
SINGLE_AGENT="${1:-}"

# Common flags for all agent invocations
CLAUDE_FLAGS="--output-format json --max-budget-usd 5.00"

# Helper: run one agent's heartbeat
run_agent() {
  local agent_name="$1"

  # Pre-check: skip if agent definition is missing
  if [[ ! -f ".claude/agents/$agent_name.md" ]]; then
    echo "WARNING: Agent definition missing for $agent_name — skipping" >&2
    echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | SYSTEM | error | $agent_name | Agent definition missing |" >> "$ORG_DIR/board/audit-log.md"
    return
  fi

  local model=$(grep "model:" "$ORG_DIR/agents/$agent_name/IDENTITY.md" | head -1 | awk '{print $2}')

  # Extract tools from IDENTITY.md
  local tools=$(awk '/^tools:/,/^[a-z]/' "$ORG_DIR/agents/$agent_name/IDENTITY.md" | \
    grep '^ *-' | sed 's/^ *- *//' | tr '\n' ',' | sed 's/,$//')

  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Starting heartbeat: $agent_name ($model)"

  export ORGAGENT_CURRENT_AGENT="$agent_name"
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1

  local result
  result=$(claude --agent "$agent_name" -p "Run your heartbeat cycle. Today is $(date +%Y-%m-%d)." \
    $CLAUDE_FLAGS --model "${model:-sonnet}" \
    --allowedTools "${tools:-Read,Write,Edit,Glob,Grep}" \
    2>&1) || true

  # Extract and log cost
  local cost=$(echo "$result" | jq -r '.cost_usd // "0.00"' 2>/dev/null || echo "0.00")
  local running_total=$(tail -1 "$ORG_DIR/budgets/spending-log.md" | awk -F'|' '{gsub(/[$ ]/, "", $6); print $6+0}' 2>/dev/null || echo "0")
  local new_total=$(awk "BEGIN {printf \"%.2f\", $running_total + $cost}")
  echo "| $(date -u +"%Y-%m-%dT%H:%M:%S") | $agent_name | heartbeat | \$$cost | \$$new_total |" >> "$ORG_DIR/budgets/spending-log.md"

  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Completed heartbeat: $agent_name (cost: \$$cost)"
}

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
  run_agent "alignment-board"
else
  echo "[$(date -u +"%Y-%m-%dT%H:%M:%S")] Alignment Board not yet created — skipping Phase 0"
fi

# Phase 1: CEO (sequential)
echo "--- Phase 1: CEO ---"
for agent in $CEO_AGENTS; do
  run_agent "$agent"
done

# Phase 2: Managers (parallel)
echo "--- Phase 2: Managers ---"
pids=()
if [[ -n "$MANAGER_AGENTS" ]]; then
  for agent in $MANAGER_AGENTS; do
    run_agent "$agent" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || echo "Warning: manager heartbeat failed (PID $pid)"
  done
fi

# Phase 3: Workers (parallel)
echo "--- Phase 3: Workers ---"
pids=()
if [[ -n "$WORKER_AGENTS" ]]; then
  for agent in $WORKER_AGENTS; do
    run_agent "$agent" &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait "$pid" || echo "Warning: worker heartbeat failed (PID $pid)"
  done
fi

# Phase 4: CAO (sequential, always last)
echo "--- Phase 4: CAO ---"
run_agent "cao"

echo ""
echo "=== Heartbeat cycle complete — $(date -u +"%Y-%m-%dT%H:%M:%S") ==="
