---
name: budget-check
description: "Check budget status for an agent, department, or the entire org. Shows allocation, spending, remaining balance, and warnings for agents approaching their limit."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Glob, Grep
argument-hint: "[agent-name | org] — or omit for org-wide overview"
---

# Budget Check

## Step 1: Determine scope
- If `$ARGUMENTS` is an agent name: show that agent's budget
- If `$ARGUMENTS` is "org" or omitted: show org-wide budget

## Step 2: Read budget data
1. Read `org/config.md` — extract `currency` field (ISO 4217 code)
2. Read `org/budgets/overview.md` — extract frontmatter totals and per-agent table
3. Read `org/budgets/spending-log.md` — extract last 10 transactions

## Step 3: Present results

### Org-wide view:
```
Budget Overview — {ORG_NAME}
Currency: {CURRENCY}
Period: {PERIOD_START} to {PERIOD_END}

Total Budget:     {TOTAL} {CURRENCY}
Allocated:        {ALLOCATED} {CURRENCY} ({PCT}%)
Spent:            {SPENT} {CURRENCY} ({PCT}%)
Remaining:        {REMAINING} {CURRENCY}

Per Agent:
| Agent | Role | Allocated | Spent | Remaining | % Used | Status |
| --- | --- | --- | --- | --- | --- | --- |
{rows from overview.md}

Status legend: OK (<80%), WARNING (80-99%), EXHAUSTED (100%)

Last 5 Transactions:
| Time | Agent | Action | Cost |
{last 5 rows from spending-log.md}

Warnings:
{List any agents over 80% with specific alert}
```

### Single agent view:
```
Budget — @{AGENT} ({TITLE})
Model: {MODEL}
Allocated: {X} {CURRENCY}/month
Spent: {Y} {CURRENCY} ({PCT}%)
Remaining: {Z} {CURRENCY}
Status: {OK / WARNING / EXHAUSTED}

Recent Transactions:
{Last 5 entries for this agent from spending-log.md}
```
