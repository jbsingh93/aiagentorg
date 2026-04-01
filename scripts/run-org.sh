#!/usr/bin/env bash
# ============================================================================
# run-org.sh — Continuous Autonomous Organisation Loop
# ============================================================================
#
# This script IS the infinite loop. It runs heartbeat cycles as long as there
# is pending work. When the org is quiescent, it waits and checks again.
# When it detects new work, it immediately runs another cycle.
#
# Usage:
#   bash scripts/run-org.sh              # Default: max 10 cycles, then wait
#   bash scripts/run-org.sh 50           # Max 50 cycles before forced pause
#   bash scripts/run-org.sh infinite     # Never stop (truly infinite)
#
# To run in the background (fully autonomous):
#   bash scripts/run-org.sh infinite &
#
# To stop:
#   kill %1  (if backgrounded)
#   Ctrl+C   (if foreground)
#   touch org/.stop-org  (clean stop signal — script checks for this)
#
# ============================================================================

set -uo pipefail

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
MAX_CYCLES="${1:-10}"
CYCLE=0
IDLE_CHECKS=0
MAX_IDLE_CHECKS=3        # Stop after 3 consecutive idle checks
IDLE_WAIT_SECONDS=60     # Wait between idle checks
CYCLE_COOLDOWN=5         # Brief pause between back-to-back cycles

# ============================================================================
# Helpers
# ============================================================================

timestamp() { date -u +"%Y-%m-%dT%H:%M:%S"; }

log() { echo "[$(timestamp)] $*"; }

check_stop_signal() {
  if [[ -f "$ORG_DIR/.stop-org" ]]; then
    log "Stop signal detected (org/.stop-org). Shutting down."
    rm -f "$ORG_DIR/.stop-org"
    exit 0
  fi
}

# ============================================================================
# Check for pending work across the entire org
# ============================================================================
check_pending_work() {
  local unread=0 approvals=0 recent_tasks=0

  # Unread inbox notifications
  for inbox in "$ORG_DIR"/agents/*/inbox/; do
    if [[ -d "$inbox" ]]; then
      local n=$(grep -rl "read: false" "$inbox" 2>/dev/null | wc -l)
      unread=$((unread + n))
    fi
  done

  # Pending board approvals
  if [[ -d "$ORG_DIR/board/approvals" ]]; then
    approvals=$(grep -rl "status: pending" "$ORG_DIR/board/approvals/" 2>/dev/null | wc -l)
  fi

  # Recently created backlog tasks (last 15 minutes)
  for backlog in "$ORG_DIR"/agents/*/tasks/backlog/; do
    if [[ -d "$backlog" ]]; then
      local n=$(find "$backlog" -name "*.md" -mmin -15 2>/dev/null | wc -l)
      recent_tasks=$((recent_tasks + n))
    fi
  done

  PENDING_UNREAD=$unread
  PENDING_APPROVALS=$approvals
  PENDING_TASKS=$recent_tasks
  PENDING_TOTAL=$((unread + approvals + recent_tasks))
}

# ============================================================================
# Main Loop
# ============================================================================

log "=========================================="
log "  OrgAgent Continuous Operation Starting"
log "  Max cycles: $MAX_CYCLES"
log "  Idle timeout: $MAX_IDLE_CHECKS checks × ${IDLE_WAIT_SECONDS}s"
log "  Stop signal: touch $ORG_DIR/.stop-org"
log "=========================================="

# Verify org exists
if [[ ! -f "$ORG_DIR/config.md" ]]; then
  log "ERROR: No organisation found ($ORG_DIR/config.md missing). Run /onboard first."
  exit 1
fi

while true; do
  check_stop_signal

  # Check for pending work
  check_pending_work

  if [[ $PENDING_TOTAL -eq 0 ]]; then
    IDLE_CHECKS=$((IDLE_CHECKS + 1))
    log "No pending work (idle check $IDLE_CHECKS of $MAX_IDLE_CHECKS)"

    if [[ $IDLE_CHECKS -ge $MAX_IDLE_CHECKS ]]; then
      log "Organisation quiescent — no work for $MAX_IDLE_CHECKS consecutive checks."
      log "Loop ending. Use /run-org or /loop to restart."
      break
    fi

    log "Waiting ${IDLE_WAIT_SECONDS}s before next check..."
    sleep "$IDLE_WAIT_SECONDS"
    continue
  fi

  # There's work to do — reset idle counter
  IDLE_CHECKS=0
  CYCLE=$((CYCLE + 1))

  # Check cycle limit (unless "infinite")
  if [[ "$MAX_CYCLES" != "infinite" && $CYCLE -gt $MAX_CYCLES ]]; then
    log "Max cycles ($MAX_CYCLES) reached. Pausing."
    log "Pending: $PENDING_UNREAD unread, $PENDING_APPROVALS approvals, $PENDING_TASKS tasks"
    log "Run again to continue processing."
    break
  fi

  log "=========================================="
  log "  Cycle $CYCLE — Pending: ${PENDING_UNREAD} unread, ${PENDING_APPROVALS} approvals, ${PENDING_TASKS} tasks"
  log "=========================================="

  # Run the full 4-phase heartbeat
  bash scripts/heartbeat.sh 2>&1 | while IFS= read -r line; do
    echo "  $line"
  done

  log "Cycle $CYCLE complete."

  # Brief cooldown between cycles (prevents hammering)
  check_stop_signal
  sleep "$CYCLE_COOLDOWN"
done

log "=========================================="
log "  OrgAgent Continuous Operation Ended"
log "  Ran $CYCLE cycles"
log "=========================================="
