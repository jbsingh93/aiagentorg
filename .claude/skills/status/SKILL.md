---
name: status
description: "Show organisation overview — agents, tasks, budget, pending approvals, recent activity. Quick snapshot of the org's current state."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Glob, Grep
---

# Organisation Status

Read and summarize the following:

## 1. Org Info
Read `org/config.md` for: organisation name, language, currency, oversight level, heartbeat interval.

## 2. Agent Roster
Read `org/orgchart.md` for the full org tree. Count agents by status:
- Active: N
- Pending approval: N
- Terminated: N

## 3. Task Summary
Count files across all agents:
- `org/agents/*/tasks/active/*.md` → Active tasks: N
- `org/agents/*/tasks/backlog/*.md` → Backlog: N
- `org/agents/*/tasks/done/*.md` → Completed (all time): N

## 4. Pending Approvals
Count files in `org/board/approvals/` where frontmatter `status: pending`.
List each with: ID, type, proposed by, date.

## 5. Budget
Read `org/budgets/overview.md` for:
- Total budget, spent, remaining, percentage
- Any agents over 80% (WARNING)
- Currency from config.md

## 6. Recent Activity
Show last 10 lines of `org/board/audit-log.md`.

## 7. Active Threads
Count active threads in `org/threads/` (all subdirectories, where `status: active`).

## Present as Dashboard Summary

```
=== {ORG_NAME} Status ===
Language: {LANG} | Currency: {CURR} | Oversight: {LEVEL}

Agents: {N_ACTIVE} active, {N_PENDING} pending, {N_TERMINATED} terminated
Tasks:  {N_ACTIVE} active, {N_BACKLOG} backlog, {N_DONE} done
Budget: {SPENT}/{TOTAL} {CURR} ({PCT}%) — {STATUS}
Approvals: {N} pending
Threads: {N} active

{Orgchart tree}

Pending Approvals:
{table of pending items, or "None"}

Recent Activity:
{last 10 audit entries}
```
