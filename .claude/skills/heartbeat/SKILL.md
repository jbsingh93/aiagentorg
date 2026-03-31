---
name: heartbeat
description: "Run the organisation heartbeat cycle — all agents process their queues in 4 sequential phases (CEO → Managers → Workers → CAO). Fully autonomous — no manual intervention between phases. Pass an agent name ONLY for debugging a single agent."
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[agent-name] (OPTIONAL — only for debugging. Default: run FULL autonomous cycle)"
---

# Heartbeat

Run the organisation heartbeat cycle. **This is fully autonomous — all 4 phases run automatically without manual intervention.**

## Pre-flight Check
1. Verify `org/config.md` exists (organisation has been onboarded)
2. Verify `scripts/heartbeat.sh` exists

If org/config.md doesn't exist: "No organisation found. Run /onboard first."

## FULL CYCLE (default — no arguments)

This is the PRIMARY usage. Runs ALL 4 phases automatically:

```bash
bash scripts/heartbeat.sh
```

**Phase 1:** CEO processes inbox, reviews initiatives, delegates tasks, writes report
**Phase 2:** All managers process CEO's tasks, delegate to workers (parallel)
**Phase 3:** All workers execute tasks, write deliverables (parallel)
**Phase 4:** CAO reviews org health, proposes hires/changes, reports to board

**The user does NOT need to run each phase manually. The script handles everything.**

## SINGLE AGENT (debugging only)

Only use this when debugging a specific agent:

```bash
bash scripts/heartbeat.sh $ARGUMENTS
```

**NOTE:** This runs ONLY that one agent. It does NOT trigger subsequent phases. This is for debugging — not normal operation. For normal operation, always use the full cycle (no arguments).

## Report Results

After the script completes, summarize:
1. Which agents ran and in which phase
2. Any errors or warnings
3. Total cost for this cycle (last entries in org/budgets/spending-log.md)
4. Any agents skipped (missing definition, budget exhausted, inactive)

**IMPORTANT:** Do NOT tell the user to manually run the next phase or another agent. The full cycle handles everything. If an agent needs input from another agent, it will be picked up in the next heartbeat cycle.
