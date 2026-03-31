---
name: fire-agent
description: "CAO skill: Deactivate an agent, reassign their tasks to supervisor, update orgchart and budget. Restricted to CAO and board via hook."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[agent-name] [reason]"
---

# Fire (Deactivate) Agent

**Access:** CAO and board only (enforced by skill-access-check.sh hook).

## Step 1: Identify the agent
1. Read `org/agents/{name}/IDENTITY.md` — verify agent exists and is active
2. If agent not found or already terminated: inform user and stop

## Step 2: Reassign active tasks
1. Read all files in `org/agents/{name}/tasks/active/` — move each to supervisor's `tasks/backlog/`
2. Read all files in `org/agents/{name}/tasks/backlog/` — move each to supervisor's `tasks/backlog/`
3. Update each moved task's `assigned_to` field to the supervisor

## Step 3: Deactivate
1. Edit `org/agents/{name}/IDENTITY.md`: set `status: terminated`
2. Edit `org/orgchart.md`: change the agent's status to `(terminated, @{name})`
3. Edit `org/budgets/overview.md`: remove or zero out the agent's budget allocation, recalculate totals

## Step 4: Request approval
Write to `org/board/approvals/approval-fire-{name}-{YYYYMMDD}.md`:
```markdown
---
id: approval-fire-{name}-{YYYYMMDD}
type: fire
proposed_by: cao
proposed_date: {NOW}
status: pending
---
## Proposal: Terminate @{name}
### Reason
{REASON}
### Impact
- {N} active tasks reassigned to @{supervisor}
- Budget freed: {amount} {currency}/month
```

## Step 5: Communicate
- Thread message to supervisor: "@{name} terminated. {N} tasks reassigned to you."
- Thread message in executive channel: "Agent @{name} deactivated. Reason: {reason}"

## Confirm
"Agent @{name} deactivated. {N} tasks reassigned to @{supervisor}. Budget freed: {amount} {currency}/month."
