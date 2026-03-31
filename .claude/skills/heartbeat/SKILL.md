---
name: heartbeat
description: "Run the organisation heartbeat cycle — all agents process their queues in 4 sequential phases (CEO → Managers → Workers → CAO). Pass an agent name to run a single agent's heartbeat only."
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[agent-name] (optional — run single agent or full org cycle)"
---

# Heartbeat

Run the organisation heartbeat cycle.

## Pre-flight Check
Before running, verify:
1. `org/config.md` exists (organisation has been onboarded)
2. `scripts/heartbeat.sh` exists

If org/config.md doesn't exist, tell the user: "No organisation found. Run /onboard first."

## Execution

If an agent name is provided as `$ARGUMENTS`, run only that agent's heartbeat:
```bash
bash scripts/heartbeat.sh $ARGUMENTS
```

If no argument, run the full multi-phase org heartbeat (all 4 phases):
```bash
bash scripts/heartbeat.sh
```

## Report Results

After the script completes, summarize:
1. Which agents ran (and which phase)
2. Any errors or warnings from the script output
3. Total cost for this cycle (from spending-log.md, last N entries matching this timestamp)
4. Any agents that were skipped (missing definition, budget exhausted)

If any agent's heartbeat failed, flag it clearly for the user.
