---
name: run-org
description: "Start continuous autonomous operation. The organisation runs heartbeat cycles automatically until all work is processed. No manual intervention needed between cycles — the loop script handles everything. Board can approve proposals in a separate terminal."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Bash, Glob, Grep
argument-hint: "[max-cycles|infinite] (default: 10, or 'infinite' for truly endless)"
---

# Run Organisation — Continuous Autonomous Operation

Start the organisation's continuous operation loop. Heartbeat cycles run automatically until all work is processed and the org reaches a quiescent state.

## How It Works

The `scripts/run-org.sh` bash script IS the loop:

1. Check for pending work (unread notifications, pending approvals, recent tasks)
2. If work exists → run a full 4-phase heartbeat cycle (CEO → Managers → Workers → CAO)
3. After the cycle → check for pending work again
4. If more work → immediately run another cycle (no delay)
5. If no work → wait 60 seconds, check again
6. If no work for 3 consecutive checks → org is quiescent, loop ends
7. Safety: max cycle limit (default 10, or "infinite")

**The user does NOT need to manually trigger anything between cycles.** The script handles all orchestration.

## Pre-flight Check

1. Verify `org/config.md` exists: if not, tell user to run `/onboard` first
2. Verify `scripts/run-org.sh` exists
3. Verify `scripts/heartbeat.sh` exists

## Run the Loop

```bash
bash scripts/run-org.sh $ARGUMENTS
```

Arguments:
- No argument: max 10 cycles, then pause
- A number (e.g., `50`): max 50 cycles
- `infinite`: never stop (truly autonomous, runs until stopped)

## Stopping the Loop

The loop can be stopped by:
1. **Ctrl+C** — immediate stop
2. **Stop signal file** — `touch org/.stop-org` (clean stop, checked between cycles)
3. **Max cycles reached** — automatic pause
4. **Quiescent** — no work for 3 consecutive 60-second checks

## Board Interaction During the Loop

The loop runs heartbeats via `claude --agent` invocations — these are separate processes. The user (board) can:
- Open a **second Claude Code terminal** and type `/approve`, `/status`, `/budget-check`, etc.
- Or use the **GUI dashboard** (localhost:3000) to approve proposals via the web interface
- Or create a **stop signal**: `touch org/.stop-org`

The loop will detect approved proposals and process them in the next cycle.

## For Fully Autonomous Background Operation

```bash
# Run in background — org operates while you're away
bash scripts/run-org.sh infinite &

# Check on it anytime
cat org/board/audit-log.md | tail -20

# Stop it
touch org/.stop-org

# Or use /loop for periodic wake-ups
# /loop 30m bash scripts/run-org.sh
```

## Example Output

```
[2026-03-31T10:00:00] ==========================================
[2026-03-31T10:00:00]   OrgAgent Continuous Operation Starting
[2026-03-31T10:00:00]   Max cycles: 10
[2026-03-31T10:00:00] ==========================================
[2026-03-31T10:00:01] ==========================================
[2026-03-31T10:00:01]   Cycle 1 — Pending: 3 unread, 0 approvals, 0 tasks
[2026-03-31T10:00:01] ==========================================
  [2026-03-31T10:00:01] Starting heartbeat: ceo (opus)
  [2026-03-31T10:00:45] Completed heartbeat: ceo (cost: $1.20)
  [2026-03-31T10:00:46] Starting heartbeat: eng-manager (sonnet)
  ...
[2026-03-31T10:02:30] Cycle 1 complete.
[2026-03-31T10:02:35] ==========================================
[2026-03-31T10:02:35]   Cycle 2 — Pending: 2 unread, 1 approvals, 3 tasks
[2026-03-31T10:02:35] ==========================================
  ...
[2026-03-31T10:05:00] Cycle 2 complete.
[2026-03-31T10:05:05] No pending work (idle check 1 of 3)
[2026-03-31T10:05:05] Waiting 60s before next check...
[2026-03-31T10:06:05] No pending work (idle check 2 of 3)
[2026-03-31T10:06:05] Waiting 60s before next check...
[2026-03-31T10:07:05] No pending work (idle check 3 of 3)
[2026-03-31T10:07:05] Organisation quiescent — no work for 3 consecutive checks.
[2026-03-31T10:07:05] ==========================================
[2026-03-31T10:07:05]   OrgAgent Continuous Operation Ended
[2026-03-31T10:07:05]   Ran 2 cycles
[2026-03-31T10:07:05] ==========================================
```

## IMPORTANT: This Replaces the Stop Hook Loop

The continuous loop is now handled by the bash script (`scripts/run-org.sh`), NOT by the Claude Code Stop hook. The Stop hook still validates agent state and communication (Part 1), but it no longer attempts to re-inject prompts for looping.

This is more reliable because:
- Bash loops ALWAYS work — no dependency on hook JSON format
- The script can check for work, wait, and re-check without Claude Code involvement
- Each heartbeat cycle is a clean `claude --agent` invocation
- The board can interact via a separate terminal or the GUI
