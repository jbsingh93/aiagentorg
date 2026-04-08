---
name: hire-agent
description: "CAO skill: Design and create a new agent with full workspace, consulting the future manager. Follows master-gpt-prompter principles for all agent files. Restricted to CAO and board via hook."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[role-description] — describe the agent role needed"
---

# Hire New Agent

**Access:** CAO and board only (enforced by skill-access-check.sh hook).

**CRITICAL:** Before writing ANY agent file (SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md), you MUST read `.claude/skills/master-gpt-prompter/SKILL.md` and its reference files. All agent workspace files are LLM prompts — they must be maximally potent, using domain-specific vocabulary, zero ambiguity, structured reasoning, and precise constraints.

## Step 1: Understand the request
If `$ARGUMENTS` provided, use as role description.
If not, ask: What role is needed? Why? What work will this agent do?

## Step 2: Validate feasibility
1. Read `org/orgchart.md` — is this role redundant? Does a similar agent already exist?
2. Read `org/budgets/overview.md` — is there unallocated budget for a new agent?
3. Read `org/config.md` — what model tier for this role? (`manager_model` or `worker_model`) What `oversight_level`?
4. If budget insufficient: explain and suggest alternatives (reconfigure existing agent, wait for budget cycle)
5. If role redundant: explain why and suggest reconfiguring the existing agent instead

## Step 3: Consult the future manager
1. Determine who the new agent will report to (from the request context or orgchart hierarchy)
2. If the manager exists and is active: send a consultation thread message asking:
   - What specific tools does the new agent need?
   - What data access is appropriate? (which directories?)
   - What are the key responsibilities and deliverables?
   - Any specific behavioral traits or constraints?
3. If no manager exists yet (first hire in a new department): consult CEO instead
4. Note: In automated/heartbeat mode, use defaults from config.md if consultation isn't possible in real-time

## Step 4: Design the agent
Read `.claude/skills/master-gpt-prompter/SKILL.md` and apply ALL its principles.

Design the complete agent:
- **name:** kebab-case, unique, max 64 chars, descriptive (e.g., `seo-agent`, `content-writer`)
- **title:** Human-readable role title (e.g., "SEO Specialist")
- **emoji:** Representative emoji for GUI display
- **model:** From config.md defaults (`manager_model` or `worker_model`)
- **department:** Which department this agent belongs to
- **reports_to:** Agent ID of the supervisor

Design the workspace files:
- **SOUL.md:** Behavioral philosophy using domain-specific vocabulary. Activate the model's deepest expertise for this role. 5-12 behavioral statements in second person.
- **IDENTITY.md:** Complete metadata including tools (principle of least privilege) and access_read/access_write lists (chain-of-command — own workspace + department shared + org basics). Include `.claude/system-reference.md` in access_read so the agent can learn about their environment. Include `org/knowledge/` in access_read so the agent can query the org-wide knowledge base.
- **INSTRUCTIONS.md:** Full operating manual with: context loading order (MUST start with `.claude/system-reference.md` as item 0 — the agent's LLM has no knowledge of Claude Code, tools, or OrgAgent without this), operating procedures, delegation rules (if manager), task management, reporting, escalation, communication rules, tool/access request instructions, observability requirements (current-state.md mandatory), error recovery, constraints
- **HEARTBEAT.md:** 8-11 ordered steps for periodic processing (urgent msgs → inbox → approvals → active tasks → backlog → subordinate review if manager → budget → report → memory update)
- **MEMORY.md:** Initial knowledge context from the org (org name, language, currency, relevant initiative, key facts). Include a note: "Read `.claude/system-reference.md` for complete documentation of your runtime environment, available tools, and how the OrgAgent system works." Also include: "Consult `org/knowledge/index.md` for the org-wide knowledge base before starting new research."

**CRITICAL:** Every new agent's context loading order in their INSTRUCTIONS.md MUST include `.claude/system-reference.md` as ITEM 0 (before org/alignment.md). Without this, the agent will not understand its tools, environment, or how to operate. The LLM powering the agent has no built-in knowledge of Claude Code, Playwright MCP, the thread system, or OrgAgent.

## Step 5: Create workspace
```bash
mkdir -p org/agents/{name}/memory org/agents/{name}/tasks/backlog org/agents/{name}/tasks/active org/agents/{name}/tasks/done org/agents/{name}/inbox org/agents/{name}/activity org/agents/{name}/reports
```

Then write all 5 workspace files (SOUL.md, IDENTITY.md, INSTRUCTIONS.md, HEARTBEAT.md, MEMORY.md).

## Step 6: Create agent definition
Write `.claude/agents/{name}.md` with:
- Frontmatter: name, description, model, maxTurns: 50
- Body: initialization instructions pointing to workspace, context loading order, execution rules

## Step 7: Update orgchart
Add the new agent to `org/orgchart.md` under their supervisor with `status: pending-approval`.

## Step 8: Update budget
Add a row for the new agent in `org/budgets/overview.md` with allocated budget (proportional to role tier).

## Step 9: Request approval
Check `org/config.md` `oversight_level`:
- `approve-everything`: Write proposal to `org/board/approvals/approval-hire-{name}-{YYYYMMDD}.md`
- `approve-strategy-only`: Auto-approve workers (set status: active immediately), write proposal for managers/executives
- `hands-off`: Auto-approve all (set status: active immediately)

Proposal file must include: role justification, tool list, access list, budget impact, reporting line, model tier.

## Step 10: Communicate
- Thread message in `org/threads/executive/`: "Proposed new agent @{name} ({title}) reporting to @{supervisor}"
- Notification to the supervisor: "New report being proposed: @{name}"
- If auto-approved: additional message confirming activation

## Confirm
"Agent @{name} ({title}) proposed/created. {Status: pending approval / active}. Budget allocated: {amount} {currency}/month."
