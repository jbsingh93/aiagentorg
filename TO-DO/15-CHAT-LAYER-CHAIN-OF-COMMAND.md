# Chat Layer & Chain-of-Command — Complete Specification

**Date:** 2026-03-31
**Purpose:** The Agent Chat / Messaging system is a FIRST-CLASS architectural component — the communication backbone of the entire organisation. It enforces chain-of-command, routes messages, tracks conversations, and provides full visibility to the appropriate governance level.
**Source:** `TO-DO/AI-Agent-Organisation-high-level.png` — the right sidebar showing "Agent chat / messaging"

---

## Why This Is Critical

In a real company, communication IS the work. Without a structured communication layer:
- Workers could bypass their managers
- Departments could operate in silos with no coordination
- The board would have no visibility into what's happening
- There's no audit trail of decisions and discussions
- Cross-department initiatives would have no coordination mechanism

The Chat Layer is NOT just "inbox/outbox folders." It is a **structured communication system** that:
1. **Enforces chain-of-command** — who can talk to whom
2. **Routes messages** — direct, upward, downward, cross-department, broadcast
3. **Tracks conversations** — threading, context preservation, history
4. **Controls visibility** — board sees all, managers see their department, workers see their scope
5. **Enables coordination** — cross-department collaboration through formal channels
6. **Provides audit trail** — every communication is logged and traceable

---

## 1. Communication Rules — WHO Can Talk to WHOM

### The Chain-of-Command Matrix

```
                  Board   CEO    CAO    Manager-A  Manager-B  Worker-A1  Worker-B1
Board              —      ✓D     ✓ D    ✓ D        ✓ D        ✓ D        ✓ D
CEO               ✓ U     —      ✓ D    ✓ D        ✓ D        ✗ *        ✗ *
CAO               ✓ U    ✓ L     —      ✓ D        ✓ D        ✓ D **     ✓ D **
Manager-A         ✗ E    ✓ U    ✓ U     —          ✓ X ***    ✓ D        ✗
Manager-B         ✗ E    ✓ U    ✓ U    ✓ X ***      —         ✗          ✓ D
Worker-A1         ✗ E    ✗ E    ✓ R    ✓ U          ✗ R       ✓ L        ✗ R
Worker-B1         ✗ E    ✗ E    ✓ R    ✗ R         ✓ U        ✗ R        ✓ L

Legend:
✓ D = Direct (can message freely downward)
✓ U = Upward (can message supervisor)
✓ L = Lateral (can message peer in same department)
✓ X = Cross-department (requires formal protocol)
✓ R = Request only (can send a formal request, not casual messages)
✗   = Cannot communicate directly
✗ E = Must escalate through chain (worker → manager → CEO → board)
✗ R = Must request through chain (worker → manager → target manager)
*   = CEO messages workers via their manager, not directly
**  = CAO can message any agent for workforce management purposes
*** = Cross-department requires formal protocol (see section 3)
```

### Rules by Role

#### Board (Human)
- **Can message:** Anyone (full access)
- **Visibility:** All messages across the entire organisation
- **Special:** Board messages are marked as `priority: board-directive` and are always processed first

#### CEO
- **Can message directly:** CAO, all managers
- **Cannot message directly:** Workers (must delegate through managers)
- **Upward:** Board (via approvals or escalations)
- **Broadcasts:** Can send org-wide broadcasts via `org/messages/broadcast-*.md`
- **Exception:** In emergency situations, CEO CAN message any agent with `priority: urgent`

#### CAO
- **Can message directly:** CEO, all managers, ALL agents (for workforce management)
- **Special authority:** The CAO is the only non-board entity that can message across all levels — this is because the CAO manages the workforce and needs to communicate with any agent about their role, tools, access, or performance
- **Upward:** CEO, Board (via approvals)

#### Department Managers
- **Can message directly:** CEO (upward), CAO (lateral/requests), their own workers (downward), peer managers (cross-department protocol)
- **Cannot message directly:** Other departments' workers
- **Upward:** CEO for strategic matters, CAO for workforce matters
- **Downward:** Their direct reports only

#### Workers
- **Can message directly:** Their manager (upward), peers in same department (lateral)
- **Cannot message directly:** CEO, Board, other departments' agents
- **Requests:** Can send formal requests to CAO (tool/access requests go in `org/threads/requests/`)
- **Escalation:** If manager is unavailable, can escalate to CEO via formal escalation message (not casual)

---

## 2. Message Types & Routing

### Message Types

| Type | Code | Description | Routing |
|------|------|-------------|---------|
| **Directive** | `directive` | Order from superior to subordinate | Downward only |
| **Report** | `report` | Status update from subordinate to superior | Upward only |
| **Request** | `request` | Request for resources, tools, access, approval | Upward or to CAO |
| **Escalation** | `escalation` | Issue that needs higher authority | Strictly upward through chain |
| **Notification** | `notification` | FYI message (task assigned, task completed, etc.) | Any allowed direction |
| **Discussion** | `discussion` | Collaborative exchange between peers or adjacent levels | Lateral or adjacent |
| **Broadcast** | `broadcast` | Org-wide or department-wide announcement | Board/CEO: org-wide. Manager: department-wide |
| **Urgent** | `urgent` | Emergency requiring immediate attention | Can bypass normal chain (CEO+ only) |
| **Cross-dept** | `cross-dept` | Cross-department coordination | Via formal protocol (see section 3) |
| **Board-directive** | `board-directive` | Direct order from human board | Top priority, to any agent |

### Message File Format (Enhanced)

```markdown
---
id: msg-20260331-100500-ceo
type: directive
from: ceo
to: marketing-manager
timestamp: 2026-03-31T10:05:00
priority: normal
read: false
subject: Q2 Marketing Strategy Kickoff
thread_id: thread-q2-marketing-20260331
reply_to:
chain_validated: true
---

Please prioritize the Q2 marketing initiative. I've created the initiative
document at `org/initiatives/q2-marketing-growth.md`.

Key objectives:
1. Increase organic traffic by 30%
2. Launch social media presence on 3 platforms
3. Stay within the marketing budget allocation

Please create a plan and assign tasks to your team by end of week.

Ref: org/initiatives/q2-marketing-growth.md
```

### New Fields Explained

| Field | Type | Purpose |
|-------|------|---------|
| `type` | enum | Message type (directive, report, request, escalation, etc.) |
| `thread_id` | string | Groups related messages into a conversation thread |
| `reply_to` | string | ID of the message this is replying to (enables threading) |
| `chain_validated` | boolean | Whether the chain-of-command hook verified this message is allowed |

---

## 3. Cross-Department Communication Protocol

When agents from different departments need to coordinate:

### The Formal Protocol

```
Worker-A needs info from Worker-B (different department)
     ↓
Step 1: Worker-A sends REQUEST to Manager-A
        "I need X data from Department B for task Y"
     ↓
Step 2: Manager-A evaluates the request
        If approved: Manager-A sends CROSS-DEPT message to Manager-B
        "My agent needs X. Can your team provide it?"
     ↓
Step 3: Manager-B evaluates and responds
        If approved: Manager-B instructs Worker-B to prepare data
        Worker-B sends data via the cross-dept thread
     ↓
Step 4: Manager-B forwards data to Manager-A
        Manager-A forwards to Worker-A
     ↓
Step 5: All steps logged in both departments' audit trails
```

### Why This Matters

- **Prevents chaos** — 20 agents freely messaging each other = noise
- **Maintains accountability** — managers know what their team is doing
- **Enables oversight** — board can see cross-department coordination
- **Mirrors real companies** — departments coordinate through their leaders

### When to Bypass the Protocol

The protocol can be simplified when:
- `oversight_level: hands-off` — managers can authorize direct cross-dept worker communication
- The CEO explicitly creates a cross-department initiative with shared access
- An Agent Team is formed for a specific cross-department deliverable

---

## 4. Chain-of-Command Enforcement Hook

### `message-routing-check.sh`

A new PreToolUse hook that validates messages follow chain-of-command rules:

```bash
#!/usr/bin/env bash
# message-routing-check.sh — Enforce chain-of-command communication rules
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
TARGET_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Only check Write operations to inbox directories
if [[ "$TOOL" != "Write" ]]; then exit 0; fi
if [[ "$TARGET_PATH" != *"/inbox/"* ]]; then exit 0; fi

# Board has full access
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Extract target agent from path (org/agents/{target}/inbox/...)
TARGET_AGENT=$(echo "$TARGET_PATH" | grep -o 'agents/[^/]*' | sed 's/agents\///')
if [[ -z "$TARGET_AGENT" ]]; then exit 0; fi

# CAO can message anyone (workforce management authority)
if [[ "$AGENT" == "cao" ]]; then exit 0; fi

# Read orgchart to determine relationships
ORGCHART="$ORG_DIR/orgchart.md"
if [[ ! -f "$ORGCHART" ]]; then exit 0; fi  # No orgchart = allow (bootstrapping)

# Find the sender's supervisor
SENDER_LINE=$(grep "@$AGENT" "$ORGCHART" | head -1)
SENDER_DEPTH=$(echo "$SENDER_LINE" | sed 's/[^ ].*//' | wc -c)
# Depth in chars / 2 = hierarchy level

# Find the target's supervisor
TARGET_LINE=$(grep "@$TARGET_AGENT" "$ORGCHART" | head -1)
TARGET_DEPTH=$(echo "$TARGET_LINE" | sed 's/[^ ].*//' | wc -c)

# Get sender's supervisor (line above with less indentation)
get_supervisor() {
  local agent_id="$1"
  local agent_line_num=$(grep -n "@$agent_id" "$ORGCHART" | head -1 | cut -d: -f1)
  local agent_depth=$(sed -n "${agent_line_num}p" "$ORGCHART" | sed 's/[^ ].*//' | wc -c)
  
  # Walk up the file to find the first line with less indentation
  local n=$((agent_line_num - 1))
  while [ $n -gt 0 ]; do
    local line_depth=$(sed -n "${n}p" "$ORGCHART" | sed 's/[^ ].*//' | wc -c)
    if [ "$line_depth" -lt "$agent_depth" ]; then
      sed -n "${n}p" "$ORGCHART" | grep -o '@[a-z0-9-]*' | sed 's/@//'
      return
    fi
    n=$((n - 1))
  done
  echo "board"
}

SENDER_SUPERVISOR=$(get_supervisor "$AGENT")
TARGET_SUPERVISOR=$(get_supervisor "$TARGET_AGENT")

# Rule 1: Can always message your direct supervisor
if [[ "$TARGET_AGENT" == "$SENDER_SUPERVISOR" ]]; then exit 0; fi

# Rule 2: Can always message your direct reports
# (target's supervisor is the sender)
if [[ "$AGENT" == "$TARGET_SUPERVISOR" ]]; then exit 0; fi

# Rule 3: Can message peers in the same department
# (same supervisor)
if [[ "$SENDER_SUPERVISOR" == "$TARGET_SUPERVISOR" ]]; then exit 0; fi

# Rule 4: CEO can message any manager
if [[ "$AGENT" == "ceo" ]]; then
  # Check if target is a manager (depth 2 in orgchart = depth level ~6 chars)
  if [[ "$TARGET_DEPTH" -le 8 ]]; then exit 0; fi
fi

# Rule 5: Managers can message peer managers (cross-department)
# Both at depth 2, both report to CEO
if [[ "$SENDER_SUPERVISOR" == "ceo" && "$TARGET_SUPERVISOR" == "ceo" ]]; then exit 0; fi

# Rule 6: Check for urgent messages (bypass allowed)
# Read the message content to check if it's marked urgent
MESSAGE_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
if echo "$MESSAGE_CONTENT" | grep -q "priority: urgent"; then
  if [[ "$AGENT" == "ceo" || "$SENDER_DEPTH" -le 6 ]]; then
    exit 0  # CEO and executives can send urgent to anyone
  fi
fi

# Not allowed — chain-of-command violation
echo "CHAIN-OF-COMMAND VIOLATION: Agent '$AGENT' cannot directly message '$TARGET_AGENT'. Message your supervisor '$SENDER_SUPERVISOR' to route this communication." >&2
exit 2
```

### Settings.json Registration

Add to the PreToolUse hooks:

```json
{
  "matcher": "Write",
  "if": "Write(org/agents/*/inbox/*)",
  "hooks": [{
    "type": "command",
    "command": "bash scripts/hooks/message-routing-check.sh"
  }]
}
```

---

## 5. Threading & Conversation Tracking

### Thread IDs

Messages belong to conversation threads. A thread is a sequence of related messages.

**Thread ID format:** `thread-{topic-slug}-{YYYYMMDD}`

Example conversation thread:

```
Thread: thread-q2-marketing-20260331

msg-20260331-100500-ceo        → CEO to Marketing Manager: "Kickoff Q2 marketing"
  msg-20260331-110000-marketing-manager → MM to CEO: "Understood. Plan ready by Friday."
    msg-20260331-140000-ceo    → CEO to MM: "Good. Prioritize SEO."
msg-20260331-110500-marketing-manager → MM to SEO Agent: "Start keyword research"
  msg-20260331-120000-seo-agent → SEO to MM: "Started. Need WebSearch tool."
    msg-20260331-120100-marketing-manager → MM to CAO: "SEO agent needs WebSearch"
```

### How Threading Works

1. First message in a thread: `thread_id: thread-{topic}-{date}`, `reply_to:` (empty)
2. Reply: Same `thread_id`, `reply_to: {parent_message_id}`
3. Agents include `thread_id` and `reply_to` when responding to keep context

### Thread Reconstruction

The GUI (or any reader) reconstructs threads by:
1. Reading the thread file directly (all messages are in one file)
2. Sorting by timestamp
3. Building a reply tree using `reply_to` references

---

## 6. Communication Visibility Rules

### Who Sees What

| Observer | Can See Messages |
|----------|-----------------|
| **Board** | ALL messages across the entire org (full visibility via GUI) |
| **CEO** | All messages to/from CEO + all messages involving direct reports |
| **CAO** | All messages to/from CAO + all messages involving workforce management |
| **Manager** | All messages within their department (to/from them + between their workers) |
| **Worker** | Only messages to/from themselves |

### Implementation

Visibility is enforced at the GUI/API level:

```javascript
// gui/api/messages.js
function getVisibleMessages(agentId, orgDir) {
  if (agentId === 'board') return getAllMessages(orgDir);
  
  // Get agent's department (subordinates + self)
  const department = getDepartmentAgents(agentId, orgDir);
  
  // Collect messages from all agents in department
  const messages = [];
  for (const agent of department) {
    messages.push(...getAgentInbox(agent, orgDir));
    messages.push(...getAgentOutbox(agent, orgDir));
  }
  return deduplicateByMessageId(messages);
}
```

The data access hooks handle file-level access. The GUI provides the filtered view.

---

## 7. The Message Skill (Enhanced)

The `/message` skill must enforce chain-of-command:

```yaml
---
name: message
description: "Send an inter-agent message following chain-of-command rules. Validates routing before delivery."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[from] [to] [message] — or omit for interactive mode"
---

# Send Inter-Agent Message

## Step 1: Determine sender and recipient
- If `$ARGUMENTS` provided: parse from, to, and message
- If no arguments: ask the user who should send what to whom

## Step 2: Validate chain-of-command
Before sending, verify the communication is allowed:

1. Read `org/orgchart.md` to determine relationships
2. Determine the sender's position, supervisor, and direct reports
3. Determine the recipient's position, supervisor, and direct reports
4. Check if the message route is allowed per chain-of-command rules:
   - Downward to direct reports: ALLOWED
   - Upward to direct supervisor: ALLOWED
   - Lateral to same-department peers: ALLOWED
   - CAO to anyone: ALLOWED (workforce management)
   - CEO to any manager: ALLOWED
   - Cross-department managers: ALLOWED (but note it in the message type)
   - Worker to non-supervisor: BLOCKED — suggest routing through their manager
   - Skip-level (worker to CEO): BLOCKED — suggest escalation through manager

5. If BLOCKED: tell the user why and suggest the correct route
   Example: "SEO Agent cannot message the CEO directly. The message should go to Marketing Manager, who can escalate to CEO if needed."

## Step 3: Determine message type
Based on the content and direction:
- Superior → subordinate: `directive` or `notification`
- Subordinate → superior: `report`, `request`, or `escalation`
- Peer → peer: `discussion`
- CEO/Board → all: `broadcast`
- Cross-department: `cross-dept`

## Step 4: Create thread context
- If this relates to an existing thread: use the same `thread_id`
- If this is a new topic: generate `thread-{topic-slug}-{YYYYMMDD}`

## Step 5: Write the message
1. Create message file in recipient's `inbox/`:
   - Filename: `msg-{YYYYMMDD}-{HHMMSS}-{from}.md`
   - Include all frontmatter fields (type, thread_id, reply_to, chain_validated: true)
2. If `priority: urgent`: also copy a notification to `org/messages/urgent/`

## Step 6: Confirm delivery
Tell the user: "Message sent from @{from} to @{to}: {subject}"
```

---

## 8. The Escalation Skill (Enhanced)

Escalation follows a strict upward path:

```yaml
---
name: escalate
description: "Escalate an issue through the chain-of-command. Always goes UP — never sideways or down."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent] [issue] — escalate an issue from agent to their supervisor"
---

# Escalate Issue Through Chain-of-Command

## Escalation Rules
- Escalation ALWAYS goes UP one level at a time
- Worker → their Manager → CEO → Board
- An escalation cannot skip levels
- Each level can resolve the issue or escalate further

## Step 1: Identify the escalating agent and their supervisor
- Read `org/orgchart.md`
- Find the agent's direct supervisor

## Step 2: Create escalation message
Write to the supervisor's inbox with:
- `type: escalation`
- `priority: high`
- Clear description of the issue
- What the agent has already tried
- What decision or action is needed

## Step 3: If the supervisor cannot resolve
The supervisor escalates to THEIR supervisor with:
- The original issue
- Their assessment
- Recommended action

## Step 4: Board escalation
If an issue reaches the board:
- Write to `org/board/approvals/` as a decision request
- Include the full escalation chain (who escalated, when, why at each level)
```

---

## 9. GUI Chat View

The screenshot shows a dedicated **Agent Chat / Messaging** panel. In the GUI:

### Chat View Specification

```
┌──────────────────────────────────────────────────────┐
│  Agent Chat / Messaging                         🔍   │
├──────────────────────────────────────────────────────┤
│  Filters: [All] [Department ▼] [Agent ▼] [Type ▼]   │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌ Thread: Q2 Marketing Strategy ─────────────────┐  │
│  │ 🎯 CEO → 📢 Marketing Manager       10:05    │  │
│  │ "Kickoff Q2 marketing. Prioritize SEO."       │  │
│  │                                                │  │
│  │   📢 Marketing Manager → 🎯 CEO     11:00    │  │
│  │   "Understood. Plan ready by Friday."         │  │
│  │                                                │  │
│  │   📢 Marketing Manager → 🔍 SEO Agent 11:05  │  │
│  │   "Start keyword research for Q2."            │  │
│  │                                                │  │
│  │     🔍 SEO Agent → 📢 Marketing Mgr  12:00   │  │
│  │     "Started. Need WebSearch tool."           │  │
│  │                                                │  │
│  │   📢 Marketing Manager → 🏗️ CAO      12:01   │  │
│  │   "SEO agent needs WebSearch capability."     │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ┌ Thread: Hiring SEO Agent ──────────────────────┐  │
│  │ 🎯 CEO → 🏗️ CAO                     09:30    │  │
│  │ "We need an SEO specialist."                  │  │
│  │                                                │  │
│  │   🏗️ CAO → 📢 Marketing Manager     09:45    │  │
│  │   "Consulting on SEO Agent role design."      │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
├──────────────────────────────────────────────────────┤
│  [Send as Board] To: [Agent ▼] Message: [______]  📤│
└──────────────────────────────────────────────────────┘
```

### Chat API Endpoint

```javascript
// GET /api/messages?filter=all|department|agent&thread=id&type=directive|report|...
// Returns messages grouped by thread, sorted by timestamp
// Respects visibility rules based on the viewing agent (board sees all)

// POST /api/messages
// Send a message as the board
// Body: { from: "board", to: "ceo", subject: "...", body: "...", type: "board-directive" }
```

### Chat View Features

1. **Thread grouping** — Messages grouped by `thread_id`, collapsed/expandable
2. **Chronological within threads** — Newest thread at top, messages within thread in chronological order
3. **Agent avatars** — Emoji from IDENTITY.md displayed next to each message
4. **Message type badges** — Color-coded: directive (blue), report (green), escalation (red), request (yellow)
5. **Department filter** — Show only messages within a specific department
6. **Chain-of-command visualization** — Indentation shows the routing chain
7. **Send as Board** — Input field to send messages as the board (human)
8. **Unread indicators** — Highlight messages with `read: false`
9. **Search** — Full-text search across all visible messages

---

## 10. Agent Instructions Update

Every agent's INSTRUCTIONS.md must include a Communication section:

```markdown
## Communication Rules

### Who You Can Message
- Your direct supervisor: @{supervisor} (upward reports, escalations, requests)
- Your direct reports: @{list} (directives, task assignments, feedback)
- Peers in your department: @{peers} (discussion, collaboration)
- CAO: @cao (tool requests, access requests ONLY)

### Who You CANNOT Message Directly
- Agents in other departments (route through your manager)
- Skip-level superiors (escalate through your manager)
- The board (escalate through the chain: you → manager → CEO → board)

### Message Types You Can Send
- **report** — to your supervisor (status updates, task completion)
- **request** — to your supervisor or CAO (resources, tools, access, help)
- **escalation** — to your supervisor (issues you cannot resolve)
- **notification** — to your reports (task assignments, FYI)
- **discussion** — to peers (collaboration, questions)

### Threading
- When replying to a message, use the same `thread_id` and set `reply_to`
- When starting a new topic, create a new `thread_id`: `thread-{topic}-{date}`

### Cross-Department Collaboration
If you need information from another department:
1. Send a request to your manager explaining what you need and why
2. Your manager will coordinate with the other department's manager
3. Do NOT attempt to message agents in other departments directly

### Urgent Messages
You CANNOT send urgent messages. Only CEO and board can use `priority: urgent`.
If you have an urgent matter, escalate to your supervisor with `type: escalation` and `priority: high`.
```

---

## 11. Updated Hook Count

This adds 1 new hook script:

| # | Hook | Purpose |
|---|------|---------|
| 1 | data-access-check.sh | Chain-of-command data access |
| 2 | message-routing-check.sh | **NEW** — Chain-of-command message routing |
| 3 | require-board-approval.sh | Board-only decisions |
| 4 | require-cao-or-board.sh | Agent definition protection |
| 5 | skill-access-check.sh | Agent management skill restriction |
| 6 | budget-check.sh | Budget enforcement |
| 7 | audit-log.sh | All-write audit logging |
| 8 | log-agent-activation.sh | Agent session start |
| 9 | log-agent-deactivation.sh | Agent session end |
| 10 | post-cycle-summary.sh | Session completion |

**Total hooks: 10**

---

## 12. How This Integrates With Everything

### Heartbeat Integration
During heartbeat, each agent's HEARTBEAT.md step 2 ("Process inbox") now involves:
- Reading messages in chronological order
- Checking thread context (read `reply_to` chain for history)
- Responding within the chain-of-command rules
- Routing cross-department requests through manager

### GUI Integration
The "Agent Chat / Messaging" view in the GUI dashboard becomes a DEDICATED TAB (not just a feed):
- Thread-based view with filtering
- Real-time updates (polling every 5 seconds)
- Board can send messages directly from the GUI
- Department-scoped views for managers

### Onboarding Integration
The `/onboard` skill creates CEO and CAO with full communication instructions baked into their INSTRUCTIONS.md. The CAO's instructions include how to handle communication about tool/access requests.

### Data Access Integration
The `data-access-check.sh` hook already controls file reads. The `message-routing-check.sh` hook controls writes to inbox directories. Together they form a complete access control layer.

### Audit Integration
Every message write triggers the `audit-log.sh` PostToolUse hook, ensuring all communications are logged.
