---
name: heartbeat
description: "Run the organisation heartbeat cycle using native Claude Code subagents for true parallelism. Phase 0: Alignment Board → Phase 1: CEO → Phase 2: Managers (parallel) → Phase 3: Workers (parallel) → Phase 4: CAO. Uses the Agent tool with subagent_type for each agent, run_in_background for parallel phases."
disable-model-invocation: true
user-invocable: true
allowed-tools: Agent, Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[agent-name] (OPTIONAL — only for debugging a single agent)"
---

# Heartbeat — Native Subagent Orchestration

Run the organisation heartbeat cycle using Claude Code's **native Agent tool** for true parallelism. This replaces the old bash-based sequential approach with subagent-based orchestration.

**Key advantage:** Managers run in parallel. Workers run in parallel. No cold-start overhead per agent. A 10-agent org completes in ~8 minutes instead of 30+.

## Pre-flight Check

1. Verify `org/config.md` exists: `if not → "No organisation found. Run /onboard first."`
2. Read `org/orgchart.md` to identify all active agents and their hierarchy
3. Run integrity check: `bash scripts/integrity-check.sh` — if critical, STOP

## Parse Orgchart

Read `org/orgchart.md` and classify agents by role:

- **Phase 0 agents:** agents with `alignment-board` in their ID
- **Phase 1 agents:** agents at depth 1 under Board (typically: CEO)
- **Phase 2 agents:** agents at depth 2, excluding CAO (managers)
- **Phase 3 agents:** agents at depth 3+ (workers)
- **Phase 4 agents:** the CAO (always last)

Determine each agent's model from their `org/agents/{name}/IDENTITY.md` (`model:` field).

For each agent, check if they have pending work (same logic as `has_pending_work()` in heartbeat.sh):
- Unread inbox notifications (`read: false`)
- Tasks in backlog or active
- Pending board approvals (for executives)

## SINGLE AGENT MODE (debugging only)

If `$ARGUMENTS` contains an agent name, run ONLY that agent:

```
Use the Agent tool:
  subagent_type: "{agent-name}"
  prompt: "Run your heartbeat cycle. Today is {YYYY-MM-DD}."
  mode: "bypassPermissions"
```

Then report results and stop.

## FULL CYCLE (default — no arguments)

Execute all 5 phases. For each phase, use the Agent tool to spawn agent(s).

### Phase 0: Alignment Board (sequential, foreground)

Only if `alignment-board` agent exists and is active:

```
Agent tool:
  subagent_type: "alignment-board"
  description: "Alignment Board governance review"
  prompt: "Run your heartbeat cycle. Today is {YYYY-MM-DD}. You are the Alignment Board — Phase 0 of the heartbeat. Review pending proposals, check for drift, assess alignment."
  mode: "bypassPermissions"
```

Wait for completion. Report any governance issues found.

### Phase 1: CEO (sequential, foreground)

```
Agent tool:
  subagent_type: "ceo"
  description: "CEO strategic heartbeat"
  prompt: "Run your heartbeat cycle. Today is {YYYY-MM-DD}."
  mode: "bypassPermissions"
```

Wait for completion. The CEO's output will include tasks delegated to managers.

### Phase 2: Managers (PARALLEL, background)

For EACH manager with pending work, launch in parallel using `run_in_background: true`:

```
For each manager agent:
  Agent tool:
    subagent_type: "{manager-name}"   (if .claude/agents/{name}.md exists)
    description: "{manager-name} heartbeat"
    prompt: "Run your heartbeat cycle. Today is {YYYY-MM-DD}."
    run_in_background: true
    mode: "bypassPermissions"
```

**CRITICAL:** Launch ALL managers in a SINGLE message with MULTIPLE Agent tool calls. This is how Claude Code achieves true parallelism — multiple tool calls in one response run concurrently.

Skip managers with no pending work: "Skipping {name} — no pending work."

Wait for ALL background managers to complete (you will be notified when each finishes).

### Phase 3: Workers (PARALLEL, background)

Same pattern as Phase 2 — launch ALL workers with pending work in a SINGLE message:

```
For each worker agent:
  Agent tool:
    subagent_type: "{worker-name}"    (if .claude/agents/{name}.md exists)
    description: "{worker-name} heartbeat"
    prompt: "Run your heartbeat cycle. Today is {YYYY-MM-DD}."
    run_in_background: true
    mode: "bypassPermissions"
```

Skip workers with no pending work.

**If no .claude/agents/{name}.md exists** for a worker (dynamically hired agents without a custom definition), use a generic agent:

```
Agent tool:
  subagent_type: "general-purpose"
  name: "{worker-name}"
  description: "{worker-name} heartbeat"
  prompt: "You are {worker-name}, an agent in an AI organisation. Read your workspace at org/agents/{worker-name}/ to initialize: SOUL.md → IDENTITY.md → INSTRUCTIONS.md → HEARTBEAT.md → MEMORY.md. Then run your heartbeat cycle. Today is {YYYY-MM-DD}."
  run_in_background: true
  mode: "bypassPermissions"
```

Wait for ALL background workers to complete.

### Phase 4: CAO (sequential, foreground)

```
Agent tool:
  subagent_type: "cao"
  description: "CAO workforce review"
  prompt: "Run your heartbeat cycle. Today is {YYYY-MM-DD}."
  mode: "bypassPermissions"
```

Wait for completion.

## Post-Heartbeat Summary

After all phases complete, report:

1. **Phase results:** Which agents ran, which were skipped (no work), which failed
2. **Timing:** Note which phases ran in parallel
3. **Pending work:** Check if new work was created during this cycle (for Ralph Wiggum loop)
   - Unread inbox notifications: `grep -rl "read: false" org/agents/*/inbox/ 2>/dev/null | wc -l`
   - Pending approvals: `grep -rl "status: pending" org/board/approvals/ 2>/dev/null | wc -l`
4. **Errors:** Any agents that failed or were skipped due to circuit breaker

## Important Rules

- **Do NOT tell the user to run phases manually.** This skill runs ALL phases automatically.
- **Do NOT run managers/workers sequentially.** Use `run_in_background: true` and launch them in a SINGLE message for true parallelism.
- **Do NOT skip the Alignment Board.** Phase 0 runs FIRST, always (if the agent exists).
- **CAO runs LAST.** Phase 4 is always the final phase.
- **Agents with no pending work are SKIPPED** — zero cost for idle agents.
- **If an agent has no `.claude/agents/{name}.md` definition**, use `general-purpose` subagent type with a prompt that loads the agent's workspace files.

## Fallback: Bash Script

If the Agent tool is not available or fails, fall back to the bash script:

```bash
bash scripts/heartbeat.sh
```

This runs the old sequential approach. It still works, just slower.
