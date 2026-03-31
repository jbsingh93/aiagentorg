---
name: escalate
description: "Escalate an issue UP the chain-of-command. Always goes to the direct supervisor — never sideways or down. Each level can resolve or escalate further. Board escalation writes to org/board/approvals/."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent] [issue-description] — or omit for interactive"
---

# Escalate Issue Through Chain-of-Command

## Rules
- Escalation ALWAYS goes UP one level: agent → their direct supervisor
- Cannot skip levels (worker cannot escalate directly to CEO — must go through manager)
- Each level can resolve the issue or escalate further up
- If escalation reaches the board: write to `org/board/approvals/` as a decision request

## Step 1: Identify the escalating agent and issue
If `$ARGUMENTS` provided, parse agent ID and issue description.
If not, ask: Who is escalating? What is the issue? What has already been tried?

## Step 2: Find the supervisor
1. Read `org/orgchart.md`
2. Find the agent's direct supervisor (the node one level above in the tree)
3. If the agent reports to `board`: this is a board-level escalation (Step 4)

## Step 3: Create escalation in thread
1. Find or create a thread in the appropriate department folder under `org/threads/`
2. Append escalation message:
   ```
   ---
   ### [MSG-{YYYYMMDD}-{HHMMSS}-{agent}] {TIMESTAMP} — {EMOJI} {AGENT_TITLE} → {EMOJI} {SUPERVISOR_TITLE} [escalation]

   **ESCALATION**

   **Issue:** {ISSUE_DESCRIPTION}
   **What I've tried:** {WHAT_AGENT_ALREADY_TRIED}
   **What I need:** {DECISION_OR_ACTION_NEEDED}
   **Urgency:** {HIGH / MEDIUM / LOW}
   **Related task:** {TASK_REF_IF_ANY}
   ```
3. Send notification to supervisor's inbox
4. Update thread frontmatter

## Step 4: Board-level escalation
If the escalation reaches the board (CEO escalates, or chain reaches top):

Write to `org/board/approvals/escalation-{topic-slug}-{YYYYMMDD}.md`:
```markdown
---
id: escalation-{topic-slug}-{YYYYMMDD}
type: escalation
proposed_by: {AGENT_WHO_ESCALATED}
proposed_date: {NOW_ISO8601}
status: pending
decided_by:
decided_date:
decision_reason:
---

## Escalation: {ISSUE_TITLE}

### Escalation Chain
- Originated from: @{ORIGINAL_AGENT}
- Escalated through: @{EACH_LEVEL_IN_CHAIN}
- Reached board: {NOW}

### Issue
{FULL_DESCRIPTION_WITH_CONTEXT}

### What Has Been Tried
{ACTIONS_ALREADY_TAKEN_AT_EACH_LEVEL}

### Decision Needed
{WHAT_THE_BOARD_MUST_DECIDE}

### Recommended Action
{IF_ANY_AGENT_IN_THE_CHAIN_HAS_A_RECOMMENDATION}
```

Also send thread message in `org/threads/executive/` and notification to board.

## Step 5: Confirm
"Issue escalated from @{agent} to @{supervisor}: {issue_summary}"
