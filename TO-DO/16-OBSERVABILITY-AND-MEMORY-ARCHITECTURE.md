# Observability & Memory Architecture — Complete Specification

**Date:** 2026-03-31
**Purpose:** Three-layer observability system ensuring every agent's cognitive state, actions, and communications are fully traceable at all times. Plus the thread-based chat architecture replacing inbox/outbox.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    THREE-LAYER OBSERVABILITY                      │
│                                                                   │
│  Layer 1: ACTIVITY STREAM (hook-forced, immutable)               │
│  ├── Every file operation logged automatically                    │
│  ├── org/agents/{name}/activity/YYYY-MM-DD.md                    │
│  └── Long-term memory — "what happened" (objective)              │
│                                                                   │
│  Layer 2: CURRENT STATE (agent-maintained, enforced by hooks)    │
│  ├── What agent is doing RIGHT NOW                               │
│  ├── org/agents/{name}/activity/current-state.md                 │
│  └── Short-term memory — "what I'm thinking" (subjective)       │
│                                                                   │
│  Layer 3: THREAD-BASED CHAT (replaces inbox/outbox)              │
│  ├── Full conversations in single files                          │
│  ├── org/threads/{department}/*.md                               │
│  ├── Greppable message IDs per message                           │
│  └── Lightweight notifications in agent inbox/                   │
│                                                                   │
│  ENFORCEMENT: Hooks force compliance                             │
│  ├── PostToolUse: activity-logger.sh (auto-logs every action)    │
│  ├── PostToolUse: remind-state-update.sh (periodic reminder)     │
│  └── Stop: require-state-and-communication.sh (blocks if stale) │
└─────────────────────────────────────────────────────────────────┘
```

---

## LAYER 1: Activity Stream (Long-Term Memory)

### What It Is

An immutable, hook-generated chronological log of EVERY file operation an agent performs. The agent cannot skip or modify this — hooks force it.

### File Location

```
org/agents/{name}/activity/
├── 2026-03-31.md          # Today's activity stream
├── 2026-04-01.md          # Tomorrow's
└── ...                    # One file per day, forever
```

### File Format

```markdown
# Activity Stream — Marketing Manager — 2026-03-31

| Time | Tool | Action | Target | Summary |
|------|------|--------|--------|---------|
| 10:00:01 | Read | read | org/alignment.md | Context loading: alignment |
| 10:00:02 | Read | read | org/config.md | Context loading: config |
| 10:00:03 | Read | read | org/agents/marketing-manager/SOUL.md | Context loading: identity |
| 10:00:04 | Read | read | org/agents/marketing-manager/IDENTITY.md | Context loading: role |
| 10:00:05 | Read | read | org/agents/marketing-manager/INSTRUCTIONS.md | Context loading: procedures |
| 10:00:06 | Read | read | org/agents/marketing-manager/MEMORY.md | Context loading: knowledge |
| 10:00:07 | Read | read | org/agents/marketing-manager/inbox/notif-20260331-100000.md | Inbox: new thread notification |
| 10:00:08 | Read | read | org/threads/marketing/thread-q2-seo-20260331.md | Reading thread context |
| 10:00:10 | Write | create | org/agents/marketing-manager/activity/current-state.md | State update: starting task |
| 10:00:15 | Write | create | org/agents/seo-agent/tasks/backlog/task-20260331-002.md | Delegated: keyword research |
| 10:00:16 | Edit | append | org/threads/marketing/thread-q2-seo-20260331.md | Sent directive to @seo-agent |
| 10:00:17 | Write | create | org/agents/seo-agent/inbox/notif-20260331-100016.md | Notification to @seo-agent |
| 10:00:20 | Edit | update | org/agents/marketing-manager/activity/current-state.md | State update: step 3 complete |
| 10:00:25 | Write | create | org/agents/marketing-manager/reports/daily-2026-03-31.md | Daily report |
| 10:00:26 | Edit | update | org/agents/marketing-manager/activity/current-state.md | State update: cycle complete |
```

### Hook: `activity-logger.sh` (Replaces `audit-log.sh`)

This hook fires on EVERY PostToolUse for Read, Write, Edit, Glob, Grep, Bash. It writes to BOTH the agent's activity stream AND the org-wide audit log.

```bash
#!/usr/bin/env bash
# activity-logger.sh — Log every file operation to agent's activity stream + audit log
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // "unknown"')
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date +%H:%M:%S)
FULL_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")

# Determine target and action based on tool type
case "$TOOL" in
  Read)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    ACTION="read"
    SUMMARY="Read file"
    ;;
  Write)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    ACTION="create"
    # Extract a summary from the content (first 80 chars of first non-frontmatter line)
    SUMMARY=$(echo "$INPUT" | jq -r '.tool_input.content // ""' | grep -v '^---' | grep -v '^$' | head -1 | cut -c1-80)
    [[ -z "$SUMMARY" ]] && SUMMARY="File written"
    ;;
  Edit)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // "unknown"')
    ACTION="update"
    SUMMARY="File edited"
    ;;
  Glob)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.pattern // "unknown"')
    ACTION="search"
    SUMMARY="File pattern search"
    ;;
  Grep)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.pattern // "unknown"')
    ACTION="search"
    SUMMARY="Content search"
    ;;
  Bash)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.command // "unknown"' | cut -c1-80)
    ACTION="exec"
    SUMMARY="Command executed"
    ;;
  *)
    TARGET="—"
    ACTION="$TOOL"
    SUMMARY="Tool used"
    ;;
esac

# === Write to agent's activity stream ===
if [[ "$AGENT" != "board" ]]; then
  ACTIVITY_DIR="$ORG_DIR/agents/$AGENT/activity"
  ACTIVITY_FILE="$ACTIVITY_DIR/$TODAY.md"
  
  # Create activity directory and file header if needed
  mkdir -p "$ACTIVITY_DIR"
  if [[ ! -f "$ACTIVITY_FILE" ]]; then
    echo "# Activity Stream — $AGENT — $TODAY" > "$ACTIVITY_FILE"
    echo "" >> "$ACTIVITY_FILE"
    echo "| Time | Tool | Action | Target | Summary |" >> "$ACTIVITY_FILE"
    echo "|------|------|--------|--------|---------|" >> "$ACTIVITY_FILE"
  fi
  
  # Append activity entry
  echo "| $TIMESTAMP | $TOOL | $ACTION | $TARGET | $SUMMARY |" >> "$ACTIVITY_FILE"
fi

# === Write to org-wide audit log ===
AUDIT_FILE="$ORG_DIR/board/audit-log.md"
if [[ -f "$AUDIT_FILE" ]]; then
  echo "| $FULL_TIMESTAMP | $AGENT | $ACTION | $TARGET | $SUMMARY |" >> "$AUDIT_FILE"
fi

exit 0
```

### Hook Registration (replaces old `audit-log.sh`)

```json
{
  "PostToolUse": [
    {
      "matcher": "Read|Write|Edit|Glob|Grep|Bash",
      "hooks": [{
        "type": "command",
        "command": "bash scripts/hooks/activity-logger.sh"
      }]
    }
  ]
}
```

**Note:** This REPLACES the old `audit-log.sh` — the activity-logger now handles both per-agent activity streams AND the org-wide audit log in a single hook.

### Supervisor Access

| Observer | Can Read Activity Streams Of |
|----------|------------------------------|
| Board | ALL agents |
| CEO | ALL agents |
| CAO | ALL agents (workforce management) |
| Manager | Self + direct subordinates |
| Worker | Self only |

This is enforced by the existing `data-access-check.sh` hook via `access_read` in IDENTITY.md:
```yaml
# Marketing Manager IDENTITY.md
access_read:
  - org/agents/marketing-manager/activity/
  - org/agents/seo-agent/activity/
  - org/agents/social-media-agent/activity/
```

---

## LAYER 2: Current State (Short-Term Memory)

### What It Is

A single file per agent that captures their CURRENT cognitive state — what they're working on, what step they're at, what they plan to do next, what files they're touching. Updated by the agent at key milestones. Enforced by hooks.

### File Location

```
org/agents/{name}/activity/current-state.md
```

### File Format — Complete Specification

```markdown
---
agent: marketing-manager
updated: 2026-03-31T10:05:00
status: working
current_task_id: task-20260331-001
current_task_title: Create Q2 content strategy
current_step: 3
total_steps: 5
heartbeat_cycle: 3
session_start: 2026-03-31T10:00:00
---

# Current State — Marketing Manager

## Status: WORKING on task-20260331-001

## Progress
- Step 1: Read CEO directive ✅
- Step 2: Review initiative document ✅
- Step 3: Delegate keyword research to @seo-agent 🔄 IN PROGRESS
- Step 4: Draft content calendar ⬜ PENDING
- Step 5: Write report to CEO ⬜ PENDING

## Current Action
Creating task file for @seo-agent with keyword research requirements.
Target file: org/agents/seo-agent/tasks/backlog/task-20260331-002.md

## Active Decision
Prioritizing SEO over social media for first 2 weeks of Q2.
Reasoning: Organic search has higher long-term ROI. Social media can start in week 3 when content pipeline is established.

## Files In Active Use
- READING: org/initiatives/q2-marketing-growth.md (initiative context)
- WRITING: org/agents/seo-agent/tasks/backlog/task-20260331-002.md (delegation)
- WILL WRITE: org/threads/marketing/thread-q2-seo-20260331.md (directive message)
- WILL WRITE: org/agents/seo-agent/inbox/notif-*.md (notification)

## Open Threads
- [thread-q2-seo-20260331] Q2 SEO Strategy — ACTIVE, sending directive to @seo-agent
- [thread-content-calendar-20260331] Content Calendar — PENDING, will start after delegation

## Blockers
None.

## Completed This Cycle
- Processed 2 inbox notifications
- Read CEO directive about Q2 marketing priorities
- Reviewed Q2 marketing initiative document
- Made strategic decision: SEO-first approach

## Queue (After Current Task)
1. Check if @seo-agent has any pending requests
2. Review department budget in org/budgets/overview.md
3. Write daily report to reports/daily-2026-03-31.md
4. Update MEMORY.md with strategic decisions

## Reasoning Trace
CEO prioritized "organic growth." Initiative KR1 is "30% organic traffic increase."
This directly maps to SEO work. Social media (KR2) is "establish presence" which is
less urgent than growth. Therefore: SEO first, social media second.
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `agent` | string | Agent ID |
| `updated` | datetime | Last time this file was modified |
| `status` | enum | `working`, `idle`, `blocked`, `waiting`, `completing` |
| `current_task_id` | string | ID of the task being worked on (or empty) |
| `current_task_title` | string | Human-readable task title |
| `current_step` | number | Current step number in the task |
| `total_steps` | number | Total steps planned for current task |
| `heartbeat_cycle` | number | Which heartbeat cycle today (1, 2, 3...) |
| `session_start` | datetime | When this agent session started |

### Sections Explained

| Section | Purpose | Updated When |
|---------|---------|-------------|
| **Status** | One-line summary of current state | Every milestone |
| **Progress** | Step-by-step checklist for current task | Each step completion |
| **Current Action** | Exactly what agent is doing RIGHT NOW | Before each significant action |
| **Active Decision** | Latest reasoning/decision with justification | When making decisions |
| **Files In Active Use** | Which files being read/written/planned | When file focus changes |
| **Open Threads** | Which conversation threads are active | When threads change |
| **Blockers** | Anything preventing progress | When blockers appear/resolve |
| **Completed This Cycle** | Summary of actions taken | After each action |
| **Queue** | What agent plans to do next | When plans change |
| **Reasoning Trace** | WHY decisions were made | When making non-obvious decisions |

### When Agents MUST Update current-state.md

1. **Session start** — Create the file with initial state
2. **Starting a task** — Update current_task, steps, status
3. **Completing a step** — Update progress checklist
4. **Making a decision** — Update Active Decision + Reasoning Trace
5. **Changing files** — Update Files In Active Use
6. **Encountering a blocker** — Update Blockers section
7. **Session end** — Update status to `idle`, clear current action, write final Queue

---

## LAYER 3: Thread-Based Chat (Replaces Inbox/Outbox)

### Architecture Change

**ELIMINATED:**
- `org/agents/{name}/outbox/` — removed entirely
- Large message files in `inbox/` — replaced by lightweight notifications

**NEW:**
- `org/threads/` — conversation thread files (single source of truth)
- `org/agents/{name}/inbox/` — lightweight notifications only

### Thread Directory Structure

```
org/threads/
├── executive/                      # Board, CEO, CAO conversations
│   ├── thread-strategic-plan-20260331.md
│   └── thread-budget-review-20260331.md
├── marketing/                      # Marketing department
│   ├── thread-q2-seo-20260331.md
│   └── thread-content-calendar-20260331.md
├── sales/                          # Sales department
│   └── thread-webshop-strategy-20260331.md
├── cross-dept/                     # Cross-department coordination
│   └── thread-seo-social-alignment-20260331.md
├── requests/                       # Tool, access, hire requests
│   ├── request-tool-seo-websearch-20260331.md
│   └── request-hire-social-agent-20260331.md
└── index.md                        # Master thread index
```

### Thread File Format

```markdown
---
thread_id: thread-q2-seo-20260331
topic: Q2 SEO Strategy Kickoff
department: marketing
participants:
  - ceo
  - marketing-manager
  - seo-agent
status: active
created: 2026-03-31T10:05:00
last_activity: 2026-03-31T12:00:00
message_count: 4
---

# Thread: Q2 SEO Strategy Kickoff

---
### [MSG-20260331-100500-ceo] 2026-03-31T10:05:00 — 🎯 CEO → 📢 Marketing Manager [directive]

Kickoff Q2 marketing. Prioritize SEO strategy.
See: `org/initiatives/q2-marketing-growth.md`
Target: 30% organic traffic growth by end of Q2.

---
### [MSG-20260331-110000-marketing-manager] 2026-03-31T11:00:00 — 📢 Marketing Manager → 🎯 CEO [report]

Understood. My plan:
1. Delegate keyword research to @seo-agent (this cycle)
2. Draft content calendar (by Friday)
3. Present full strategy next heartbeat

Strategic decision: Prioritizing SEO over social media for first 2 weeks — organic traffic has higher ROI.

---
### [MSG-20260331-110500-marketing-manager] 2026-03-31T11:05:00 — 📢 Marketing Manager → 🔍 SEO Agent [directive]

Start keyword research for Q2. Requirements:
- Top 20 keywords by search volume in our niche
- Difficulty assessment (1-10) for each keyword
- Current competitor ranking for each keyword
- Recommended content type per keyword (blog, guide, comparison)

Deadline: 2 days.
Ref: `org/initiatives/q2-marketing-growth.md`
Task created: `org/agents/seo-agent/tasks/backlog/task-20260331-002.md`

---
### [MSG-20260331-120000-seo-agent] 2026-03-31T12:00:00 — 🔍 SEO Agent → 📢 Marketing Manager [request]

Research started. Issue: I need **WebSearch** and **WebFetch** tools to access search engine data and competitor pages. Cannot complete keyword research without external web access.

Creating tool request: `org/threads/requests/request-tool-seo-websearch-20260331.md`

Continuing with what I can do locally while waiting for tool approval.
```

### Message ID Format

Each message has a unique, greppable identifier:

**Format:** `[MSG-YYYYMMDD-HHMMSS-{sender}]`

**Examples:**
```
[MSG-20260331-100500-ceo]
[MSG-20260331-110000-marketing-manager]
[MSG-20260331-120000-seo-agent]
```

**Search patterns:**
```bash
# Find specific message
grep "MSG-20260331-100500-ceo" org/threads/marketing/*.md

# Find all messages from an agent
grep "\[MSG-.*-seo-agent\]" org/threads/**/*.md

# Find all messages in a time window
grep "\[MSG-20260331-1[0-2]" org/threads/marketing/*.md

# Find all directives
grep "\[directive\]" org/threads/marketing/*.md

# Find a specific thread's messages
grep "\[MSG-" org/threads/marketing/thread-q2-seo-20260331.md

# Count messages in a thread
grep -c "\[MSG-" org/threads/marketing/thread-q2-seo-20260331.md
```

### How Agents Send Messages (Append to Thread)

When an agent sends a message, it:

1. **Determines the thread** — Existing thread or new topic?
2. **Validates chain-of-command** — Can I message this person? (enforced by hook)
3. **Appends to the thread file** — Using Edit tool to append the new message block
4. **Sends notification** — Creates a lightweight notification in recipient's inbox
5. **Updates current-state.md** — "Sent message in thread X"

### Notification Format (Lightweight Inbox)

```markdown
---
type: thread-notification
thread_id: thread-q2-seo-20260331
thread_path: org/threads/marketing/thread-q2-seo-20260331.md
msg_id: MSG-20260331-110500-marketing-manager
from: marketing-manager
timestamp: 2026-03-31T11:05:00
read: false
subject: "New directive in: Q2 SEO Strategy Kickoff"
---
```

That's it. No message body. Just a pointer. The full message lives in the thread file.

**File naming:** `notif-YYYYMMDD-HHMMSS-{from}.md`

### Thread Index

```markdown
# Thread Index

| Thread ID | Topic | Department | Participants | Status | Messages | Last Activity |
|-----------|-------|-----------|-------------|--------|----------|--------------|
| thread-q2-seo-20260331 | Q2 SEO Strategy | marketing | ceo, mm, seo | active | 4 | 2026-03-31T12:00 |
| thread-strategic-plan-20260331 | Strategic Plan | executive | board, ceo | active | 2 | 2026-03-31T09:00 |
| request-tool-seo-websearch-20260331 | Tool: WebSearch for SEO | requests | seo, cao, mm | pending | 3 | 2026-03-31T12:01 |
```

Updated by agents when they create or close threads.

### Thread Access Control

| Agent Tier | Can Read Threads In |
|-----------|-------------------|
| Board | ALL directories (`org/threads/`) |
| CEO | ALL directories |
| CAO | ALL directories (workforce management) |
| Manager | `executive/` (if participant), own department, `cross-dept/` (if participant), `requests/` (own agents) |
| Worker | Own department only (if participant in the thread) |

Enforced by `data-access-check.sh` via IDENTITY.md `access_read`:
```yaml
# SEO Agent IDENTITY.md
access_read:
  - org/threads/marketing/     # Own department threads
  - org/threads/requests/      # Can see their own requests
```

---

## ENFORCEMENT HOOKS

### Hook 1: `activity-logger.sh` (described in Layer 1 above)

Fires on: **PostToolUse** for Read, Write, Edit, Glob, Grep, Bash
Action: Logs every operation to agent's activity stream + org audit log

### Hook 2: `remind-state-update.sh`

Fires on: **PostToolUse** for Write|Edit
Action: Counts write operations. Every 5th write, injects a reminder to update current-state.md and communicate in threads. Does NOT block — just warns.

```bash
#!/usr/bin/env bash
# remind-state-update.sh — Periodic reminder to update state and communicate
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then exit 0; fi

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
ACTIVITY_FILE="$ORG_DIR/agents/$AGENT/activity/$TODAY.md"

# Count write operations so far
WRITE_COUNT=0
if [[ -f "$ACTIVITY_FILE" ]]; then
  WRITE_COUNT=$(grep -c "|.*Write\|Edit" "$ACTIVITY_FILE" 2>/dev/null || echo "0")
fi

# Every 5th write, inject a reminder
if [[ "$WRITE_COUNT" -gt 0 ]] && (( WRITE_COUNT % 5 == 0 )); then
  # Check if current-state.md was updated in the last 2 minutes
  STATE_FILE="$ORG_DIR/agents/$AGENT/activity/current-state.md"
  STALE=false
  
  if [[ ! -f "$STATE_FILE" ]]; then
    STALE=true
  else
    if command -v stat &>/dev/null; then
      LAST_MOD=$(stat -c %Y "$STATE_FILE" 2>/dev/null || stat -f %m "$STATE_FILE" 2>/dev/null || echo "0")
      NOW=$(date +%s)
      DIFF=$((NOW - LAST_MOD))
      if [[ $DIFF -gt 120 ]]; then STALE=true; fi
    fi
  fi
  
  if [[ "$STALE" == "true" ]]; then
    # Output reminder as JSON with reason (shown to Claude as warning)
    echo '{"hookSpecificOutput":{"reason":"⚠️ REMINDER: Update your current-state.md with current task, step, files in use, and next actions. If you made progress or decisions, report in the relevant thread in org/threads/."}}'
    exit 1  # Warn (non-blocking, message shown to agent)
  fi
fi

exit 0
```

### Hook 3: `require-state-and-communication.sh`

Fires on: **Stop** event
Action: **BLOCKS** the agent from ending its session if:
- current-state.md doesn't exist or is stale (no today's date)
- Agent created/modified tasks but didn't write to any thread
- Agent's status in current-state.md isn't set to `idle` or `completing`

```bash
#!/usr/bin/env bash
# require-state-and-communication.sh — Block session end if state is stale
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then exit 0; fi

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
STATE_FILE="$ORG_DIR/agents/$AGENT/activity/current-state.md"
ACTIVITY_FILE="$ORG_DIR/agents/$AGENT/activity/$TODAY.md"

ERRORS=""

# Check 1: current-state.md exists and contains today's date
if [[ ! -f "$STATE_FILE" ]]; then
  ERRORS="${ERRORS}\n- current-state.md does NOT exist. Create it at: $STATE_FILE"
elif ! grep -q "$TODAY" "$STATE_FILE" 2>/dev/null; then
  ERRORS="${ERRORS}\n- current-state.md is STALE (no entry for $TODAY). Update it."
fi

# Check 2: If agent wrote to tasks/, it must also have written to threads/
if [[ -f "$ACTIVITY_FILE" ]]; then
  TASK_WRITES=$(grep -c "tasks/" "$ACTIVITY_FILE" 2>/dev/null | grep -c "Write\|create" || echo "0")
  THREAD_WRITES=$(grep -c "threads/" "$ACTIVITY_FILE" 2>/dev/null | grep -c "Write\|Edit\|update\|append" || echo "0")
  
  if [[ "$TASK_WRITES" -gt 0 && "$THREAD_WRITES" -eq 0 ]]; then
    ERRORS="${ERRORS}\n- You modified TASKS but did NOT communicate in any THREAD. Report your task actions in the relevant thread."
  fi
fi

# Check 3: current-state.md should indicate session is ending
if [[ -f "$STATE_FILE" ]]; then
  STATUS=$(grep "^status:" "$STATE_FILE" | head -1 | awk '{print $2}')
  if [[ "$STATUS" == "working" || "$STATUS" == "blocked" ]]; then
    ERRORS="${ERRORS}\n- current-state.md status is '$STATUS'. Update to 'idle' or 'completing' before ending session."
  fi
fi

if [[ -n "$ERRORS" ]]; then
  echo "SESSION END BLOCKED. Before finishing, fix these issues:$ERRORS" >&2
  exit 2  # Block
fi

exit 0
```

### Updated Hook Registration (Complete settings.json hooks)

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
    "PostToolUse": [
      {
        "matcher": "Read|Write|Edit|Glob|Grep|Bash",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/activity-logger.sh"
        }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/remind-state-update.sh"
        }]
      },
      {
        "matcher": "Write",
        "if": "Write(org/agents/*/tasks/*)",
        "hooks": [{
          "type": "command",
          "command": "bash scripts/hooks/budget-check.sh"
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
          "command": "bash scripts/hooks/require-state-and-communication.sh"
        }]
      }
    ]
  }
}
```

---

## Updated Agent Workspace Structure

The workspace changes to reflect the new architecture:

```
org/agents/{name}/
├── SOUL.md                         # Behavioral identity
├── IDENTITY.md                     # Role, tools, access, skills
├── INSTRUCTIONS.md                 # Operating manual
├── HEARTBEAT.md                    # Periodic checklist
├── MEMORY.md                       # Curated persistent knowledge
│
├── activity/                       # OBSERVABILITY (Layers 1 & 2)
│   ├── current-state.md            # Layer 2: Current cognitive state
│   ├── 2026-03-31.md              # Layer 1: Daily activity stream
│   └── 2026-04-01.md              # (one file per day, immutable)
│
├── memory/                         # Agent reflections (curated, not raw)
│   └── 2026-03-31.md              # Daily reflection/learnings
│
├── tasks/                          # Task management
│   ├── backlog/
│   ├── active/
│   └── done/
│
├── inbox/                          # NOTIFICATIONS ONLY (lightweight)
│   └── notif-20260331-100500-ceo.md
│
└── reports/                        # Status reports & deliverables
    └── daily-2026-03-31.md
```

**REMOVED:** `outbox/` — eliminated. Thread files are the record of sent messages.
**ADDED:** `activity/` — observability layer (hook-generated + agent-maintained)

---

## Updated Agent Instructions Template

Every agent's INSTRUCTIONS.md must include these sections:

```markdown
## Observability Requirements (MANDATORY)

### current-state.md
You MUST maintain `activity/current-state.md` at all times. Update it:
- At SESSION START: Create with initial state, status: working
- When STARTING a task: Update current_task, steps, files
- When COMPLETING a step: Update progress checklist
- When MAKING A DECISION: Update Active Decision + Reasoning Trace
- When CHANGING FILES: Update Files In Active Use
- When ENCOUNTERING A BLOCKER: Update Blockers section
- At SESSION END: Set status to idle, clear current action, write final Queue

If you forget, a hook will remind you. If you try to end your session without updating, the hook will BLOCK you.

### Thread Communication
Every significant action (task creation, delegation, completion, decision) MUST be reported in the relevant thread in `org/threads/{department}/`.

To send a message:
1. Determine the correct thread file (or create a new one)
2. Append your message using the format:
   ```
   ---
   ### [MSG-YYYYMMDD-HHMMSS-{your-name}] TIMESTAMP — EMOJI YOU → EMOJI RECIPIENT [type]
   
   Your message content here.
   ```
3. Send a lightweight notification to the recipient's inbox
4. The message-routing hook will validate chain-of-command

If you create or modify tasks but don't communicate in any thread, the session-end hook will BLOCK you.

### Activity Stream
You do NOT need to maintain the activity stream — it is automatically generated by hooks. Every file you read, write, or edit is logged. This is your long-term memory and audit trail.
```

---

## Updated Hook Count

| # | Hook Script | Event | Purpose |
|---|------------|-------|---------|
| 1 | `activity-logger.sh` | PostToolUse (all) | Log every action to activity stream + audit log |
| 2 | `remind-state-update.sh` | PostToolUse (Write\|Edit) | Periodic reminder to update state and communicate |
| 3 | `require-state-and-communication.sh` | Stop | Block session end if state stale or no communication |
| 4 | `data-access-check.sh` | PreToolUse (Read\|Write\|Edit\|Glob\|Grep) | Chain-of-command data access |
| 5 | `message-routing-check.sh` | PreToolUse (Write to inbox) | Chain-of-command message routing |
| 6 | `require-board-approval.sh` | PreToolUse (Write to decisions) | Board-only decisions |
| 7 | `require-cao-or-board.sh` | PreToolUse (Write to .claude/agents) | Agent definition protection |
| 8 | `skill-access-check.sh` | PreToolUse (Skill hire/fire/reconfig) | Agent management restriction |
| 9 | `budget-check.sh` | PostToolUse (Write to tasks) | Budget enforcement |
| 10 | `log-agent-activation.sh` | SubagentStart | Log agent session start |
| 11 | `log-agent-deactivation.sh` | SubagentStop | Log agent session end |

**Total hooks: 11** (old `audit-log.sh` and `post-cycle-summary.sh` absorbed into `activity-logger.sh` and `require-state-and-communication.sh`)

---

## GUI Integration

### Activity Stream View (New Dashboard Tab)

A new "Activity" tab in the GUI showing real-time agent activity:

```
┌──────────────────────────────────────────────────────────┐
│  Agent Activity Stream                              🔍   │
├──────────────────────────────────────────────────────────┤
│  Agent: [All ▼]  Date: [Today ▼]  Tool: [All ▼]        │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  🎯 CEO — Status: idle (last active 10:00)              │
│  ├── 10:00:01 Read  org/alignment.md                     │
│  ├── 10:00:05 Read  org/agents/ceo/inbox/notif-001.md   │
│  ├── 10:00:10 Write org/agents/mm/tasks/backlog/...      │
│  ├── 10:00:11 Edit  org/threads/executive/thread-...     │
│  └── 10:00:15 Write org/agents/ceo/reports/daily-...     │
│                                                          │
│  📢 Marketing Manager — Status: working on task-001     │
│  ├── 10:01:00 Read  org/alignment.md                     │
│  ├── 10:01:05 Read  org/threads/marketing/thread-...     │
│  ├── 10:01:10 Write org/agents/seo/tasks/backlog/...     │
│  ├── 10:01:11 Edit  org/threads/marketing/thread-...     │
│  └── 10:01:15 Edit  activity/current-state.md            │
│                                                          │
│  🔍 SEO Agent — Status: idle (awaiting tools)           │
│  └── (no activity today)                                 │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Agent Detail View Enhancement

The agent detail view now shows current-state.md as a live panel:

```
┌──────────────────────────────────────────────────────────┐
│  Agent: Marketing Manager (@marketing-manager)           │
├────────────────────┬─────────────────────────────────────┤
│  Current State     │  Open Threads                       │
│  ─────────────     │  ────────────                       │
│  Status: working   │  thread-q2-seo (active, 4 msgs)   │
│  Task: task-001    │  thread-calendar (pending, 0 msgs) │
│  Step: 3/5         │                                     │
│  Next: Draft cal   │  Recent Activity                   │
│                    │  ───────────────                    │
│  Files:            │  10:01:10 Write task for seo-agent │
│  - Reading: init.. │  10:01:11 Thread msg: directive    │
│  - Writing: task.. │  10:01:15 State update: step 3     │
├────────────────────┴─────────────────────────────────────┤
│  [SOUL] [IDENTITY] [INSTRUCTIONS] [TASKS] [THREADS]     │
└──────────────────────────────────────────────────────────┘
```
