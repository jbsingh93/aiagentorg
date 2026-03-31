# Remaining Skill Specifications, Rules Files, Agent Init Guide & Edge Cases

**Date:** 2026-03-31
**Purpose:** Complete SKILL.md bodies for all 9 unspecified skills, plus .claude/CLAUDE.md, .claude/rules/ content, and edge case handling. After this document, ALL components for Phases 1-4 are fully specified.

---

## PART 1: NINE MISSING SKILL BODIES

---

### Skill: `/delegate`

**File:** `.claude/skills/delegate/SKILL.md`

```yaml
---
name: delegate
description: "Create a task for a subordinate and notify them via thread. Validates chain-of-command before delegating."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[assignee] [task-title] — or omit for interactive mode"
---

# Delegate Task to Subordinate

## Step 1: Determine delegation parameters
If `$ARGUMENTS` provided, parse assignee and task title.
If not, ask the user:
- Who should this be delegated to? (agent ID)
- What is the task? (title and description)
- What priority? (critical/high/medium/low)
- What deadline? (date or "none")
- Which initiative does this support? (check org/initiatives/)

## Step 2: Validate chain-of-command
1. Read `org/orgchart.md`
2. Confirm the assignee reports to the assigning agent (or is a subordinate of a subordinate for CEO)
3. If the assignee does NOT report to the assigner: BLOCK and suggest the correct route
   - "You cannot delegate to @seo-agent directly. Delegate to @marketing-manager instead."
4. Confirm the assignee status is `active` (not terminated, paused, or pending-approval)

## Step 3: Generate task ID
1. Read existing files in the assignee's `tasks/backlog/` directory
2. Find the highest task number for today's date: `task-{YYYYMMDD}-NNN`
3. Increment by 1. If none exist, start at 001.

## Step 4: Create the task file
Write to `org/agents/{assignee}/tasks/backlog/task-{YYYYMMDD}-{NNN}.md`:

```markdown
---
id: task-{YYYYMMDD}-{NNN}
title: {TASK_TITLE}
priority: {PRIORITY}
status: backlog
assigned_to: {ASSIGNEE}
assigned_by: {ASSIGNER}
initiative: {INITIATIVE_SLUG}
created: {NOW_ISO8601}
started:
completed:
deadline: {DEADLINE_OR_EMPTY}
estimated_cost_usd:
---

## Description
{TASK_DESCRIPTION}

## Acceptance Criteria
{CRITERIA — if not provided, generate reasonable criteria from the description}

## Context
Ref: org/initiatives/{INITIATIVE_SLUG}.md
Reports to: @{ASSIGNER}

## Results
_(filled in by the assigned agent upon completion)_
```

## Step 5: Communicate via thread
1. Determine the correct thread:
   - If an existing thread covers this topic: append to it
   - If new topic: create `org/threads/{department}/thread-{topic-slug}-{YYYYMMDD}.md`
2. Append a message block:
   ```
   ---
   ### [MSG-{YYYYMMDD}-{HHMMSS}-{assigner}] {TIMESTAMP} — {EMOJI} {ASSIGNER} → {EMOJI} {ASSIGNEE} [directive]
   
   Task delegated: {TASK_TITLE}
   Task file: org/agents/{assignee}/tasks/backlog/task-{ID}.md
   Priority: {PRIORITY}
   Deadline: {DEADLINE}
   Initiative: {INITIATIVE}
   
   {BRIEF CONTEXT OR INSTRUCTIONS}
   ```
3. Update thread frontmatter: `last_activity`, `message_count`

## Step 6: Send notification
Write lightweight notification to `org/agents/{assignee}/inbox/notif-{YYYYMMDD}-{HHMMSS}-{assigner}.md`

## Step 7: Confirm
Tell the user: "Task {ID} delegated to @{assignee}: {title}"
```

---

### Skill: `/escalate`

**File:** `.claude/skills/escalate/SKILL.md`

```yaml
---
name: escalate
description: "Escalate an issue UP the chain-of-command. Always goes to direct supervisor. Never sideways or down."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent] [issue-description] — or omit for interactive"
---

# Escalate Issue Through Chain-of-Command

## Rules
- Escalation ALWAYS goes UP one level: agent → their direct supervisor
- Cannot skip levels (worker cannot escalate directly to CEO)
- Each level can resolve or escalate further
- Board escalation writes to org/board/approvals/ as a decision request

## Step 1: Identify the escalating agent and issue
If `$ARGUMENTS` provided, parse agent and issue.
If not, ask: Who is escalating? What is the issue?

## Step 2: Find the supervisor
1. Read `org/orgchart.md`
2. Find the agent's direct supervisor (one level up)
3. If agent reports to `board`: write to `org/board/approvals/` instead

## Step 3: Create escalation in thread
1. Find or create a thread in the appropriate department folder
2. Append escalation message:
   ```
   ---
   ### [MSG-{YYYYMMDD}-{HHMMSS}-{agent}] {TIMESTAMP} — {EMOJI} {AGENT} → {EMOJI} {SUPERVISOR} [escalation]
   
   **ESCALATION**
   
   Issue: {ISSUE_DESCRIPTION}
   What I've tried: {WHAT_AGENT_TRIED}
   What I need: {DECISION_OR_ACTION_NEEDED}
   Urgency: {HIGH/MEDIUM/LOW}
   Related task: {TASK_REF_IF_ANY}
   ```

## Step 4: If escalating to board
Write to `org/board/approvals/escalation-{topic}-{YYYYMMDD}.md`:
```markdown
---
id: escalation-{topic}-{YYYYMMDD}
type: escalation
proposed_by: {AGENT_CHAIN}
proposed_date: {NOW}
status: pending
---
## Escalation: {ISSUE}
### Chain
- Originated from: @{ORIGINAL_AGENT}
- Escalated through: @{EACH_LEVEL}
### Issue
{FULL_DESCRIPTION}
### Decision Needed
{WHAT_BOARD_MUST_DECIDE}
```

## Step 5: Send notification to supervisor's inbox

## Step 6: Confirm
"Issue escalated from @{agent} to @{supervisor}: {issue_summary}"
```

---

### Skill: `/report`

**File:** `.claude/skills/report/SKILL.md`

```yaml
---
name: report
description: "Write a status report for an agent. Summarizes tasks, decisions, budget, and blockers."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent-name] — or omit to report for all agents"
---

# Write Status Report

## Step 1: Determine which agent
If `$ARGUMENTS` provided, report for that agent.
If not, ask: Which agent should write a report? Or "all" for org-wide summary.

## Step 2: Gather data for the agent
Read these files:
1. `org/agents/{name}/tasks/active/` — count and list active tasks
2. `org/agents/{name}/tasks/done/` — tasks completed today (check frontmatter `completed` date)
3. `org/agents/{name}/tasks/backlog/` — pending tasks
4. `org/agents/{name}/activity/current-state.md` — current state snapshot
5. `org/agents/{name}/activity/{today}.md` — today's activity stream
6. `org/budgets/overview.md` — agent's budget row
7. `org/threads/{department}/` — recent thread activity involving this agent

## Step 3: Write the report
Write to `org/agents/{name}/reports/daily-{YYYY-MM-DD}.md`:

```markdown
---
agent: {AGENT_NAME}
date: {TODAY}
heartbeat_cycles: {COUNT}
---

# Daily Report — {AGENT_TITLE} — {TODAY}

## Summary
{1-2 sentence overview synthesized from the gathered data}

## Completed
{List tasks moved to done/ today, with results}

## In Progress
{List tasks in active/, with current step from current-state.md}

## Backlog
{Count of tasks in backlog/}

## Budget
{Agent's row from budget overview: spent / allocated}

## Blockers
{Any blockers from current-state.md, or "None"}

## Key Decisions
{Decisions from current-state.md Reasoning Trace, or "None"}

## Escalations
{Any escalation messages sent today, or "None"}
```

## Step 4: If "all" — write org-wide summary
Aggregate all agent reports into a board-facing summary.
```

---

### Skill: `/budget-check`

**File:** `.claude/skills/budget-check/SKILL.md`

```yaml
---
name: budget-check
description: "Check budget status for an agent, department, or the entire org. Shows allocation, spending, and remaining."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Glob, Grep
argument-hint: "[agent-name|department|org] — or omit for org overview"
---

# Budget Check

## Step 1: Determine scope
If `$ARGUMENTS` is an agent name: show that agent's budget.
If `$ARGUMENTS` is "org" or omitted: show org-wide budget.

## Step 2: Read budget data
1. Read `org/config.md` for currency code
2. Read `org/budgets/overview.md` for allocations and spending
3. Read `org/budgets/spending-log.md` for recent transactions

## Step 3: Calculate and present
For org-wide:
```
Budget Overview — {ORG_NAME}
Currency: {CURRENCY}
Period: {PERIOD_START} to {PERIOD_END}

Total Budget:     {TOTAL} {CURRENCY}
Allocated:        {ALLOCATED} {CURRENCY} ({PCT}%)
Spent:            {SPENT} {CURRENCY} ({PCT}%)
Remaining:        {REMAINING} {CURRENCY} ({PCT}%)

Per Agent:
| Agent | Allocated | Spent | Remaining | % Used |
| ...   | ...       | ...   | ...       | ...    |

Last 5 Transactions:
| Time | Agent | Cost | Action |
| ...  | ...   | ...  | ...    |

Warnings:
{List any agents over 80% of allocation}
```

For single agent:
```
Budget — @{AGENT}
Allocated: {X} {CURRENCY}/month
Spent: {Y} {CURRENCY} ({PCT}%)
Remaining: {Z} {CURRENCY}
Status: {OK / WARNING (>80%) / EXHAUSTED (100%)}
```
```

---

### Skill: `/hire-agent`

**File:** `.claude/skills/hire-agent/SKILL.md`

```yaml
---
name: hire-agent
description: "CAO skill: Design and create a new agent with full workspace. Consults manager, follows master-gpt-prompter. Restricted to CAO and board via hook."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[role-description] — describe the agent needed"
---

# Hire New Agent

**Access:** CAO and board only (enforced by skill-access-check.sh hook).

**CRITICAL:** Before writing ANY agent file, read `.claude/skills/master-gpt-prompter/SKILL.md` and its references. All SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md are LLM prompts — they must be maximally potent.

## Step 1: Understand the request
If `$ARGUMENTS` provided, use as role description.
If not, ask: What role is needed and why?

## Step 2: Validate feasibility
1. Read `org/orgchart.md` — is this role redundant?
2. Read `org/budgets/overview.md` — is there budget for a new agent?
3. Read `org/config.md` — what model tier? what oversight level?
4. If budget insufficient or role redundant: explain why and suggest alternatives.

## Step 3: Consult the future manager
1. Determine who the new agent will report to
2. Send a consultation message via thread to that manager:
   - What tools does the new agent need?
   - What data access?
   - What key responsibilities?
3. If manager doesn't exist yet (first hire for a department): consult CEO instead

## Step 4: Design the agent
Read `.claude/skills/master-gpt-prompter/SKILL.md` and apply ALL 15 principles.

Design:
- **name:** kebab-case, unique, max 64 chars, descriptive (e.g., `seo-agent`)
- **title:** Human-readable (e.g., "SEO Specialist")
- **model:** From config.md (manager_model or worker_model default)
- **SOUL.md:** Behavioral philosophy using domain-specific vocabulary. Activate the model's deepest expertise for this role.
- **IDENTITY.md:** Complete metadata including tools (least privilege) and access lists (chain-of-command)
- **INSTRUCTIONS.md:** Full operating manual — context loading, procedures, constraints, communication rules, tool/data request instructions, observability requirements (current-state.md, threads), error recovery
- **HEARTBEAT.md:** Ordered checklist for periodic runs
- **MEMORY.md:** Initial knowledge from the org context

## Step 5: Create workspace
```bash
mkdir -p org/agents/{name}/memory org/agents/{name}/tasks/backlog org/agents/{name}/tasks/active org/agents/{name}/tasks/done org/agents/{name}/inbox org/agents/{name}/activity org/agents/{name}/reports
```

Then write all workspace files.

## Step 6: Create agent definition
Write `.claude/agents/{name}.md` with frontmatter (name, description, model, maxTurns) and initialization instructions pointing to the workspace.

## Step 7: Update orgchart
Add the new agent under their supervisor in `org/orgchart.md` with `status: pending-approval`.

## Step 8: Request approval
Check `org/config.md` `oversight_level`:
- `approve-everything`: Write proposal to `org/board/approvals/approval-hire-{name}-{YYYYMMDD}.md`
- `approve-strategy-only`: Auto-approve workers, propose managers to board
- `hands-off`: Auto-approve all (set status to `active` immediately, update budget)

## Step 9: Communicate
- Send thread message to the requesting agent: "Agent @{name} proposed/created"
- Send notification to the supervisor: "New report assigned to you: @{name}"
- If approval needed: notify board via thread in `org/threads/executive/`

## Step 10: Update budget
Add a row for the new agent in `org/budgets/overview.md` with allocated budget.
```

---

### Skill: `/fire-agent`

**File:** `.claude/skills/fire-agent/SKILL.md`

```yaml
---
name: fire-agent
description: "CAO skill: Deactivate an agent, reassign tasks, update orgchart. Restricted to CAO and board."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[agent-name] [reason]"
---

# Fire (Deactivate) Agent

**Access:** CAO and board only.

## Step 1: Identify the agent
Read `org/agents/{name}/IDENTITY.md`. Verify the agent exists and is active.

## Step 2: Reassign active tasks
1. Read all files in `org/agents/{name}/tasks/active/`
2. For each active task: move to the agent's supervisor's `tasks/backlog/`
3. Read all files in `org/agents/{name}/tasks/backlog/`
4. For each backlog task: move to supervisor's `tasks/backlog/`

## Step 3: Deactivate
1. Edit `org/agents/{name}/IDENTITY.md`: set `status: terminated`
2. Edit `org/orgchart.md`: change status to `terminated`
3. Remove budget allocation from `org/budgets/overview.md`

## Step 4: Request approval
Write to `org/board/approvals/approval-fire-{name}-{YYYYMMDD}.md`

## Step 5: Communicate
- Thread message to the supervisor: "@{name} has been terminated. Active tasks reassigned to you."
- Thread message in executive channel: "Agent @{name} deactivated. Reason: {REASON}"

## Step 6: Confirm
"Agent @{name} deactivated. {N} tasks reassigned to @{supervisor}."
```

---

### Skill: `/reconfigure-agent`

**File:** `.claude/skills/reconfigure-agent/SKILL.md`

```yaml
---
name: reconfigure-agent
description: "CAO skill: Modify an agent's SOUL, INSTRUCTIONS, HEARTBEAT, tools, or access. Restricted to CAO and board."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent-name] [what-to-change]"
---

# Reconfigure Agent

**Access:** CAO and board only.
**CRITICAL:** Read `.claude/skills/master-gpt-prompter/SKILL.md` before rewriting any agent files.

## Step 1: Identify what to change
If `$ARGUMENTS` provided, parse agent and change description.
If not, ask: Which agent? What needs to change? Why?

## Step 2: Read current configuration
Read the agent's full workspace: SOUL.md, IDENTITY.md, INSTRUCTIONS.md, HEARTBEAT.md

## Step 3: Make changes
Depending on what's requested:
- **Tools change:** Edit IDENTITY.md `tools` list + edit `.claude/agents/{name}.md`
- **Access change:** Edit IDENTITY.md `access_read`/`access_write` lists
- **Behavior change:** Edit SOUL.md and/or INSTRUCTIONS.md (follow master-gpt-prompter)
- **Heartbeat change:** Edit HEARTBEAT.md
- **Model change:** Edit IDENTITY.md `model` + `.claude/agents/{name}.md` frontmatter
- **Role change:** Edit IDENTITY.md `title`, update orgchart

## Step 4: Log the change
Write to `org/board/approvals/approval-reconfigure-{name}-{YYYYMMDD}.md`

## Step 5: Communicate
Thread message to the agent and their supervisor about what changed and why.

## Step 6: Confirm
"Agent @{name} reconfigured: {summary of changes}"
```

---

### Skill: `/review-work`

**File:** `.claude/skills/review-work/SKILL.md`

```yaml
---
name: review-work
description: "Manager skill: Review a subordinate's completed task. Provide feedback, approve, or request revisions."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent-name] [task-id] — or omit to review latest completed tasks"
---

# Review Subordinate Work

## Step 1: Find completed tasks to review
If `$ARGUMENTS` specifies agent and task: review that specific task.
If only agent specified: list all tasks in their `tasks/done/` from today.
If omitted: scan all subordinates' `tasks/done/` for unreviewed tasks.

## Step 2: Read the completed task
1. Read the task file in `org/agents/{subordinate}/tasks/done/{task-id}.md`
2. Read the Results section
3. If the task references deliverables (reports, files), read those too

## Step 3: Evaluate against acceptance criteria
Compare the Results against the Acceptance Criteria checklist in the task file.
- All criteria met? → APPROVED
- Some criteria missing? → REVISIONS NEEDED
- Quality insufficient? → REVISIONS NEEDED with specific feedback

## Step 4: Provide feedback via thread
Append to the relevant department thread:
```
---
### [MSG-...] — Manager → Subordinate [discussion]

**REVIEW: {task-title}**
Status: APPROVED / REVISIONS NEEDED

{Specific feedback — what was good, what needs improvement}
{If revisions needed: exact changes required}
```

## Step 5: If revisions needed
1. Move the task BACK to `tasks/active/` (not backlog — it's already started)
2. Edit the task: update status to `active`, clear `completed` date
3. Add revision notes to the task file

## Step 6: Confirm
"Review complete for @{subordinate} task {id}: {APPROVED/REVISIONS NEEDED}"
```

---

### Skill: `/task`

**File:** `.claude/skills/task/SKILL.md`

```yaml
---
name: task
description: "Task management: assign, list, view, or move tasks. Works across agents."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[assign|list|view|move] [args] — or omit for interactive"
---

# Task Management

## Subcommands

### `assign` — Create and assign a task (alias for /delegate)
Same workflow as the `/delegate` skill. Invoke `/delegate` internally.

### `list` — List tasks
If `$ARGUMENTS` contains an agent name: list that agent's tasks.
If `$ARGUMENTS` contains "all": list all tasks across all agents.
If omitted: list all tasks.

For each task, show:
```
| ID | Title | Agent | Status | Priority | Deadline |
```

Read from: `org/agents/*/tasks/backlog/*.md`, `org/agents/*/tasks/active/*.md`, `org/agents/*/tasks/done/*.md`
Parse frontmatter for fields.

### `view` — View a specific task
Read the task file and display full content including Results.

### `move` — Move a task between states
`/task move {task-id} {backlog|active|done}`

1. Find the task file across all agents' task directories
2. Move it to the target status directory
3. Update frontmatter: `status`, `started`/`completed` timestamps
4. Communicate the change in the relevant thread
```

---

## PART 2: RULES FILES

---

### `.claude/rules/governance.md`

```markdown
# Governance Rules

These rules are loaded into every Claude Code session and apply to ALL agents.

## Delegation Chain
- Every task MUST trace back to an initiative in org/initiatives/
- Delegation follows the reporting chain in org/orgchart.md — no skip-level delegation
- Cross-department coordination goes through department managers, not directly between workers
- The board has ultimate authority over all decisions

## Budget
- Every agent has an allocated budget in org/budgets/overview.md
- Agents MUST NOT exceed their budget allocation
- Budget changes require board approval (unless oversight_level is hands-off)
- The heartbeat script enforces per-run spending caps via --max-budget-usd

## Audit & Logging
- Every file operation is logged by the activity-logger.sh hook — this is automatic and cannot be disabled
- Agents MUST maintain their activity/current-state.md — the session-end hook enforces this
- Agents MUST communicate in threads (org/threads/) — the session-end hook enforces this
- The org-wide audit log (org/board/audit-log.md) is append-only and immutable

## Approvals
- Agent creation/termination requires approval per the oversight_level in org/config.md
- Board decisions are written to org/board/decisions/ — only the board can write there
- Pending proposals go to org/board/approvals/ — the CAO creates these, the board resolves them

## Agent Definitions
- Only the CAO and board can create or modify .claude/agents/*.md files
- Only the CAO and board can use the /hire-agent, /fire-agent, and /reconfigure-agent skills
- These restrictions are enforced by hooks (require-cao-or-board.sh, skill-access-check.sh)

## Communication
- All inter-agent communication happens through threads in org/threads/
- Messages follow chain-of-command rules enforced by message-routing-check.sh
- Workers cannot message the CEO or board directly — they must escalate through their manager
- Only CEO and board can send org-wide broadcasts or urgent messages
```

---

### `.claude/rules/structured-autonomy.md`

```markdown
# Structured Autonomy Rules

These rules define the boundaries of agent autonomy. Agents DO real work but within strict guardrails.

## Mandate
- Every agent operates within the scope defined in their INSTRUCTIONS.md
- Agents MUST NOT act outside their department or role scope
- All work must be tied to an assigned task or heartbeat checklist item
- No freelancing — if an agent identifies work that needs doing, they propose it (don't just do it)

## Self-Modification Prohibited
- Agents CANNOT modify their own SOUL.md, IDENTITY.md, or the .claude/agents/ definition
- Agents CANNOT grant themselves new tools or data access
- To change capabilities: create a request via org/threads/requests/

## Tool & Data Access
- Agents MUST only use tools listed in their IDENTITY.md
- Agents MUST only read/write files within their access_read/access_write lists
- The data-access-check.sh hook enforces this — unauthorized access is blocked
- To request new tools or data access: follow the request workflow in INSTRUCTIONS.md

## Communication Boundaries
- Agents communicate ONLY through threads and inbox notifications
- Message routing follows chain-of-command (message-routing-check.sh enforces this)
- No external communication (no API calls, web requests) unless explicitly granted the tools

## Observability
- Agents MUST maintain activity/current-state.md at all times (hook-enforced)
- Agents MUST report actions in relevant threads (hook-enforced at session end)
- The activity stream is hook-generated and cannot be disabled

## Decision Authority
- Workers execute tasks — they do not make strategic decisions
- Managers delegate and coordinate — they propose but don't decide strategy
- CEO decides strategy within board mandate — escalates beyond it
- CAO manages the workforce — consults with managers before changes
- Board has final authority on all matters

## Error Handling
- Agents MUST NOT silently ignore errors
- Errors are logged in the activity stream and escalated to the supervisor
- Agents do not retry failed actions more than twice — escalate instead

## Agent Teams
- Agent Teams (experimental) are available ONLY for exceptional cases
- Must be proposed to and approved by the board before activation
- Normal heartbeat orchestration handles 95%+ of coordination needs
```

---

## PART 3: `.claude/CLAUDE.md` — Agent Initialization Guide

**File:** `.claude/CLAUDE.md`

```markdown
# Agent Initialization Guide

This file is loaded by Claude Code into every session — both the board (human) and every agent. It tells you how to initialize yourself and operate within this AI agent organisation.

## If You Are an Agent

You are an agent in an AI organisation managed by OrgAgent. To initialize:

1. **Determine your identity.** Your agent name matches your `.claude/agents/{name}.md` definition. Your workspace is at `org/agents/{name}/`.

2. **Load your context in this order:**
   - `org/alignment.md` — the organisation's mission, values, and principles
   - `org/config.md` — organisation settings (language, currency, tone, oversight level)
   - `org/agents/{name}/SOUL.md` — WHO you are (behavioral philosophy)
   - `org/agents/{name}/IDENTITY.md` — your role, tools, data access, skills
   - `org/agents/{name}/INSTRUCTIONS.md` — HOW you operate (procedures, constraints)
   - `org/agents/{name}/HEARTBEAT.md` — your periodic checklist (if this is a heartbeat run)
   - `org/agents/{name}/MEMORY.md` — your persistent knowledge
   - `org/orgchart.md` — the current org structure
   - `org/rules/custom-rules.md` — custom rules (if the file exists)

3. **Read the rules.** The files in `.claude/rules/` define governance and autonomy boundaries. Follow them.

4. **Maintain observability.** You MUST keep `org/agents/{name}/activity/current-state.md` updated at all times. Hooks will remind you and block your session end if you forget.

5. **Communicate via threads.** All messages go through `org/threads/`. Never write directly to another agent's workspace except task assignments and inbox notifications. The message-routing hook enforces chain-of-command.

6. **If you need a tool or data you don't have:** Do NOT attempt to access it. Create a request in `org/threads/requests/` and send a notification to the CAO or your supervisor. See your INSTRUCTIONS.md for the exact procedure.

7. **All prompts in this system follow the master-gpt-prompter principles.** When writing any text that an LLM will read (task descriptions, messages, reports), be precise, use domain vocabulary, and eliminate ambiguity.

## If You Are the Board (Human)

You are the human operator. Use skills to manage your organisation:
- `/onboard` — create a new organisation
- `/status` — see org overview
- `/heartbeat` — run a heartbeat cycle
- `/approve` — approve or reject pending proposals
- `/dashboard` — start the GUI
- Or just ask in natural language — Claude understands the org context.

## Environment

- `ORGAGENT_CURRENT_AGENT` — set by heartbeat.sh to identify the running agent. If unset, you are the board.
- `ORGAGENT_ORG_DIR` — path to the org state directory (default: `org`)
- All agent output must be in the language specified in `org/config.md`
- All monetary values use the currency from `org/config.md`
```

---

## PART 4: EDGE CASE HANDLING

### Edge Case 1: First Heartbeat (No Threads, No Tasks)

**Behavior:** On the first heartbeat after onboarding:
- CEO runs: finds no inbox messages, no tasks, no threads. CEO SHOULD:
  1. Read the initial initiatives in `org/initiatives/`
  2. Create the first threads in `org/threads/executive/`
  3. Send the first directive to CAO: "Review the org and propose initial hires"
  4. Create initial tasks for itself (strategic planning)
- CAO runs: finds CEO's message, begins org analysis

**Implementation:** The CEO's INSTRUCTIONS.md includes: "If this is the first heartbeat (no activity history exists), begin by reading all initiatives and creating an initial strategic plan."

**Hook safety:** `activity-logger.sh` creates the activity directory with `mkdir -p` before writing — handles missing directories.

### Edge Case 2: New Agent Hired Mid-Cycle

**Behavior:** If the CAO creates a new agent during Phase 4 of a heartbeat:
- The new agent does NOT run in the current cycle (heartbeat.sh already parsed the orgchart at the start)
- The new agent runs on the NEXT heartbeat cycle
- This is BY DESIGN — the heartbeat script parses orgchart once at the beginning

**Documentation:** Already in heartbeat.sh comments. No code change needed.

### Edge Case 3: Agent in Orgchart but Definition Missing

**Behavior:** If orgchart lists `@sales-agent (active)` but `.claude/agents/sales-agent.md` doesn't exist:
- `claude --agent sales-agent` will fail
- heartbeat.sh captures the error via `|| true` and logs it
- The activity-logger logs the failure to the org audit log

**Fix in heartbeat.sh:** Add a pre-check:
```bash
if [[ ! -f ".claude/agents/$agent_name.md" ]]; then
  echo "WARNING: Agent definition missing for $agent_name — skipping" >&2
  echo "| $(date -Iseconds) | SYSTEM | error | $agent_name | Agent definition missing |" >> "$ORG_DIR/board/audit-log.md"
  return
fi
```

### Edge Case 4: Running /onboard Twice

**Behavior:** MUST be prevented. Running onboarding on an existing org would overwrite all state.

**Fix in onboard SKILL.md:** Add a guard at the beginning:
```
## Pre-flight Check
Before starting the conversation, check if org/ already exists:
1. Check if `org/config.md` exists
2. If it does: STOP. Tell the user: "An organisation already exists in this directory ({ORG_NAME}). Running onboarding again would overwrite all existing data. If you want to start fresh, delete the org/ directory first."
3. Only proceed if org/ does not exist or is empty.
```

### Edge Case 5: Budget = 0

**Behavior:** If the user sets budget to 0:
- All agents get 0 allocated budget
- The `--max-budget-usd` flag still applies (set to 0)
- `claude --agent ceo -p "..." --max-budget-usd 0` would prevent any work

**Fix:** The onboarding skill should validate: "Your budget is 0. Agents will not be able to run heartbeats. Are you sure? (Note: a minimum of ~$5/month is needed for basic CEO + CAO heartbeats.)"

### Edge Case 6: Windows `date` Command Differences

**Fix:** Replace all `date -Iseconds` with `date -u +"%Y-%m-%dT%H:%M:%S"` which works on both GNU and Git Bash. Replace `bc -l` with `jq -n` for arithmetic:
```bash
# Instead of: echo "$a + $b" | bc -l
# Use: jq -n "$a + $b"
```

### Edge Case 7: Concurrent Thread Writes (Parallel Heartbeat Phases)

**Behavior:** Two managers running in parallel both append to the same thread file.

**Risk:** Interleaved writes. Unlikely with short append operations but possible.

**Mitigation:** Each message is a complete block (`---\n### [MSG-...]\n...\n`). Even if interleaved, the thread remains parseable because message blocks are self-contained. Worst case: messages appear out of timestamp order (cosmetic issue).

### Edge Case 8: Activity Logger Hook Failure

**Fix:** The activity-logger.sh hook MUST exit 0 even on failure — it should never block the agent's work:
```bash
# At the end of activity-logger.sh:
exit 0  # ALWAYS allow — logging failure must not block agent work
```
This is already the case in the spec (doc 16).

---

## PART 5: COMPLETE SETTINGS.JSON (Copy-Paste Ready)

```json
{
  "permissions": {
    "allow": [
      "Read", "Write", "Edit", "Glob", "Grep",
      "Bash(date *)", "Bash(mkdir *)", "Bash(mv *)", "Bash(cp *)",
      "Bash(ls *)", "Bash(wc *)", "Bash(head *)", "Bash(tail *)",
      "Bash(claude *)", "Bash(node *)", "Bash(bash *)", "Bash(jq *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Write|Edit|Glob|Grep",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/data-access-check.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "if": "Write(org/board/decisions/*)|Edit(org/board/decisions/*)",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/require-board-approval.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "if": "Write(.claude/agents/*)|Edit(.claude/agents/*)",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/require-cao-or-board.sh" }]
      },
      {
        "matcher": "Skill",
        "if": "Skill(hire-agent)|Skill(fire-agent)|Skill(reconfigure-agent)",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/skill-access-check.sh" }]
      },
      {
        "matcher": "Write",
        "if": "Write(org/agents/*/inbox/*)",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/message-routing-check.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Read|Write|Edit|Glob|Grep|Bash",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/activity-logger.sh" }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/remind-state-update.sh" }]
      },
      {
        "matcher": "Write",
        "if": "Write(org/agents/*/tasks/*)",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/budget-check.sh" }]
      }
    ],
    "SubagentStart": [
      { "hooks": [{ "type": "command", "command": "bash scripts/hooks/log-agent-activation.sh" }] }
    ],
    "SubagentStop": [
      { "hooks": [{ "type": "command", "command": "bash scripts/hooks/log-agent-deactivation.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "bash scripts/hooks/require-state-and-communication.sh" }] }
    ]
  },
  "env": {
    "ORGAGENT_ORG_DIR": "org"
  }
}
```

---

## PART 6: COMPLETE PACKAGE.JSON (Copy-Paste Ready)

```json
{
  "name": "orgagent",
  "version": "1.0.0",
  "private": true,
  "description": "AI Agent Organisation — powered by Claude Code",
  "scripts": {
    "dashboard": "node gui/server.js",
    "heartbeat": "bash scripts/heartbeat.sh",
    "heartbeat:ceo": "bash scripts/heartbeat.sh ceo",
    "heartbeat:cao": "bash scripts/heartbeat.sh cao"
  },
  "dependencies": {
    "express": "^5.0.0",
    "marked": "^15.0.0",
    "gray-matter": "^4.0.3"
  }
}
```
