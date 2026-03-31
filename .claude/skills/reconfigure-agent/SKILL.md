---
name: reconfigure-agent
description: "CAO skill: Modify an agent's SOUL, INSTRUCTIONS, HEARTBEAT, tools, access, or model. Follows master-gpt-prompter for any rewritten files. Restricted to CAO and board."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent-name] [what-to-change] — or omit for interactive"
---

# Reconfigure Agent

**Access:** CAO and board only (enforced by skill-access-check.sh hook).
**CRITICAL:** If rewriting SOUL.md, INSTRUCTIONS.md, or HEARTBEAT.md: read `.claude/skills/master-gpt-prompter/SKILL.md` first.

## Step 1: Identify what to change
If `$ARGUMENTS` provided: parse agent name and change description.
If not, ask: Which agent? What needs to change? Why?

## Step 2: Read current configuration
Read the agent's workspace:
- `org/agents/{name}/SOUL.md`
- `org/agents/{name}/IDENTITY.md`
- `org/agents/{name}/INSTRUCTIONS.md`
- `org/agents/{name}/HEARTBEAT.md`
- `.claude/agents/{name}.md`

## Step 3: Make changes
Depending on what's requested:

| Change Type | Files to Edit |
|------------|---------------|
| **Add/remove tools** | IDENTITY.md `tools` list + `.claude/agents/{name}.md` |
| **Change data access** | IDENTITY.md `access_read`/`access_write` lists |
| **Behavior change** | SOUL.md and/or INSTRUCTIONS.md (follow master-gpt-prompter) |
| **Heartbeat change** | HEARTBEAT.md |
| **Model change** | IDENTITY.md `model` + `.claude/agents/{name}.md` frontmatter |
| **Role/title change** | IDENTITY.md `title` + orgchart.md |
| **Reporting line change** | IDENTITY.md `reports_to` + orgchart.md (move in tree) |

## Step 4: Log the change
Write to `org/board/approvals/approval-reconfigure-{name}-{YYYYMMDD}.md`:
```markdown
---
id: approval-reconfigure-{name}-{YYYYMMDD}
type: reconfigure
proposed_by: cao
proposed_date: {NOW}
status: pending
---
## Reconfiguration: @{name}
### Changes Made
{List each field changed with before/after}
### Reason
{WHY this change was needed}
```

## Step 5: Communicate
- Thread message to the agent: "Your configuration has been updated: {summary}"
- Thread message to their supervisor: "@{name} reconfigured: {summary}"

## Confirm
"Agent @{name} reconfigured: {summary of changes}"
