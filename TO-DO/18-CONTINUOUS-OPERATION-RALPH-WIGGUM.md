# Continuous Operation — Ralph Wiggum Pattern for OrgAgent

**Date:** 2026-03-31
**Purpose:** Complete specification for autonomous continuous operation using the Ralph Wiggum Stop-hook pattern. This makes the org behave like a real company — work flows continuously until all tasks are processed, without manual orchestration.

**Source:** Ralph Wiggum pattern from [anthropics/claude-code/plugins/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum) and [computerlovetech/ralphify](https://github.com/computerlovetech/ralphify)

---

## 1. What Is the Ralph Wiggum Pattern?

The Ralph Wiggum pattern creates an autonomous continuous loop in Claude Code using the **Stop hook**:

1. Claude finishes its work and tries to exit the session
2. The Stop hook intercepts the exit attempt
3. The hook checks: "Is there still work to do?"
4. If YES → **block exit** with `{"decision":"block","reason":"..."}` → re-injects a prompt → Claude continues
5. If NO → allow exit → session ends cleanly
6. Safety: max iterations cap prevents true infinite loops

**The key insight:** No external daemon, no file watcher, no bash `while true` loop. Just Claude Code's own hook system keeping the session alive until the org is quiescent.

---

## 2. How It Applies to OrgAgent

### The Problem It Solves

Without Ralph Wiggum, OrgAgent works in batch mode:
- User types `/heartbeat` → 4 phases run → session ends → nothing happens
- CEO delegates to a manager → manager doesn't act until NEXT heartbeat
- Work chains (CEO → Manager → Worker) require MULTIPLE manual heartbeat invocations
- The user must manually orchestrate: "run CEO, now run manager, now run worker"

### The Solution

With Ralph Wiggum, one `/run-org` command triggers CONTINUOUS operation:
- Phase cycle runs (CEO → Managers → Workers → CAO)
- Stop hook checks: "Did this cycle create new unprocessed work?"
- If yes → automatically runs another cycle
- If no → org is quiescent, session ends
- Full delegation chains complete in a SINGLE session

### Real Organisation Behavior

```
User: /run-org

[Cycle 1]
CEO reads initiatives → creates directives for CAO and managers → writes to threads
CAO receives CEO directive → proposes marketing manager hire → writes approval

[Stop hook: Pending approval found → block exit → run another cycle]

[Cycle 2]
User sees pending approval → /approve hire-marketing-manager
CAO activates marketing manager → updates orgchart
CEO delegates SEO strategy to marketing manager → writes task + thread

[Stop hook: Marketing manager has unread notification → block exit]

[Cycle 3]
Marketing Manager processes task → requests SEO agent from CAO → delegates sub-tasks
CAO designs SEO agent → writes approval for board

[Stop hook: Pending approval → block exit]

[Cycle 4]
User approves SEO agent hire
CAO activates SEO agent
Marketing Manager assigns keyword research to SEO agent

[Stop hook: SEO agent has unread notification → block exit]

[Cycle 5]
SEO Agent executes keyword research → writes deliverable → reports to manager
Marketing Manager reviews deliverable → approves → reports to CEO
CEO reviews report → updates initiative status

[Stop hook: No unread notifications, no pending approvals, no new tasks → QUIESCENT]

Session ends: "Organisation idle after 5 cycles. All work processed."
```

**One command. Full cascade. The board only intervenes for approvals. Everything else is autonomous.**

---

## 3. Architecture — Two Operation Modes

The 3-mode proposal from the previous discussion is simplified to 2 modes:

### Mode A: Continuous Operation (`/run-org`)

The primary mode. A Ralph Wiggum loop that:
1. Runs a full heartbeat cycle (4 phases)
2. After each cycle, the Stop hook checks for pending work
3. If work exists → block exit → run another heartbeat cycle
4. If quiescent → allow exit
5. Safety: max N cycles per session (default: 10, configurable)

**When to use:** Whenever you want the org to process work. This is the "normal workday."

### Mode B: Scheduled Wake-Up (`/loop 30m /run-org`)

Periodically triggers Mode A. The org:
1. Wakes up every 30 minutes (or configured interval)
2. Runs Mode A until quiescent
3. Goes idle
4. Wakes up again in 30 minutes

**When to use:** For fully autonomous operation. Set it and forget it.

### What Was Eliminated

| Old Mode | New Status |
|----------|-----------|
| Mode 1: Scheduled heartbeat | **Merged** into Mode B (loop + run-org) |
| Mode 2: Reactive daemon | **ELIMINATED** — Ralph pattern replaces file watchers entirely |
| Mode 3: Multi-round heartbeat | **MERGED** into Mode A (Ralph loop handles multiple rounds) |

### The `/heartbeat` Skill Still Exists

`/heartbeat` runs ONE cycle — useful for debugging. `/run-org` is the production command that keeps cycling.

---

## 4. Technical Implementation

### 4.1 The Stop Hook Enhancement

The existing `require-state-and-communication.sh` Stop hook is enhanced with Ralph loop logic.

**Decision flow:**

```
Stop hook fires (Claude tries to exit)
     │
     ├── Is org-run mode active? (check org/.loop-state.md exists)
     │   │
     │   ├── NO → Normal behavior:
     │   │        Check current-state.md updated? Check thread communication?
     │   │        Block if stale, allow if OK.
     │   │
     │   └── YES → Ralph loop behavior:
     │            │
     │            ├── Check iteration count vs max_iterations
     │            │   └── Over limit? → Allow exit (safety stop)
     │            │
     │            ├── Check for completion promise in Claude's output
     │            │   └── <promise>ORG_IDLE</promise> found? → Allow exit (clean stop)
     │            │
     │            ├── Check for pending work:
     │            │   ├── Any unread notifications in org/agents/*/inbox/?
     │            │   ├── Any pending approvals in org/board/approvals/?
     │            │   ├── Any tasks in backlog that were created this cycle?
     │            │   └── Any threads with unresponded messages?
     │            │
     │            ├── Pending work found?
     │            │   └── YES → Increment iteration → Block exit
     │            │              Return: {"decision":"block","reason":"Cycle N of M. Pending work detected: X unread notifications, Y pending approvals. Run /heartbeat to process. When no work remains, output <promise>ORG_IDLE</promise>."}
     │            │
     │            └── No pending work?
     │                └── Allow exit → Clean up loop state file
```

**The enhanced Stop hook script:**

```bash
#!/usr/bin/env bash
# require-state-and-communication.sh — Enhanced with Ralph Wiggum loop
# Fires on: Stop event
# Combines: state validation + communication check + continuous operation loop

AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
LOOP_STATE="$ORG_DIR/.loop-state.md"

# ========================================
# PART 1: Agent state validation (non-board only)
# ========================================
if [[ "$AGENT" != "board" ]]; then
  STATE_FILE="$ORG_DIR/agents/$AGENT/activity/current-state.md"
  ACTIVITY_FILE="$ORG_DIR/agents/$AGENT/activity/$TODAY.md"
  ERRORS=""

  # Check current-state.md exists and is current
  if [[ ! -f "$STATE_FILE" ]]; then
    ERRORS="${ERRORS}current-state.md does NOT exist. "
  elif ! grep -q "$TODAY" "$STATE_FILE" 2>/dev/null; then
    ERRORS="${ERRORS}current-state.md is stale. "
  fi

  # Check thread communication if tasks were modified
  if [[ -f "$ACTIVITY_FILE" ]]; then
    TASK_WRITES=$(grep -c "tasks/" "$ACTIVITY_FILE" 2>/dev/null || echo "0")
    THREAD_WRITES=$(grep -c "threads/" "$ACTIVITY_FILE" 2>/dev/null || echo "0")
    if [[ "$TASK_WRITES" -gt 0 && "$THREAD_WRITES" -eq 0 ]]; then
      ERRORS="${ERRORS}Tasks modified without thread communication. "
    fi
  fi

  if [[ -n "$ERRORS" ]]; then
    echo "SESSION BLOCKED: $ERRORS" >&2
    exit 2
  fi
fi

# ========================================
# PART 2: Ralph Wiggum continuous loop (board session only)
# ========================================
if [[ "$AGENT" != "board" ]]; then
  exit 0  # Non-board sessions exit normally after Part 1
fi

# Check if org-run mode is active
if [[ ! -f "$LOOP_STATE" ]]; then
  exit 0  # Not in org-run mode — normal exit
fi

# Read loop state
ITERATION=$(grep "^iteration:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "0")
MAX_ITERATIONS=$(grep "^max_iterations:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "10")

# Safety check: max iterations reached
if [[ "$ITERATION" -ge "$MAX_ITERATIONS" ]]; then
  echo "Max iterations ($MAX_ITERATIONS) reached. Stopping org-run loop." >&2
  rm -f "$LOOP_STATE"
  exit 0
fi

# Check for completion promise in Claude's last output
INPUT=$(cat)
ASSISTANT_OUTPUT=$(echo "$INPUT" | jq -r '.transcript // [] | .[-1] // {} | .content // ""' 2>/dev/null || echo "")
if echo "$ASSISTANT_OUTPUT" | grep -q '<promise>ORG_IDLE</promise>'; then
  rm -f "$LOOP_STATE"
  exit 0  # Clean exit — org is quiescent
fi

# ========================================
# PART 3: Check for pending work
# ========================================
PENDING_WORK=""

# Check 1: Unread notifications in any agent's inbox
UNREAD_COUNT=0
for inbox_dir in "$ORG_DIR"/agents/*/inbox/; do
  if [[ -d "$inbox_dir" ]]; then
    UNREAD=$(find "$inbox_dir" -name "*.md" -exec grep -l "read: false" {} \; 2>/dev/null | wc -l)
    UNREAD_COUNT=$((UNREAD_COUNT + UNREAD))
  fi
done
if [[ "$UNREAD_COUNT" -gt 0 ]]; then
  PENDING_WORK="${PENDING_WORK}${UNREAD_COUNT} unread notifications. "
fi

# Check 2: Pending approvals
PENDING_APPROVALS=0
if [[ -d "$ORG_DIR/board/approvals" ]]; then
  PENDING_APPROVALS=$(find "$ORG_DIR/board/approvals" -name "*.md" -exec grep -l "status: pending" {} \; 2>/dev/null | wc -l)
fi
if [[ "$PENDING_APPROVALS" -gt 0 ]]; then
  PENDING_WORK="${PENDING_WORK}${PENDING_APPROVALS} pending approvals. "
fi

# Check 3: Tasks in backlog that were created recently (within last 10 minutes)
RECENT_TASKS=0
for backlog_dir in "$ORG_DIR"/agents/*/tasks/backlog/; do
  if [[ -d "$backlog_dir" ]]; then
    RECENT=$(find "$backlog_dir" -name "*.md" -mmin -10 2>/dev/null | wc -l)
    RECENT_TASKS=$((RECENT_TASKS + RECENT))
  fi
done
if [[ "$RECENT_TASKS" -gt 0 ]]; then
  PENDING_WORK="${PENDING_WORK}${RECENT_TASKS} recent backlog tasks. "
fi

# ========================================
# PART 4: Decision
# ========================================
if [[ -n "$PENDING_WORK" ]]; then
  # Increment iteration
  NEW_ITERATION=$((ITERATION + 1))
  sed -i "s/^iteration:.*/iteration: $NEW_ITERATION/" "$LOOP_STATE" 2>/dev/null || \
    echo "iteration: $NEW_ITERATION" > "$LOOP_STATE.tmp" && mv "$LOOP_STATE.tmp" "$LOOP_STATE"

  # Block exit and re-inject prompt
  cat <<RALPH_JSON
{"decision":"block","reason":"Organisation cycle $NEW_ITERATION of $MAX_ITERATIONS. Pending work detected: ${PENDING_WORK}Run /heartbeat to process the next cycle. After the heartbeat, check if there is still pending work. If all inboxes are empty, all approvals processed, and no new tasks were created, output <promise>ORG_IDLE</promise> to end the loop. If there are pending approvals, present them to the user with /approve before continuing."}
RALPH_JSON
  exit 2
fi

# No pending work — org is quiescent
rm -f "$LOOP_STATE"
exit 0
```

### 4.2 The `/run-org` Skill

**File:** `.claude/skills/run-org/SKILL.md`

```yaml
---
name: run-org
description: "Start continuous autonomous operation. The organisation runs heartbeat cycles until all work is processed — CEO delegates, managers coordinate, workers execute, CAO reviews. Uses the Ralph Wiggum pattern: Stop hook keeps cycling until quiescent. Board intervenes only for approvals."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[max-cycles] (optional, default: 10)"
---

# Run Organisation — Continuous Autonomous Operation

This skill starts a continuous operation loop. The organisation will run multiple heartbeat cycles autonomously until all work is processed and the org reaches a quiescent state.

## How It Works

1. You trigger `/run-org`
2. This creates a loop state file and runs the first heartbeat
3. After each heartbeat cycle, the Stop hook checks: "Is there still unprocessed work?"
4. If YES → the hook blocks exit and re-injects the heartbeat prompt → another cycle runs
5. If NO → the hook allows exit → session ends with "Organisation idle"
6. Safety: max cycles cap (default 10) prevents true infinite loops
7. YOU (the board) can intervene at any time: approve proposals, send directives, answer questions

## Pre-flight Check

1. Verify `org/config.md` exists (org must be onboarded)
2. Verify `scripts/heartbeat.sh` exists
3. Verify `org/.loop-state.md` does NOT already exist (prevent overlapping runs)

If org doesn't exist: "No organisation found. Run /onboard first."
If loop state already exists: "An org-run loop is already active. Use Ctrl+C to stop it first, or delete org/.loop-state.md."

## Step 1: Parse max cycles

If `$ARGUMENTS` provided and is a number: use as max_iterations.
Default: 10 cycles.

## Step 2: Create loop state file

Write to `org/.loop-state.md`:
```markdown
---
iteration: 0
max_iterations: {MAX_CYCLES}
started: {NOW_ISO8601}
mode: continuous
---

# Continuous Operation Loop

This file controls the Ralph Wiggum autonomous loop.
It is automatically deleted when the loop ends.
Do NOT delete this file manually while the loop is running.
```

## Step 3: Run the first heartbeat

```bash
bash scripts/heartbeat.sh
```

## Step 4: After heartbeat completes — assess the state

After the heartbeat script finishes, do the following assessment:

1. **Check for pending approvals**: Read `org/board/approvals/` for files with `status: pending`
   - If found: Present them to the user with `/approve` and wait for their decision
   - The board MUST be able to review and approve/reject during the loop

2. **Check for unread notifications**: Scan `org/agents/*/inbox/` for `read: false`
   - If found: report how many agents have unread messages

3. **Check for recent backlog tasks**: Scan `org/agents/*/tasks/backlog/` for recently created tasks

4. **Summarize the cycle**: "Cycle N complete. {summary of what happened}. {pending work description}."

5. **If no pending work detected at all:**
   Output exactly: `<promise>ORG_IDLE</promise>`
   This signals the Stop hook to allow clean exit.

6. **If pending work exists but no approvals needed:**
   Just finish your response. The Stop hook will detect pending work and automatically trigger another cycle.

7. **If pending work includes approvals:**
   Present them to the user. After user responds, finish your response. The Stop hook handles the rest.

## Important Behavioral Rules

- **Do NOT manually tell the user "now run /heartbeat again"** — the Stop hook handles this automatically
- **Do NOT output `<promise>ORG_IDLE</promise>` unless ALL work is genuinely complete** — the promise must be truthful
- **DO present pending approvals to the user** — the board must be able to act during the loop
- **DO summarize each cycle** — the user should understand what happened
- **The loop is NOT silent** — each cycle reports its results to the user

## Stopping the Loop

The loop stops automatically when:
1. No more pending work (quiescent) → `<promise>ORG_IDLE</promise>`
2. Max iterations reached → safety limit
3. User presses Ctrl+C → immediate stop
4. User types `/cancel-org` → clean stop (deletes loop state)

## Example Session

```
User: /run-org

[Cycle 1]
Running heartbeat... CEO → Managers → Workers → CAO
CEO: Created 2 tasks, sent 3 messages
CAO: Proposed hire for Marketing Manager
Cycle 1 complete. Pending: 1 approval, 2 unread notifications.

There is a pending approval:
  approval-hire-marketing-manager-20260331: Hire Marketing Manager

Approve or reject? (/approve approve|reject hire-marketing-manager ...)

User: /approve approve hire-marketing-manager

Approved! Marketing Manager activated.

[Cycle 2 — automatic, triggered by Stop hook]
Running heartbeat...
CEO: Delegated SEO strategy to Marketing Manager
Marketing Manager: Processed CEO directive, created 2 sub-tasks
Cycle 2 complete. Pending: 2 unread notifications.

[Cycle 3 — automatic]
Running heartbeat...
Marketing Manager: Requested SEO Agent hire from CAO
CAO: Designed SEO Agent, proposed to board
Cycle 3 complete. Pending: 1 approval.

There is a pending approval:
  approval-hire-seo-agent-20260331: Hire SEO Agent

User: /approve approve hire-seo-agent

[Cycle 4 — automatic]
Running heartbeat...
SEO Agent: First heartbeat, processed keyword research task
Marketing Manager: Reviewed SEO deliverable, approved
CEO: Updated initiative progress
Cycle 4 complete. No pending work detected.

<promise>ORG_IDLE</promise>

Organisation idle after 4 cycles. All work processed.
Total cost: 12.50 DKK across 4 cycles.
```
```

### 4.3 The `/cancel-org` Skill

**File:** `.claude/skills/cancel-org/SKILL.md`

```yaml
---
name: cancel-org
description: "Stop a running continuous operation loop. Cleans up the loop state file."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Bash
---

# Cancel Organisation Loop

Stop the continuous operation loop started by `/run-org`.

1. Check if `org/.loop-state.md` exists
2. If yes: read current iteration count, delete the file
3. Confirm: "Organisation loop stopped after {N} cycles."
4. If no: "No active organisation loop found."
```

### 4.4 Updated Settings.json

The Stop hook registration stays the same — `require-state-and-communication.sh` is already registered. Its logic is enhanced internally. No settings.json change needed.

### 4.5 Loop State File Format

**File:** `org/.loop-state.md` (created by `/run-org`, deleted when loop ends)

```markdown
---
iteration: 3
max_iterations: 10
started: 2026-03-31T10:00:00
mode: continuous
---
```

This file is:
- Created by the `/run-org` skill
- Read and updated by the Stop hook on each cycle
- Deleted when the loop ends (clean exit, max iterations, or cancel)
- Gitignored (runtime state, never committed)
- Its EXISTENCE signals that org-run mode is active

---

## 5. Pending Work Detection — What Counts as "Work"

The Stop hook checks these conditions to determine if the org has pending work:

| Check | What It Detects | How |
|-------|----------------|-----|
| **Unread notifications** | Messages that agents haven't processed yet | `find org/agents/*/inbox/ -name "*.md" -exec grep -l "read: false"` |
| **Pending approvals** | Proposals awaiting board decision | `find org/board/approvals/ -name "*.md" -exec grep -l "status: pending"` |
| **Recent backlog tasks** | Tasks created in the last 10 minutes that haven't been picked up | `find org/agents/*/tasks/backlog/ -mmin -10` |

**What does NOT count as pending work:**
- Active tasks (agents are already working on them)
- Completed tasks (done)
- Read notifications (already processed)
- Decided approvals (already in decisions/)
- Old backlog tasks (created before this loop session)

**Why 10-minute window for backlog tasks?** Tasks created during the current cycle are "new work" that should be processed. Tasks from hours ago are "old backlog" that can wait for the next scheduled run.

---

## 6. Board Interaction During the Loop

The board (human user) is NOT locked out during continuous operation. They can:

1. **Approve/reject proposals** — when the cycle presents pending approvals
2. **Send messages** — type naturally in the Claude Code session
3. **Give directives** — "Tell the CEO to prioritize the finance department"
4. **Stop the loop** — `/cancel-org` or Ctrl+C
5. **Check status** — `/status` works during the loop
6. **Check budget** — `/budget-check` works during the loop

The key design: each heartbeat cycle PAUSES to present approvals to the board. The board acts, then the cycle completes, the Stop hook checks for more work, and the next cycle begins.

---

## 7. Safety Rails

| Safety Mechanism | Purpose | Default |
|-----------------|---------|---------|
| **Max iterations** | Prevents true infinite loops | 10 cycles |
| **Per-agent budget cap** | `--max-budget-usd` on each claude invocation | From config.md |
| **Completion promise** | `<promise>ORG_IDLE</promise>` must be genuine | Exact string match |
| **User interrupt** | Ctrl+C always works | Built into Claude Code |
| **Cancel skill** | `/cancel-org` for clean stop | Deletes state file |
| **State file** | `org/.loop-state.md` — loop only runs if this exists | Auto-deleted on exit |
| **Budget exhaustion** | budget-check.sh hook blocks task creation at 0 budget | Per-agent enforcement |
| **Stale detection** | If 3 cycles produce no changes → auto-stop (prevent spinning) | Tracked by hook |

### Stale Loop Detection

If the same pending work count persists for 3 consecutive cycles (nothing is being processed), the loop auto-stops:

```bash
# In the Stop hook:
PREV_PENDING=$(grep "^prev_pending:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "")
CURRENT_PENDING="${UNREAD_COUNT}-${PENDING_APPROVALS}-${RECENT_TASKS}"

if [[ "$CURRENT_PENDING" == "$PREV_PENDING" ]]; then
  STALE_COUNT=$(grep "^stale_count:" "$LOOP_STATE" 2>/dev/null | awk '{print $2}' || echo "0")
  STALE_COUNT=$((STALE_COUNT + 1))
  if [[ "$STALE_COUNT" -ge 3 ]]; then
    echo "Loop stale for 3 cycles. Pending work is not being resolved. Stopping." >&2
    rm -f "$LOOP_STATE"
    exit 0
  fi
  # Update stale count in state file
  sed -i "s/^stale_count:.*/stale_count: $STALE_COUNT/" "$LOOP_STATE"
else
  # Reset stale count — progress was made
  sed -i "s/^stale_count:.*/stale_count: 0/" "$LOOP_STATE"
fi
sed -i "s/^prev_pending:.*/prev_pending: $CURRENT_PENDING/" "$LOOP_STATE"
```

---

## 8. Updated Gitignore

`org/.loop-state.md` is already covered by the `org/` gitignore entry. No change needed.

---

## 9. Integration Points

### With Existing Heartbeat

`/heartbeat` (single cycle) still works independently. `/run-org` uses `/heartbeat` internally but adds the continuous loop wrapper.

### With `/loop` Scheduling

```
/loop 30m /run-org
```

Every 30 minutes:
1. `/run-org` triggers
2. Runs cycles until quiescent
3. Session ends
4. 30 minutes later, `/loop` triggers again

This is "always-on" autonomous operation.

### With Board Approval

The `/run-org` skill explicitly presents pending approvals to the board during each cycle. The board can approve/reject within the same session. No need to break out of the loop.

### With the GUI Dashboard

The dashboard (`/dashboard` at localhost:3000) works alongside `/run-org`. The board can:
- Watch the org chart update in real-time (5-second polling)
- See new threads appear in the chat view
- Monitor budget spending
- Approve proposals via the GUI (POST to /api/approvals/:id/approve)

---

## 10. Complete File List

### New Files

| # | File | Purpose |
|---|------|---------|
| 1 | `.claude/skills/run-org/SKILL.md` | Start continuous operation loop |
| 2 | `.claude/skills/cancel-org/SKILL.md` | Stop the loop cleanly |

### Modified Files

| # | File | Change |
|---|------|--------|
| 3 | `scripts/hooks/require-state-and-communication.sh` | Add Ralph Wiggum loop logic (Part 2-4) |
| 4 | `.claude/rules/governance.md` | Add "Continuous Operation" section |

### Runtime Files (created/deleted automatically)

| File | Created By | Deleted By |
|------|-----------|-----------|
| `org/.loop-state.md` | `/run-org` skill | Stop hook on clean exit, `/cancel-org`, or max iterations |

---

## 11. Updated Skill Count

This adds 2 new skills:

| # | Skill | Purpose |
|---|-------|---------|
| 17 | **run-org** | Start continuous autonomous loop |
| 18 | **cancel-org** | Stop the loop |

**Total skills: 18** (was 16)

---

## 12. Updated Hook Behavior

The Stop hook (`require-state-and-communication.sh`) now has dual behavior:

| Context | Behavior |
|---------|----------|
| **Agent session** (ORGAGENT_CURRENT_AGENT set) | Part 1 only: validate state + communication |
| **Board session, NOT in org-run mode** | Allow exit (no check) |
| **Board session, IN org-run mode** (loop-state.md exists) | Parts 2-4: Ralph Wiggum loop — check pending work, block or allow |

This means the hook script is ONE file with TWO operating modes, determined by context.

---

## 13. Architecture Decision Record

### Decision 38: Continuous Operation via Ralph Wiggum Pattern

**Decision:** Use the Ralph Wiggum Stop-hook pattern for continuous autonomous operation. One `/run-org` command triggers a self-sustaining loop that runs heartbeat cycles until all work is processed.

**Reasoning:**
- No external daemon needed (no file watcher, no Node.js process)
- Uses Claude Code's native hook system
- Board stays in the loop (can approve, intervene, direct)
- Safety rails prevent infinite loops (max iterations, stale detection, budget caps)
- Elegant: the org "runs itself" and "sleeps" when there's nothing to do

**What was eliminated:**
- Mode 2 (Reactive Daemon) — replaced entirely by Ralph pattern
- Mode 3 (Multi-round Heartbeat) — merged into Ralph loop
- External file watcher scripts
- Manual agent chaining

**What was added:**
- `/run-org` skill (start loop)
- `/cancel-org` skill (stop loop)
- Enhanced Stop hook with Ralph logic
- Loop state file (`org/.loop-state.md`)
- Stale loop detection (auto-stop after 3 unchanged cycles)

**See:** `18-CONTINUOUS-OPERATION-RALPH-WIGGUM.md` for complete specification.
