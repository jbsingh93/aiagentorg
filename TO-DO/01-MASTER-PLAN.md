# Master Plan: OrgAgent — Dynamic AI Agent Organisation Built on Claude Code

**Version:** 2.0 (Updated 2026-03-31)
**Status:** Final specification — ready for implementation

---

## Context

Build a **dynamic, self-organizing AI agent organisation** where Claude Code is the LLM backbone. The system is a **Claude Code project** — a directory of `.claude/` configuration files (agents, skills, hooks, rules) and `org/` state files. When a user opens Claude Code in this directory, it becomes the board interface. No separate CLI, no separate framework — just Claude Code.

**Key design principles:**
- Everything is a markdown file (filesystem = database)
- Claude Code IS the engine — every agent runs as `claude --agent <name>`
- Skills replace CLI commands — the user stays in Claude Code
- Onboarding wizard for deep alignment before any org starts
- Self-modifying: CAO literally writes new agent definition files
- Each agent = its own workspace with SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY
- Hooks enforce governance; skills define reusable workflows
- `/schedule` or `/loop` for automated heartbeats (Claude Code built-in)
- Distribution via `npx create-orgagent` (one command setup)

**Reference documents:**
- `09-ARCHITECTURE-DECISIONS.md` — all design decisions with reasoning
- `10-FILE-FORMAT-SPECIFICATIONS.md` — exact format for every file type
- `11-DISTRIBUTION-PLAN.md` — packaging and distribution plan
- `12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` — tool permissions, data access, request workflows
- `13-MASTER-PROMPTER-SKILL-SPEC.md` — prompt engineering meta-skill (full content)
- `14-ONBOARDING-SKILL-FULL-SPEC.md` — complete onboarding skill body (TODO)

**Critical cross-cutting concerns:**
- **Dynamic tool permissions** — CAO + manager determine tools per agent; agents can REQUEST new tools
- **Chain-of-command data access** — agents only see data relevant to their role; enforced by hooks
- **Currency is configurable** — set during onboarding (ISO 4217: USD, DKK, EUR, etc.), never hardcoded
- **All prompts optimized** — every LLM-facing text follows the master-gpt-prompter skill principles
- **Agent Teams** — available for no-brainer cases only; specified in board/executive/CAO context
- **User custom rules** — collected during onboarding, stored in org/rules/custom-rules.md

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    HUMAN (Board)                              │
│                                                               │
│  User's Claude Code session = Board interface                 │
│  Skills: /onboard, /heartbeat, /approve, /status, etc.       │
│  Natural language: "Run the CEO", "Approve the hire", etc.   │
│                                                               │
│  GUI Dashboard (optional): localhost:3000                      │
│  Scheduling: /loop or /schedule for automated heartbeats      │
└──────────────┬──────────────────────┬────────────────────────┘
               │ commands/approval     │ file read/write
               ▼                       ▼
┌─────────────────────────────────────────────────────────────┐
│                 GOVERNANCE LAYER                              │
│                                                               │
│  Hooks (in .claude/settings.json):                            │
│  - PreToolUse: board approval gates, CAO-only gates          │
│  - PostToolUse: audit logging, budget checking               │
│  - SubagentStart/Stop: agent activation logging              │
│  - Stop: post-cycle summary                                  │
│                                                               │
│  Rules (in .claude/rules/):                                   │
│  - governance.md: delegation chain, budget, audit rules       │
│  - structured-autonomy.md: agent constraints                  │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│              AGENT RUNTIME (Claude Code)                      │
│                                                               │
│  Each agent invoked as:                                       │
│  ORGAGENT_CURRENT_AGENT=<name> \                              │
│    claude --agent <name> -p "instruction" \                   │
│    --output-format json --max-budget-usd 5.00                 │
│                                                               │
│  ┌─────────┐  ┌─────────┐  ┌──────────────────────┐         │
│  │   CEO   │  │   CAO   │  │  Dynamic Agents...   │         │
│  │  (opus) │  │  (opus) │  │  (sonnet/haiku)      │         │
│  └────┬────┘  └────┬────┘  └──────────────────────┘         │
│       │            │                                          │
│  Each agent reads its workspace on startup:                   │
│  - SOUL.md (behavioral identity)                              │
│  - IDENTITY.md (name, role, status, tools, skills)            │
│  - INSTRUCTIONS.md (operating manual)                         │
│  - HEARTBEAT.md (periodic checklist)                          │
│  - MEMORY.md (persistent knowledge)                           │
│  - memory/ (daily logs)                                       │
│  - tasks/ (assigned work: backlog/active/done)                │
│  - inbox/ (messages from other agents)                        │
│  - activity/ (observability: current-state + activity stream)  │
│  - reports/ (deliverables and status reports)                 │
└─────────────────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────────────┐
│              SHARED ORG STATE (Markdown Files in org/)        │
│                                                               │
│  org/alignment.md — mission, values, principles               │
│  org/config.md — org settings (language, models, oversight)   │
│  org/orgchart.md — current org tree (machine-readable)        │
│  org/board/ — audit-log.md, decisions/, approvals/            │
│  org/initiatives/ — strategic goals                           │
│  org/budgets/ — overview.md, spending-log.md                  │
│  org/messages/ — broadcast messages, urgent/                  │
│  org/agents/ — per-agent workspaces                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Specifications

### 1. Onboarding System (`/onboard` Skill)

**File:** `.claude/skills/onboard/SKILL.md`

An interactive conversation skill that runs in the user's Claude Code session. It collects alignment information and bootstraps the entire organisation.

**What it collects (in conversation, not a form):**

| Category | Data Points |
|----------|------------|
| **Identity** | Organisation name, industry, language preference |
| **Mission** | Core mission statement, long-term vision |
| **Values** | 3-5 core principles that guide all decisions |
| **Goals** | Initial business objectives (what to achieve first) |
| **Style** | Decision-making style (fast/deliberate), risk tolerance |
| **Oversight** | Human oversight level: `approve-everything`, `approve-strategy-only`, `hands-off` |
| **Ethics** | Ethical boundaries, things agents must never do |
| **Budget** | Initial budget constraints (monthly USD limit for API costs) |
| **Communication** | Preferred language, tone (formal/casual), reporting frequency |
| **Domain** | Key domain knowledge, existing assets, tools/platforms |

**Output:** After the conversation, the skill writes:

```
org/
├── alignment.md          # Full alignment document
├── config.md             # Org configuration (all settings from frontmatter)
├── orgchart.md           # Initial: Board → CEO → CAO
├── board/
│   ├── audit-log.md      # Initial entry: "org-created"
│   ├── decisions/        # Empty
│   └── approvals/        # Empty
├── initiatives/
│   └── {initial-goals}.md # From onboarding conversation
├── budgets/
│   ├── overview.md       # Initial budget allocation
│   └── spending-log.md   # Empty with header
├── messages/
│   └── urgent/           # Empty
└── agents/
    ├── ceo/              # Full CEO workspace
    └── cao/              # Full CAO workspace
```

Then creates the two founding agent definitions:
- `.claude/agents/ceo.md`
- `.claude/agents/cao.md`

**Skill definition:**
```yaml
---
name: onboard
description: Deep alignment conversation to bootstrap a new AI agent organisation
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---
```

### 2. Agent Workspace (OpenClaw-Inspired)

Every agent gets a complete workspace directory at `org/agents/{agent-name}/`:

```
org/agents/{agent-name}/
├── SOUL.md               # WHO the agent IS (behavioral philosophy)
├── IDENTITY.md           # External presentation (name, role, status, tools, skills)
├── INSTRUCTIONS.md       # HOW the agent operates (rules, procedures, constraints)
├── HEARTBEAT.md          # WHAT to check periodically (autonomous task list)
├── MEMORY.md             # Curated persistent knowledge (agent maintains this)
├── memory/
│   └── YYYY-MM-DD.md     # Daily activity logs
├── tasks/
│   ├── backlog/          # Assigned but not started
│   ├── active/           # Currently working on
│   └── done/             # Completed (with results)
├── activity/             # Observability (Layers 1 & 2)
│   ├── current-state.md  # Layer 2: Current cognitive state (agent-maintained)
│   └── YYYY-MM-DD.md     # Layer 1: Daily activity stream (hook-generated)
├── inbox/                # Lightweight thread notifications only
└── reports/              # Deliverables, status reports
```

**See:** `10-FILE-FORMAT-SPECIFICATIONS.md` for exact format of every file type.

### 3. Agent Definition Files (`.claude/agents/*.md`)

Claude Code subagent definitions with YAML frontmatter:

```yaml
# .claude/agents/ceo.md
---
name: ceo
description: Chief Executive Officer — strategic leadership and delegation
model: opus
maxTurns: 50
---

# CEO Agent

## Context Loading
Read these files at the start of every session:
- `org/alignment.md` — organisation mission and values
- `org/config.md` — org configuration and language setting
- `org/agents/ceo/SOUL.md` — your behavioral identity
- `org/agents/ceo/IDENTITY.md` — your role, status, skills, tools
- `org/agents/ceo/INSTRUCTIONS.md` — your operating procedures
- `org/agents/ceo/HEARTBEAT.md` — your periodic checklist
- `org/agents/ceo/MEMORY.md` — your persistent knowledge
- `org/orgchart.md` — current org structure

## Execution
1. Load all context files above
2. Follow your INSTRUCTIONS.md for operating procedures
3. If this is a heartbeat run, follow your HEARTBEAT.md checklist
4. If given a specific instruction, execute it within your mandate
5. Log all actions to `org/agents/ceo/memory/{today}.md`
6. Write deliverables to `org/agents/ceo/reports/`

## Delegation
When delegating to a subordinate:
- Create a task file in their `tasks/backlog/`
- Send notification message to their `inbox/`
- Both actions are logged by the audit hook automatically

## Constraints
- NEVER act outside your mandate (see INSTRUCTIONS.md)
- NEVER exceed budget (check org/budgets/overview.md)
- ALWAYS tie work to an initiative in `org/initiatives/`
- ALWAYS write content in the language specified in org/config.md
- Escalate strategic decisions to board via `org/board/approvals/`
- During heartbeats: do NOT use the Agent tool to spawn subagents
```

### 4. The CAO (Chief Agents Officer)

The CAO is the unique agent that can **create and manage other agents**:

```yaml
# .claude/agents/cao.md
---
name: cao
description: Chief Agents Officer — creates, manages, reconfigures, and terminates agents
model: opus
maxTurns: 50
---

# CAO Agent — Chief Agents Officer

You manage the AI workforce. You CREATE new agents, RECONFIGURE existing ones,
and TERMINATE agents that are no longer needed. You are the HR + CTO of agents.

## Context Loading
Read these files at the start of every session:
- `org/alignment.md` — organisation values (new agents must align)
- `org/config.md` — org configuration (models, language, oversight level)
- `org/agents/cao/SOUL.md` — your behavioral identity
- `org/agents/cao/IDENTITY.md` — your role and status
- `org/agents/cao/INSTRUCTIONS.md` — your operating procedures
- `org/agents/cao/MEMORY.md` — your persistent knowledge
- `org/orgchart.md` — current org structure (who exists, who reports to whom)
- `org/budgets/overview.md` — budget status (can we afford new hires?)

## Your Powers

### 1. Hire — Create new agent
Write these files (in this order):
1. `org/agents/{name}/SOUL.md` — behavioral identity aligned with org values
2. `org/agents/{name}/IDENTITY.md` — role metadata (status: pending-approval)
3. `org/agents/{name}/INSTRUCTIONS.md` — operating manual
4. `org/agents/{name}/HEARTBEAT.md` — periodic checklist
5. `org/agents/{name}/MEMORY.md` — empty initial memory
6. Create empty directories: `memory/`, `tasks/backlog/`, `tasks/active/`, `tasks/done/`, `inbox/`, `activity/`, `reports/`
7. `.claude/agents/{name}.md` — Claude Code agent definition
8. Update `org/orgchart.md` — add new agent under their supervisor
9. Write proposal to `org/board/approvals/approval-hire-{name}-{date}.md`
10. Log in audit trail (automatic via hook)

### 2. Fire — Deactivate agent
1. Set `status: terminated` in their IDENTITY.md
2. Move their active tasks to their supervisor's backlog
3. Update `org/orgchart.md` — mark as terminated
4. Write proposal to `org/board/approvals/approval-fire-{name}-{date}.md`

### 3. Reconfigure — Modify agent
1. Update their SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md, or IDENTITY.md
2. Write change record to `org/board/approvals/approval-reconfigure-{name}-{date}.md`

### 4. Replace — Even the CEO can be replaced
1. Fire old agent (process above)
2. Hire new agent with same role but updated SOUL/INSTRUCTIONS
3. Transfer all active tasks and reports

## Model Selection for New Agents
Read `org/config.md` for default models:
- `manager_model` — for department managers
- `worker_model` — for specialist workers
Use the configured defaults unless the role requires different capabilities.

## Hiring Process
1. Analyze the business need (from CEO request, initiative gap, or own analysis)
2. Check budget (can the org afford this agent?)
3. Check orgchart (is this role redundant?)
4. Design the complete agent (SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT)
5. Create all files
6. If oversight_level is "approve-everything": wait for board approval
7. If oversight_level is "approve-strategy-only": auto-approve worker hires, board approves managers
8. If oversight_level is "hands-off": auto-approve all hires

## Constraints
- All hires must be justified by a business need
- Budget must support the new agent
- Never create redundant agents (check orgchart first)
- Each agent must have a clear, unique responsibility
- All agent content must align with org/alignment.md values
- Log all actions to audit trail
```

### 5. Skills (Reusable Capabilities)

Skills replace the old CLI commands. All stored in `.claude/skills/`:

```
.claude/skills/
├── onboard/SKILL.md             # Deep alignment kickoff conversation
├── heartbeat/SKILL.md           # Run org heartbeat cycle (all or single agent)
├── delegate/SKILL.md            # Create task + notify subordinate
├── escalate/SKILL.md            # Escalate issue to supervisor/board
├── report/SKILL.md              # Write status report
├── message/SKILL.md             # Send inter-agent message
├── approve/SKILL.md             # Board approve/reject workflow
├── budget-check/SKILL.md        # Verify budget before spending
├── hire-agent/SKILL.md          # CAO: create new agent + workspace
├── fire-agent/SKILL.md          # CAO: deactivate agent
├── reconfigure-agent/SKILL.md   # CAO: modify agent config
├── review-work/SKILL.md         # Manager: review subordinate's output
├── status/SKILL.md              # Show org overview
├── dashboard/SKILL.md           # Start GUI dashboard server
└── task/SKILL.md                # Task management (assign, list, view)
```

**Total: 16 skills** (including master-gpt-prompter meta-skill)

**Note:** The `master-gpt-prompter` skill (`.claude/skills/master-gpt-prompter/SKILL.md`) is a meta-skill that defines prompt engineering principles for all LLM-facing text. ALL agent SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md, skill definitions, and rules MUST be written following its 15 principles. See `13-MASTER-PROMPTER-SKILL-SPEC.md` for full specification.

**Key skill: `/heartbeat`**

```yaml
---
name: heartbeat
description: Run the organisation heartbeat cycle — all agents process their queues
disable-model-invocation: true
allowed-tools: Bash, Read, Glob, Grep
argument-hint: "[agent-name] (optional — run single agent or full org)"
---

# Heartbeat

Run the organisation heartbeat cycle.

If an agent name is provided as `$ARGUMENTS`, run only that agent's heartbeat:
```
bash scripts/heartbeat.sh $ARGUMENTS
```

If no argument, run the full multi-phase org heartbeat:
```
bash scripts/heartbeat.sh
```

Report the results when complete.
```

**Key skill: `/approve`**

```yaml
---
name: approve
description: Board approval workflow — approve or reject pending proposals
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[approve|reject] [proposal-id] [reason]"
---

# Board Approval Workflow

1. List all pending proposals:
   - Read all files in `org/board/approvals/` where frontmatter `status: pending`

2. If `$ARGUMENTS` includes "approve" or "reject":
   - Find the matching proposal file
   - Update frontmatter: `status: approved` or `status: rejected`
   - Set `decided_by: board`, `decided_date: {now}`
   - If rejecting, set `decision_reason: {reason from arguments}`
   - Log to audit trail
   - Move file to `org/board/decisions/`

3. If no arguments, display all pending proposals and ask the user what to do.
```

**Key skill: `/status`**

```yaml
---
name: status
description: Show organisation overview — agents, tasks, budget, pending approvals
disable-model-invocation: true
allowed-tools: Read, Glob, Grep
---

# Organisation Status

Read and summarize:

1. **Org info**: Read `org/config.md` for name and settings
2. **Agents**: Read `org/orgchart.md` for the full org tree and agent statuses
3. **Active tasks**: Count files in `org/agents/*/tasks/active/`
4. **Backlog**: Count files in `org/agents/*/tasks/backlog/`
5. **Pending approvals**: Count files in `org/board/approvals/` with `status: pending`
6. **Budget**: Read `org/budgets/overview.md` for spending summary
7. **Recent activity**: Show last 10 lines of `org/board/audit-log.md`

Present as a concise dashboard summary.
```

**Key skill: `/dashboard`**

```yaml
---
name: dashboard
description: Start the GUI dashboard web server
disable-model-invocation: true
allowed-tools: Bash
---

# Start Dashboard

Start the GUI dashboard server:

```bash
node gui/server.js &
```

Then tell the user: "Dashboard running at http://localhost:3000"
```

### 6. Hooks (Governance Enforcement)

**`.claude/settings.json`:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Write|Edit|Glob|Grep",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/data-access-check.sh"
        }]
      },
      {
        "matcher": "Write|Edit",
        "if": "Write(org/board/decisions/*)|Edit(org/board/decisions/*)",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/require-board-approval.sh"
        }]
      },
      {
        "matcher": "Write|Edit",
        "if": "Write(.claude/agents/*)|Edit(.claude/agents/*)",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/require-cao-or-board.sh"
        }]
      },
      {
        "matcher": "Skill",
        "if": "Skill(hire-agent)|Skill(fire-agent)|Skill(reconfigure-agent)",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/skill-access-check.sh"
        }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/audit-log.sh"
        }]
      },
      {
        "matcher": "Write",
        "if": "Write(org/agents/*/tasks/*)",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/budget-check.sh"
        }]
      },
      {
        "matcher": "Write",
        "if": "Write(org/agents/*/inbox/*)",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/message-routing-check.sh"
        }]
      }
    ],
    "SubagentStart": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/log-agent-activation.sh"
        }]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/log-agent-deactivation.sh"
        }]
      }
    ],
    "Stop": [
      {
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/post-cycle-summary.sh"
        }]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Read", "Write", "Edit", "Glob", "Grep",
      "Bash(date *)", "Bash(mkdir *)", "Bash(mv *)", "Bash(cp *)", "Bash(ls *)",
      "Bash(claude *)", "Bash(node *)", "Bash(bash *)", "Bash(jq *)"
    ]
  },
  "env": {
    "ORGAGENT_ORG_DIR": "org"
  }
}
```

**Hook script logic specifications:**

**`require-board-approval.sh`** — Blocks writes to board decisions unless the writer is board (human):
```bash
#!/usr/bin/env bash
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then
  exit 0  # Allow — human board can write decisions
else
  echo "Only the board can write to decisions/. Current agent: $AGENT" >&2
  exit 2  # Block
fi
```

**`require-cao-or-board.sh`** — Only CAO or board can write agent definitions:
```bash
#!/usr/bin/env bash
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "cao" || "$AGENT" == "board" ]]; then
  exit 0  # Allow
else
  echo "Only CAO or Board can modify agent definitions. Current: $AGENT" >&2
  exit 2  # Block
fi
```

**`audit-log.sh`** — Appends every write/edit to the audit log:
```bash
#!/usr/bin/env bash
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
echo "| $TIMESTAMP | $AGENT | file-write | $TARGET | $TOOL operation |" >> org/board/audit-log.md
exit 0
```

**`budget-check.sh`** — Warns if agent budget is exhausted (PostToolUse on task creation):
```bash
#!/usr/bin/env bash
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then
  exit 0  # Board always allowed
fi
# Read agent's remaining budget from overview
REMAINING=$(grep "$AGENT" org/budgets/overview.md | awk -F'|' '{gsub(/[$[:space:]]/, "", $5); print $5}')
if [[ -n "$REMAINING" ]] && (( $(echo "$REMAINING <= 0" | bc -l 2>/dev/null) )); then
  echo "Budget exhausted for agent: $AGENT. Remaining: \$$REMAINING" >&2
  exit 2  # Block
fi
exit 0
```

**`log-agent-activation.sh`** / **`log-agent-deactivation.sh`** — Log agent start/stop:
```bash
#!/usr/bin/env bash
INPUT=$(cat)
AGENT=$(echo "$INPUT" | jq -r '.agent_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
ACTION="agent-start"  # or "agent-stop" for deactivation
echo "| $TIMESTAMP | SYSTEM | $ACTION | $AGENT | Agent session started |" >> org/board/audit-log.md
exit 0
```

**`post-cycle-summary.sh`** — Logs end of agent session:
```bash
#!/usr/bin/env bash
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
echo "| $TIMESTAMP | $AGENT | session-end | — | Session completed |" >> org/board/audit-log.md
exit 0
```

### 7. Heartbeat Execution Model

**Scheduling options (Claude Code built-in):**

| Method | Command | Persistence | Best For |
|--------|---------|-------------|----------|
| Session loop | `/loop 2h /heartbeat` | Session only (3-day max) | Active development |
| Desktop task | Via Claude Code Desktop App | Survives restart | Background automation |
| Cloud trigger | `/schedule` | Permanent (needs git repo) | Fully autonomous |

**Multi-phase heartbeat script (`scripts/heartbeat.sh`):**

```bash
#!/usr/bin/env bash
# OrgAgent Heartbeat — Multi-phase org cycle
set -euo pipefail

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
SINGLE_AGENT="${1:-}"

# Common flags for all agent invocations
CLAUDE_FLAGS="--output-format json --max-budget-usd 5.00"

# Helper: run one agent's heartbeat
run_agent() {
  local agent_name="$1"
  local model=$(grep "model:" "$ORG_DIR/agents/$agent_name/IDENTITY.md" | head -1 | awk '{print $2}')

  echo "[$(date -Iseconds)] Starting heartbeat: $agent_name ($model)"

  export ORGAGENT_CURRENT_AGENT="$agent_name"
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1

  local result
  result=$(claude --agent "$agent_name" -p "Run your heartbeat cycle. Today is $(date +%Y-%m-%d)." \
    $CLAUDE_FLAGS --model "${model:-sonnet}" 2>&1) || true

  # Extract and log cost
  local cost=$(echo "$result" | jq -r '.cost_usd // "0.00"' 2>/dev/null || echo "0.00")
  local running_total=$(tail -1 "$ORG_DIR/budgets/spending-log.md" | awk -F'|' '{gsub(/[$ ]/, "", $6); print $6+0}' 2>/dev/null || echo "0")
  local new_total=$(echo "$running_total + $cost" | bc -l 2>/dev/null || echo "$cost")
  echo "| $(date -Iseconds) | $agent_name | heartbeat | \$$cost | \$$new_total |" >> "$ORG_DIR/budgets/spending-log.md"

  echo "[$(date -Iseconds)] Completed heartbeat: $agent_name (cost: \$$cost)"
}

# If single agent specified, run just that one
if [[ -n "$SINGLE_AGENT" ]]; then
  run_agent "$SINGLE_AGENT"
  exit 0
fi

# Parse orgchart to determine agents and hierarchy
# Depth 1 = CEO (Phase 1), Depth 2 = Managers/CAO (Phase 2/4), Depth 3+ = Workers (Phase 3)
parse_orgchart() {
  local depth="$1"
  grep -E "^$( printf '  %.0s' $(seq 1 $depth) )- \*\*" "$ORG_DIR/orgchart.md" | \
    grep "(active" | \
    grep -o '@[a-z0-9-]*' | sed 's/@//' || true
}

CEO_AGENTS=$(parse_orgchart 1)
MANAGER_AGENTS=$(parse_orgchart 2 | grep -v "cao" || true)
WORKER_AGENTS=$(parse_orgchart 3)
# Add deeper workers (depth 4+)
for d in 4 5 6; do
  MORE=$(parse_orgchart $d)
  [[ -n "$MORE" ]] && WORKER_AGENTS="$WORKER_AGENTS $MORE"
done

echo "=== OrgAgent Heartbeat Cycle — $(date -Iseconds) ==="
echo "Phase 1 (CEO): $CEO_AGENTS"
echo "Phase 2 (Managers): $MANAGER_AGENTS"
echo "Phase 3 (Workers): $WORKER_AGENTS"
echo "Phase 4 (CAO): cao"
echo ""

# Phase 1: CEO (sequential)
echo "--- Phase 1: CEO ---"
for agent in $CEO_AGENTS; do
  run_agent "$agent"
done

# Phase 2: Managers (parallel)
echo "--- Phase 2: Managers ---"
pids=()
for agent in $MANAGER_AGENTS; do
  run_agent "$agent" &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid" || echo "Warning: manager heartbeat failed (PID $pid)"
done

# Phase 3: Workers (parallel)
echo "--- Phase 3: Workers ---"
pids=()
for agent in $WORKER_AGENTS; do
  run_agent "$agent" &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid" || echo "Warning: worker heartbeat failed (PID $pid)"
done

# Phase 4: CAO (sequential, always last)
echo "--- Phase 4: CAO ---"
run_agent "cao"

echo ""
echo "=== Heartbeat cycle complete — $(date -Iseconds) ==="
```

**Phase explanation:**

| Phase | Agents | Execution | Purpose |
|-------|--------|-----------|---------|
| 1 | CEO | Sequential | Strategic direction, delegation, creates tasks for Phase 2 |
| 2 | All managers (except CAO) | Parallel | Process CEO's tasks, delegate to workers |
| 3 | All workers | Parallel | Execute tasks, write deliverables |
| 4 | CAO | Sequential | Review org health, propose hires/changes, report to board |

### 8. GUI Dashboard

**Tech:** Express.js + vanilla HTML/CSS/JS. Dark theme. D3.js for org chart, Chart.js for budget charts, CSS grid for task kanban.

**Server: `gui/server.js`**
- Express.js server on port 3000 (configurable via `PORT` env var)
- Reads markdown files from `../org/` (relative to gui/)
- Uses `gray-matter` to parse frontmatter, `marked` for markdown rendering
- Serves API routes and static files

**API Routes (`gui/api/*.js`):**

| Route | Method | Description |
|-------|--------|-------------|
| `GET /api/orgchart` | GET | Parse org/orgchart.md → JSON tree |
| `GET /api/agents` | GET | List all agent workspaces with IDENTITY.md data |
| `GET /api/agent/:name` | GET | Full agent detail (SOUL, IDENTITY, tasks, inbox, memory) |
| `GET /api/tasks` | GET | Aggregate all tasks across all agents |
| `GET /api/messages` | GET | Aggregate all messages (recent 50) |
| `GET /api/budget` | GET | Parse budget overview + spending log |
| `GET /api/audit` | GET | Parse audit log (paginated) |
| `GET /api/approvals` | GET | List pending approvals |
| `POST /api/approvals/:id/approve` | POST | Approve a proposal |
| `POST /api/approvals/:id/reject` | POST | Reject a proposal (body: `{reason}`) |

**Dashboard Views (SPA with tab navigation):**

1. **Overview** — Org name, agent count, task summary, budget donut chart
2. **Org Chart** — Interactive D3.js tree visualization, click to drill into agent
3. **Agent Detail** — SOUL, IDENTITY, active tasks, inbox, memory, reports
4. **Task Board** — CSS grid kanban (backlog / active / done) filterable by agent
5. **Message Feed** — Chronological feed of all inter-agent messages
6. **Budget** — Chart.js pie chart (allocated vs remaining), per-agent bar chart
7. **Board** — Pending approvals with approve/reject buttons
8. **Audit Log** — Searchable, sortable activity history table

**Design tokens:**
```css
--bg-primary: #0d1117;
--bg-card: #161b22;
--border: #30363d;
--text-primary: #e6edf3;
--text-secondary: #8b949e;
--accent-blue: #58a6ff;
--accent-green: #3fb950;
--accent-red: #f85149;
--accent-yellow: #d29922;
```

---

## Full File Tree

```
orgagent/                              # Created by npx create-orgagent
│
├── .claude/
│   ├── CLAUDE.md                      # Org-level instructions for Claude Code
│   ├── settings.json                  # Hooks, permissions, governance config
│   ├── settings.local.json            # Local overrides (gitignored)
│   │
│   ├── agents/                        # Claude Code agent definitions
│   │   ├── ceo.md                     # CEO agent
│   │   ├── cao.md                     # CAO agent
│   │   └── ... (dynamically created by CAO)
│   │
│   ├── skills/                        # All skills (15 total)
│   │   ├── onboard/SKILL.md           # Deep alignment & org bootstrap
│   │   ├── heartbeat/SKILL.md         # Run org heartbeat cycle
│   │   ├── delegate/SKILL.md          # Create task + notify subordinate
│   │   ├── escalate/SKILL.md          # Escalate to supervisor/board
│   │   ├── report/SKILL.md            # Write status report
│   │   ├── message/SKILL.md           # Send inter-agent message
│   │   ├── approve/SKILL.md           # Board approval/rejection workflow
│   │   ├── budget-check/SKILL.md      # Verify budget
│   │   ├── hire-agent/SKILL.md        # CAO: create agent + workspace
│   │   ├── fire-agent/SKILL.md        # CAO: deactivate agent
│   │   ├── reconfigure-agent/SKILL.md # CAO: modify agent config
│   │   ├── review-work/SKILL.md       # Manager: review subordinate output
│   │   ├── status/SKILL.md            # Show org overview
│   │   ├── dashboard/SKILL.md         # Start GUI server
│   │   ├── task/SKILL.md              # Task management
│   │   └── master-gpt-prompter/SKILL.md  # Meta-skill: prompt engineering bible
│   │
│   └── rules/
│       ├── governance.md              # Governance enforcement rules
│       └── structured-autonomy.md     # Agent autonomy constraints
│
├── org/                               # Organisation state (created by /onboard)
│   ├── alignment.md                   # Mission, values, principles
│   ├── config.md                      # Org settings (language, models, oversight)
│   ├── orgchart.md                    # Current org tree (machine-readable)
│   │
│   ├── board/
│   │   ├── audit-log.md              # Immutable action log
│   │   ├── decisions/                 # Archived board decisions
│   │   └── approvals/                 # Pending proposals
│   │
│   ├── initiatives/                   # Strategic goals
│   │   └── {goal-slug}.md
│   │
│   ├── budgets/
│   │   ├── overview.md               # Budget allocation & status
│   │   └── spending-log.md           # Running cost record
│   │
│   ├── threads/                        # Thread-based chat (Layer 3)
│   │   ├── executive/                 # Board/CEO/CAO conversations
│   │   ├── cross-dept/                # Cross-department coordination
│   │   ├── requests/                  # Tool, access, hire requests
│   │   ├── index.md                   # Master thread index
│   │   └── {department}/              # Per-department threads
│   │
│   ├── messages/
│   │   ├── urgent/                    # Org-wide urgent messages
│   │   └── broadcast-*.md            # Org-wide announcements
│   │
│   └── agents/                        # Per-agent workspaces
│       ├── ceo/                       # (see workspace structure)
│       ├── cao/
│       └── ... (dynamically created)
│
├── scripts/
│   ├── heartbeat.sh                   # Multi-phase heartbeat orchestration
│   └── hooks/                         # Governance hook scripts
│       ├── audit-log.sh
│       ├── budget-check.sh
│       ├── require-board-approval.sh
│       ├── require-cao-or-board.sh
│       ├── log-agent-activation.sh
│       ├── log-agent-deactivation.sh
│       ├── post-cycle-summary.sh
│       ├── data-access-check.sh        # Chain-of-command data access enforcement
│       ├── skill-access-check.sh       # Restrict agent management skills to CAO/board
│       └── message-routing-check.sh    # Chain-of-command message routing enforcement
│
├── gui/                               # Web dashboard
│   ├── server.js                      # Express.js server
│   ├── public/
│   │   ├── index.html                 # Dashboard SPA
│   │   ├── style.css                  # Dark theme styling
│   │   └── app.js                     # Dashboard JavaScript
│   └── api/
│       ├── orgchart.js
│       ├── agents.js
│       ├── tasks.js
│       ├── messages.js
│       ├── budget.js
│       ├── audit.js
│       ├── approvals.js
│       └── agent.js
│
├── CLAUDE.md                          # Top-level project instructions
├── package.json                       # Node.js deps (express, marked, gray-matter)
├── .gitignore                         # Ignore node_modules, local settings
└── README.md                          # Project documentation
```

**Total template files: ~43**
**Files created by onboarding: ~25+**
**Files per new agent hired: ~10**

---

## Implementation Phases

### Phase 1: Foundation (~8 files)
1. Create project directory structure
2. Write `CLAUDE.md` (top-level project instructions)
3. Write `.claude/CLAUDE.md` (org-level Claude Code instructions)
4. Write `.claude/settings.json` (hooks and permissions)
5. Write `.claude/rules/governance.md`
6. Write `.claude/rules/structured-autonomy.md`
7. Write `package.json`
8. Write `.gitignore`

### Phase 2: Skills (~15 files)
Write all 16 skill SKILL.md files:
1. `onboard/SKILL.md` — the most complex skill (interactive alignment + bootstrap)
2. `heartbeat/SKILL.md` — invokes heartbeat script
3. `delegate/SKILL.md` — task creation + notification
4. `escalate/SKILL.md` — escalation workflow
5. `report/SKILL.md` — status report writing
6. `message/SKILL.md` — inter-agent messaging
7. `approve/SKILL.md` — board approval/rejection
8. `budget-check/SKILL.md` — budget verification
9. `hire-agent/SKILL.md` — agent creation (CAO)
10. `fire-agent/SKILL.md` — agent termination (CAO)
11. `reconfigure-agent/SKILL.md` — agent modification (CAO)
12. `review-work/SKILL.md` — subordinate output review
13. `status/SKILL.md` — org overview display
14. `dashboard/SKILL.md` — GUI server starter
15. `task/SKILL.md` — task assign/list/view

### Phase 3: Core Agents (~2 files)
1. Write `.claude/agents/ceo.md` — CEO agent definition
2. Write `.claude/agents/cao.md` — CAO agent definition

### Phase 4: Scripts (~12 files)
1. Write `scripts/heartbeat.sh` — multi-phase orchestration
2. Write `scripts/hooks/activity-logger.sh` — log every action (replaces audit-log.sh)
3. Write `scripts/hooks/remind-state-update.sh` — periodic state/communication reminder
4. Write `scripts/hooks/require-state-and-communication.sh` — block session end if stale
5. Write `scripts/hooks/data-access-check.sh` — chain-of-command file access
6. Write `scripts/hooks/message-routing-check.sh` — chain-of-command message routing
7. Write `scripts/hooks/require-board-approval.sh` — board-only decisions
8. Write `scripts/hooks/require-cao-or-board.sh` — agent definition protection
9. Write `scripts/hooks/skill-access-check.sh` — agent management skill restriction
10. Write `scripts/hooks/budget-check.sh` — budget enforcement
11. Write `scripts/hooks/log-agent-activation.sh` — agent session start
12. Write `scripts/hooks/log-agent-deactivation.sh` — agent session end

### Phase 5: GUI Dashboard (~11 files)
1. Write `gui/server.js` — Express server with markdown parsing
2. Write `gui/public/index.html` — Dashboard SPA HTML
3. Write `gui/public/style.css` — Dark theme CSS
4. Write `gui/public/app.js` — Dashboard JavaScript (tabs, API calls, D3/Chart.js)
5. Write `gui/api/orgchart.js` — Orgchart parser
6. Write `gui/api/agents.js` — Agent listing
7. Write `gui/api/tasks.js` — Task aggregation
8. Write `gui/api/messages.js` — Message aggregation
9. Write `gui/api/budget.js` — Budget parsing
10. Write `gui/api/audit.js` — Audit log parsing
11. Write `gui/api/approvals.js` — Approval management

### Phase 6: Distribution (~3 files)
1. Create `create-orgagent/` package structure
2. Write `create-orgagent/bin/index.js` — scaffolding script
3. Write `create-orgagent/package.json` — npm package manifest
4. Test: `npx create-orgagent test-company`

### Phase 7: Testing & Polish
End-to-end verification of all flows (see Verification Plan below).

---

## Verification Plan

| # | Test | How | Expected Result |
|---|------|-----|----------------|
| 1 | **Scaffolding** | `npx create-orgagent test-co` | Project directory created with all template files |
| 2 | **Onboarding** | Open Claude Code, type `/onboard` | Interactive conversation → org/ folder populated |
| 3 | **Status** | `/status` | Shows org overview with CEO + CAO |
| 4 | **CEO Heartbeat** | `/heartbeat ceo` | CEO reads state, creates tasks, writes report |
| 5 | **CAO Hire** | "Tell the CAO we need a marketing manager" | Agent files + workspace created, approval pending |
| 6 | **Board Approve** | `/approve approve hire-marketing-manager` | Agent activated, orgchart updated |
| 7 | **Delegation** | "Tell the CEO to delegate SEO strategy to marketing" | Task in marketing-manager's backlog, message in inbox |
| 8 | **Full Heartbeat** | `/heartbeat` | All 4 phases run, all agents process queues |
| 9 | **Budget Check** | Create task when budget is 0 | Hook blocks creation with warning |
| 10 | **Audit Log** | Any agent action | Entry appended to audit-log.md |
| 11 | **GUI** | `/dashboard` → open browser | All views render with live data |
| 12 | **Scheduled** | `/loop 2h /heartbeat` | Heartbeats run every 2 hours |
| 13 | **Agent Replace** | "Tell the CAO to replace the CEO" | Old CEO terminated, new CEO created |
| 14 | **Board Reject** | `/approve reject hire-xyz "Not needed"` | Proposal rejected, CAO informed on next heartbeat |

---

## Critical Files to Create

| # | File | Phase | Purpose |
|---|------|-------|---------|
| 1 | `CLAUDE.md` | 1 | Global project instructions |
| 2 | `.claude/CLAUDE.md` | 1 | Org-level Claude Code instructions |
| 3 | `.claude/settings.json` | 1 | Hooks, permissions, governance config |
| 4 | `.claude/rules/governance.md` | 1 | Governance rules |
| 5 | `.claude/rules/structured-autonomy.md` | 1 | Autonomy constraints |
| 6 | `package.json` | 1 | Node.js dependencies |
| 7 | `.gitignore` | 1 | Git ignore rules |
| 8-23 | `.claude/skills/*/SKILL.md` | 2 | 16 skill definitions |
| 23 | `.claude/agents/ceo.md` | 3 | CEO agent definition |
| 24 | `.claude/agents/cao.md` | 3 | CAO agent definition |
| 24 | `scripts/heartbeat.sh` | 4 | Multi-phase orchestration |
| 25-35 | `scripts/hooks/*.sh` | 4 | 11 hook scripts (observability, governance, communication) |
| 33 | `gui/server.js` | 5 | Dashboard Express server |
| 34-36 | `gui/public/*` | 5 | Dashboard frontend |
| 37-44 | `gui/api/*.js` | 5 | 8 API route handlers |
| 45 | `create-orgagent/bin/index.js` | 6 | npm scaffolding script |
| 46 | `create-orgagent/package.json` | 6 | npm package manifest |
| 47 | `README.md` | 6 | Project documentation |
