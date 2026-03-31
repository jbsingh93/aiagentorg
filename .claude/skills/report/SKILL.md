---
name: report
description: "Write a status report for an agent. Gathers data from tasks, activity stream, budget, and threads to produce a structured daily report."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent-name] — or omit for org-wide summary"
---

# Write Status Report

## Step 1: Determine which agent
If `$ARGUMENTS` provided: report for that agent.
If "all" or omitted: generate org-wide summary (aggregate all agents).

## Step 2: Gather data
For the target agent, read:
1. `org/agents/{name}/tasks/active/` — count and list active tasks
2. `org/agents/{name}/tasks/done/` — tasks completed today (check `completed` date in frontmatter)
3. `org/agents/{name}/tasks/backlog/` — count pending tasks
4. `org/agents/{name}/activity/current-state.md` — current cognitive state
5. `org/agents/{name}/activity/{YYYY-MM-DD}.md` — today's activity stream (action count)
6. `org/budgets/overview.md` — find this agent's budget row
7. `org/config.md` — get currency code
8. `org/threads/{department}/` — count messages sent/received today by this agent

## Step 3: Write the report
Write to `org/agents/{name}/reports/daily-{YYYY-MM-DD}.md`:

```markdown
---
agent: {AGENT_NAME}
date: {TODAY}
heartbeat_cycles: {COUNT_FROM_ACTIVITY_STREAM}
---

# Daily Report — {AGENT_TITLE} — {TODAY}

## Summary
{1-2 sentence overview synthesized from gathered data}

## Completed
- [x] {Task title} — {brief result} (task-{ID})
{for each task moved to done/ today}

## In Progress
- [ ] {Task title} — {current step from current-state.md} (task-{ID})
{for each task in active/}

## Backlog
{N} tasks waiting in backlog

## Budget
{SPENT} / {ALLOCATED} {CURRENCY} ({PERCENTAGE}%)
Status: {OK / WARNING >80% / EXHAUSTED}

## Blockers
{From current-state.md Blockers section, or "None"}

## Key Decisions
{From current-state.md Reasoning Trace, or "None"}

## Escalations
{Any escalation messages sent today, or "None"}
```

## Step 4: Org-wide summary (if "all")
Read all agent reports for today and aggregate into:
```markdown
# Org Report — {ORG_NAME} — {TODAY}

## Active Agents: {N}
## Tasks Completed Today: {N}
## Tasks In Progress: {N}
## Budget: {TOTAL_SPENT} / {TOTAL_BUDGET} {CURRENCY}
## Escalations: {N}

{Per-agent one-line summary}
```
Write to `org/board/reports/org-daily-{YYYY-MM-DD}.md`

## Step 5: Confirm
"Report written for @{agent}: org/agents/{name}/reports/daily-{date}.md"
