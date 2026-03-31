# Dynamic Permissions & Access Control — Complete Specification

**Date:** 2026-03-31
**Purpose:** Specification for dynamic tool permissions, data access control, request workflows, and chain-of-command enforcement.

---

## Overview

In a real company, not every employee has access to all systems, data, and tools. OrgAgent mirrors this:

1. **Tool permissions** — Each agent has specific tools determined by the CAO + their manager. Agents can REQUEST additional tools.
2. **Data access** — Each agent can only read/write specific directories. Chain-of-command determines access scope.
3. **Request workflows** — Agents can request new tools or data access from their superiors. All requests are logged.
4. **Hook enforcement** — PreToolUse hooks enforce access control at runtime.

---

## 1. Tool Permissions System

### How Tool Permissions Are Assigned

When the CAO creates a new agent, the CAO (in consultation with the agent's manager/executive) determines which tools the agent needs:

```yaml
# In org/agents/{name}/IDENTITY.md
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
```

The same tools list is mirrored in the agent definition (`.claude/agents/{name}.md`).

### Tool Categories

| Category | Tools | Typical Access |
|----------|-------|---------------|
| **Core (all agents)** | Read, Write, Edit, Glob, Grep | Every agent needs filesystem operations |
| **Execution** | Bash | Agents that run scripts, process data |
| **Web** | WebFetch, WebSearch | Research agents, SEO, marketing |
| **Communication** | Agent (spawn subagents) | Only CEO in interactive mode |
| **MCP** | mcp__* tools | As configured per agent's needs |

### Tool Determination Process

1. **CAO designs the role** — determines base tool requirements
2. **CAO consults with the agent's future manager** — manager confirms or modifies tool list
3. **If oversight requires it** — board approves the tool list as part of the hire approval
4. **Agent is created** with the approved tool set
5. **At runtime** — the heartbeat script passes `--allowedTools` based on the agent's IDENTITY.md tools list

### Tool Request Workflow

When an agent discovers it needs a tool it doesn't have:

```
Agent discovers need → Creates tool request → Sends to CAO via inbox
     ↓
CAO receives request → Reads justification → Consults agent's manager
     ↓
Manager approves/rejects → CAO writes decision
     ↓
If approved → CAO updates IDENTITY.md tools + .claude/agents/{name}.md
     ↓
Agent gets new tool on next heartbeat run
```

**All requests are logged in the audit trail.**

### Tool Request File Format

Created in `org/threads/requests/` AND a notification sent to CAO's `inbox/`:

```markdown
---
id: request-tool-20260331-100000-seo-agent
type: tool-request
from: seo-agent
to: cao
status: pending
requested_tools:
  - WebSearch
  - WebFetch
reason: "Need web search capability to perform competitor backlink analysis for task-20260331-003. Cannot complete SEO keyword research without accessing search results."
task_ref: task-20260331-003
timestamp: 2026-03-31T10:00:00
consulted_manager:
manager_decision:
decided_by:
decided_date:
decision_reason:
---

## Tool Request: WebSearch, WebFetch

### Current Tools
Read, Write, Edit, Glob, Grep

### Requested Tools
- **WebSearch** — Search the web for keyword data, competitor analysis
- **WebFetch** — Fetch web pages for content analysis and backlink research

### Justification
I am assigned task-20260331-003 (Competitor Backlink Analysis) under the Q2 Marketing Growth initiative. This task requires me to:
1. Search for competitor websites and their backlink profiles
2. Fetch competitor pages to analyze their SEO structure
3. Research current keyword rankings across search engines

Without WebSearch and WebFetch, I cannot access external data needed to complete this analysis. I would need to rely entirely on internally provided data, which does not exist for competitor analysis.

### Risk Assessment
- WebSearch: Low risk — read-only web queries
- WebFetch: Low risk — read-only page fetching, no form submissions
- No authentication or credential access needed
- Bounded by budget constraints (web operations are low cost)

### Duration
Permanent — SEO work fundamentally requires web access.
```

### Tool Request State Transitions

```
pending → approved → tools updated in IDENTITY.md
pending → rejected → agent notified, suggestion for alternative approach
pending → escalated → sent to board for decision (if manager + CAO disagree)
```

---

## 2. Data Access Control System

### The Chain-of-Command Access Model

Based on the high-level architecture diagram, data access follows the organisational hierarchy:

```
BOARD (full access to everything)
  ↓
CEO (reads everything in org/, writes to own workspace + org-level files)
  ↓
MANAGERS (read own department + shared org files, no access to other departments or board internals)
  ↓
WORKERS (read own workspace + limited shared files, no access to budgets, board, or other departments)
```

### Default Access Levels by Tier

#### Board (human user)
```yaml
access_read:
  - "*"  # Everything
access_write:
  - "*"  # Everything
```

#### CEO
```yaml
access_read:
  - org/                          # Everything in org
  - .claude/agents/               # All agent definitions
access_write:
  - org/agents/ceo/               # Own workspace
  - org/initiatives/              # Strategic goals
  - org/messages/                 # Broadcasts
```

#### CAO
```yaml
access_read:
  - org/                          # Everything in org (needs to assess workforce)
  - .claude/agents/               # All agent definitions (manages them)
access_write:
  - org/agents/cao/               # Own workspace
  - org/agents/*/IDENTITY.md      # Updates agent configs (tools, access, status)
  - org/agents/*/SOUL.md          # Rewrites agent souls
  - org/agents/*/INSTRUCTIONS.md  # Updates instructions
  - org/agents/*/HEARTBEAT.md     # Updates heartbeats
  - org/orgchart.md               # Updates org structure
  - org/budgets/overview.md       # Reallocates budgets
  - .claude/agents/               # Creates/modifies agent definitions
```

#### Department Managers
```yaml
access_read:
  - org/agents/{self}/            # Own workspace
  - org/agents/{subordinates}/    # Subordinate workspaces
  - org/alignment.md              # Shared alignment
  - org/config.md                 # Shared config
  - org/orgchart.md               # Org structure
  - org/initiatives/              # Strategic goals
  - org/budgets/overview.md       # Budget overview (their allocation only)
  - org/messages/                 # Broadcasts and urgent
access_write:
  - org/agents/{self}/            # Own workspace
  - org/agents/{subordinates}/inbox/      # Send tasks/messages to subordinates
  - org/agents/{subordinates}/tasks/backlog/  # Assign tasks
```

#### Workers
```yaml
access_read:
  - org/agents/{self}/            # Own workspace
  - org/alignment.md              # Shared alignment
  - org/config.md                 # Shared config (language, tone)
  - org/orgchart.md               # Org structure (to know who to escalate to)
  - org/initiatives/              # Their relevant initiative
access_write:
  - org/agents/{self}/            # Own workspace only
  - org/agents/{manager}/inbox/   # Send messages to manager
```

### IDENTITY.md Access Specification

Each agent's IDENTITY.md includes explicit access lists:

```yaml
# In IDENTITY.md frontmatter
access_read:
  - org/agents/seo-agent/
  - org/alignment.md
  - org/config.md
  - org/orgchart.md
  - org/initiatives/q2-marketing-growth.md
access_write:
  - org/agents/seo-agent/
  - org/agents/marketing-manager/inbox/
```

### Access Control Hook: `data-access-check.sh`

A new PreToolUse hook that enforces data access control:

```bash
#!/usr/bin/env bash
# data-access-check.sh — Enforce data access control per agent
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Board has full access
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Extract target path from tool input
case "$TOOL" in
  Read|Glob)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // ""')
    ACCESS_TYPE="read"
    ;;
  Grep)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.path // ""')
    ACCESS_TYPE="read"
    ;;
  Write|Edit)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    ACCESS_TYPE="write"
    ;;
  *)
    exit 0  # Non-file tools are not access-controlled here
    ;;
esac

# If no target path, allow (some tools have optional paths)
if [[ -z "$TARGET" || "$TARGET" == "null" ]]; then exit 0; fi

# Read agent's access list from IDENTITY.md
IDENTITY_FILE="$ORG_DIR/agents/$AGENT/IDENTITY.md"
if [[ ! -f "$IDENTITY_FILE" ]]; then
  echo "No IDENTITY.md found for agent: $AGENT" >&2
  exit 2
fi

# Extract allowed paths based on access type
if [[ "$ACCESS_TYPE" == "read" ]]; then
  ALLOWED=$(awk '/^access_read:/,/^[a-z]/' "$IDENTITY_FILE" | grep '^ *-' | sed 's/^ *- *//')
else
  ALLOWED=$(awk '/^access_write:/,/^[a-z]/' "$IDENTITY_FILE" | grep '^ *-' | sed 's/^ *- *//')
fi

# Check if target matches any allowed path
while IFS= read -r allowed_path; do
  [[ -z "$allowed_path" ]] && continue
  # Check if target starts with the allowed path (prefix match)
  if [[ "$TARGET" == "$allowed_path"* || "$TARGET" == *"$allowed_path"* ]]; then
    exit 0  # Allowed
  fi
done <<< "$ALLOWED"

# Not allowed
echo "ACCESS DENIED: Agent '$AGENT' cannot $ACCESS_TYPE '$TARGET'. Request access from your superior." >&2
exit 2
```

### Settings.json Hook Registration

Add to `.claude/settings.json`:
```json
{
  "PreToolUse": [
    {
      "matcher": "Read|Write|Edit|Glob|Grep",
      "hooks": [{
        "type": "command",
        "command": "bash scripts/hooks/data-access-check.sh"
      }]
    }
  ]
}
```

### Data Access Request Workflow

When an agent needs access to data outside their scope:

```
Agent needs data → Creates access request → Sends to their SUPERIOR (not CAO)
     ↓
Superior reviews → If within their authority, approves
     ↓
Superior notifies CAO → CAO updates IDENTITY.md access lists
     ↓
Agent gets new access on next heartbeat run
```

**Access Request File Format:**

```markdown
---
id: request-access-20260331-100000-seo-agent
type: access-request
from: seo-agent
to: marketing-manager
status: pending
requested_access:
  - path: org/agents/social-media-agent/reports/
    mode: read
    reason: "Need to review social media performance data to align SEO content strategy with social media topics that are performing well"
  - path: org/budgets/overview.md
    mode: read
    reason: "Need to check remaining budget before proposing additional keyword research work"
timestamp: 2026-03-31T10:00:00
decided_by:
decided_date:
decision_reason:
---

## Data Access Request

### Requesting Agent
SEO Agent (@seo-agent) — reports to Marketing Manager (@marketing-manager)

### Current Access
- Read: own workspace, alignment, config, orgchart, q2-marketing-growth initiative
- Write: own workspace, marketing-manager inbox

### Requested Additional Access
1. **org/agents/social-media-agent/reports/** (read)
   - Justification: Cross-referencing social media performance with SEO metrics will improve content strategy. Social media trending topics often correlate with search volume spikes.
   
2. **org/budgets/overview.md** (read)
   - Justification: Need to understand budget constraints before proposing resource-intensive keyword research tasks.

### Duration
- Social media reports: Permanent (ongoing collaboration)
- Budget overview: Temporary (for current planning cycle)
```

### Data Access Request State Transitions

```
pending → approved by superior → CAO updates IDENTITY.md → access granted
pending → rejected by superior → agent notified, alternative suggested
pending → escalated to CEO → if cross-department access needed
```

---

## 3. Hook Enforcement Summary

### All Access Control Hooks

| Hook | Event | Matcher | Purpose |
|------|-------|---------|---------|
| `data-access-check.sh` | PreToolUse | Read\|Write\|Edit\|Glob\|Grep | Enforce per-agent file access |
| `require-cao-or-board.sh` | PreToolUse | Write\|Edit on `.claude/agents/*` | Only CAO/board modify agent definitions |
| `require-board-approval.sh` | PreToolUse | Write\|Edit on `org/board/decisions/*` | Only board writes decisions |
| `skill-access-check.sh` | PreToolUse | Skill(hire-agent)\|Skill(fire-agent)\|Skill(reconfigure-agent) | Only CAO/board can use agent management skills |
| `budget-check.sh` | PostToolUse | Write on `org/agents/*/tasks/*` | Check budget before task creation |
| `audit-log.sh` | PostToolUse | Write\|Edit | Log all file modifications |

### New Hook: `skill-access-check.sh`

Restricts agent management skills to CAO and board:

```bash
#!/usr/bin/env bash
# skill-access-check.sh — Only CAO or board can use agent management skills
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "cao" || "$AGENT" == "board" ]]; then
  exit 0  # Allow
else
  echo "Only CAO or Board can use agent management skills. Current: $AGENT" >&2
  exit 2  # Block
fi
```

Settings.json registration:
```json
{
  "matcher": "Skill",
  "if": "Skill(hire-agent)|Skill(fire-agent)|Skill(reconfigure-agent)",
  "hooks": [{
    "type": "command",
    "command": "bash scripts/hooks/skill-access-check.sh"
  }]
}
```

---

## 4. Heartbeat Script Integration

The heartbeat script must pass tool permissions per agent:

```bash
run_agent() {
  local agent_name="$1"
  local model=$(grep "model:" "$ORG_DIR/agents/$agent_name/IDENTITY.md" | head -1 | awk '{print $2}')
  
  # Extract tools from IDENTITY.md
  local tools=$(awk '/^tools:/,/^[a-z]/' "$ORG_DIR/agents/$agent_name/IDENTITY.md" | \
    grep '^ *-' | sed 's/^ *- *//' | tr '\n' ',' | sed 's/,$//')
  
  export ORGAGENT_CURRENT_AGENT="$agent_name"
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
  
  claude --agent "$agent_name" \
    -p "Run your heartbeat cycle. Today is $(date +%Y-%m-%d)." \
    --output-format json \
    --max-budget-usd "${MAX_BUDGET_PER_RUN:-5.00}" \
    --model "${model:-sonnet}" \
    --allowedTools "${tools:-Read,Write,Edit,Glob,Grep}" \
    2>&1 || true
}
```

---

## 5. Agent Context: Understanding the Permission System

Every agent must understand they can request tools and data access. This is achieved by including the following in EVERY agent's INSTRUCTIONS.md:

```markdown
## Requesting Additional Tools or Data Access

If you encounter a task that requires a tool or data you don't have access to:

1. **Do NOT attempt to use tools not listed in your IDENTITY.md** — you will be blocked
2. **Do NOT attempt to read files outside your access_read list** — you will be blocked
3. **Instead, create a request:**
   - For tools: Write a tool-request in `org/threads/requests/` AND send notification to CAO's inbox/
   - For data: Write an access-request in `org/threads/requests/` AND send notification to your supervisor's inbox/
4. **Include justification:** Which task requires it, why you need it, duration (permanent/temporary)
5. **Continue with other work** while waiting for approval
6. **On your next heartbeat**, check your inbox for the decision

Your available tools and data access are listed in your IDENTITY.md file.
```

---

## 6. CAO's Role in Permission Management

The CAO's INSTRUCTIONS.md includes a section on handling permission requests:

```markdown
## Permission Management

### Tool Requests
When you receive a tool-request in your inbox:
1. Read the request and justification
2. Identify the agent's manager from org/orgchart.md
3. Send a consultation message to the manager:
   - "Agent X requests tools Y for reason Z. Do you approve?"
4. Wait for manager's response (next heartbeat cycle)
5. If approved:
   - Update the agent's IDENTITY.md `tools` list
   - Update .claude/agents/{name}.md (add tools to agent definition)
   - Notify the agent via their inbox: "Tools approved and activated"
6. If rejected:
   - Notify the agent with the reason and suggest alternatives
7. Log all decisions in the audit trail

### Data Access Requests
These come from the agent's supervisor (not the agent directly):
1. Supervisor sends you a pre-approved access request
2. Update the agent's IDENTITY.md `access_read` or `access_write` lists
3. Notify the agent and supervisor
4. Log in audit trail

### Principle: Least Privilege
- Grant the minimum access needed for the task
- Prefer temporary access for one-off tasks
- Review access lists during org health checks (Phase 4 heartbeat)
- Remove access that is no longer needed
```
