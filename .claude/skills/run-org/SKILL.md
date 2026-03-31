---
name: run-org
description: "Start continuous autonomous operation using the Ralph Wiggum pattern. The organisation runs heartbeat cycles until all work is processed — CEO delegates, managers coordinate, workers execute, CAO reviews. The Stop hook keeps the loop cycling until the org is quiescent. Board intervenes only for approvals."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[max-cycles] (optional, default: 10)"
---

# Run Organisation — Continuous Autonomous Operation

This skill starts a continuous operation loop. The organisation will run multiple heartbeat cycles autonomously until all work is processed and the org reaches a quiescent state. This uses the Ralph Wiggum pattern — the Stop hook blocks session exit whenever there is pending work, automatically triggering the next cycle.

## How It Works

1. You trigger `/run-org`
2. This creates a loop state file (`org/.loop-state.md`) and runs the first heartbeat
3. After each heartbeat cycle, YOU assess the org state and report results
4. The **Stop hook** then checks: "Is there still unprocessed work?"
5. If YES → the hook blocks exit and re-injects the prompt → another cycle runs automatically
6. If NO → the hook allows exit → session ends with "Organisation idle"
7. Safety: max cycles cap (default 10) prevents true infinite loops
8. YOU (the board) can intervene at any time: approve proposals, send directives, stop the loop

## Pre-flight Check

Before starting, verify:

1. **Org exists:** Check if `org/config.md` exists. If not: "No organisation found. Run `/onboard` first."
2. **Heartbeat script exists:** Check if `scripts/heartbeat.sh` exists. If not: "Heartbeat script missing."
3. **No overlapping loop:** Check if `org/.loop-state.md` already exists. If it does: "An org-run loop is already active. Use `/cancel-org` to stop it first, or delete `org/.loop-state.md`."

If any check fails, stop and inform the user.

## Step 1: Parse max cycles

If `$ARGUMENTS` is provided and is a number, use it as max_iterations.
Default: 10 cycles.

## Step 2: Create loop state file

Write to `org/.loop-state.md`:

```markdown
---
iteration: 0
max_iterations: {MAX_CYCLES}
started: {NOW_ISO8601}
mode: continuous
stale_count: 0
prev_pending: ""
---
```

## Step 3: Run the first heartbeat cycle

Execute the full 4-phase heartbeat:

```bash
bash scripts/heartbeat.sh
```

Wait for it to complete.

## Step 4: Assess the state after the heartbeat

After the heartbeat script finishes, perform a thorough assessment:

### 4a. Read the loop state
Read `org/.loop-state.md` to get the current iteration count.

### 4b. Check for pending approvals
Read all files in `org/board/approvals/` — look for any with `status: pending` in frontmatter.

If pending approvals found:
- Present EACH one to the user clearly:
  ```
  PENDING APPROVAL:
    ID: approval-hire-marketing-manager-20260331
    Type: hire
    Proposed by: CAO
    Summary: [read the proposal body]
  
  Approve or reject? (use /approve)
  ```
- WAIT for the user to respond before continuing
- The board MUST be able to review and decide during the loop

### 4c. Check for unread notifications
Count files across all `org/agents/*/inbox/` directories that contain `read: false`.
Report: "{N} agents have unread notifications."

### 4d. Check for recent backlog tasks
Count files in `org/agents/*/tasks/backlog/` that were created in the last 10 minutes.
Report: "{N} new tasks in backlog."

### 4e. Summarize the cycle
Present a clear summary to the user:
```
=== Cycle {N} of {MAX} Complete ===

Results:
- [summary of what each agent did, from heartbeat output]

Pending work:
- {X} unread notifications
- {Y} pending approvals
- {Z} new backlog tasks

{If pending approvals: present them for user decision}
{If no pending work at all: proceed to Step 5}
{If pending work but no approvals: just end your response — the Stop hook handles the rest}
```

## Step 5: Quiescence check

If ALL of these are true:
- Zero unread notifications across all agents
- Zero pending approvals
- Zero recently created backlog tasks

Then output EXACTLY this (the Stop hook looks for this exact string):

```
<promise>ORG_IDLE</promise>
```

Then say: "Organisation idle after {N} cycles. All work processed."

## Step 6: If pending work exists

If there IS pending work but NO approvals needing user input:
- Just end your response naturally. Report the pending work summary.
- Do NOT say "please run /heartbeat" or "run the next cycle" — the Stop hook handles this automatically.
- Do NOT output the `<promise>ORG_IDLE</promise>` tag — the org is NOT idle.
- The Stop hook will detect the pending work, block your exit, and re-inject the prompt for the next cycle.

If there IS pending work AND approvals need user input:
- Present the approvals to the user
- After user responds (approves/rejects), end your response
- The Stop hook will trigger the next cycle to process the approval results

## CRITICAL BEHAVIORAL RULES

1. **NEVER tell the user to manually run /heartbeat, /heartbeat ceo, or any agent.** The loop handles everything.
2. **NEVER output `<promise>ORG_IDLE</promise>` unless ALL work is genuinely complete.** The promise must be truthful — falsely claiming idle will stop the loop prematurely.
3. **DO present pending approvals to the user.** The board must be able to act during the loop.
4. **DO summarize each cycle clearly.** The user should understand what happened.
5. **DO NOT modify `.claude/agents/*.md` files.** All changes happen in `org/` only.
6. **The loop is NOT silent.** Each cycle reports results to the user.

## Stopping the Loop

The loop stops automatically when:
1. **Quiescent** — no more pending work → `<promise>ORG_IDLE</promise>` → clean exit
2. **Max iterations reached** — safety limit (Stop hook allows exit)
3. **Stale loop** — 3 consecutive cycles with no progress (Stop hook auto-stops)
4. **User interrupt** — Ctrl+C at any time
5. **User command** — `/cancel-org` deletes loop state and stops

## Example Session

```
User: /run-org

Creating loop state... Max cycles: 10.
Running heartbeat cycle 1...

=== Cycle 1 of 10 Complete ===
Results:
- CEO: Reviewed 2 initiatives, sent hiring directive to CAO
- CAO: Designed Marketing Manager role, created approval proposal

Pending work:
- 0 unread notifications
- 1 pending approval
- 0 new backlog tasks

PENDING APPROVAL:
  ID: approval-hire-marketing-manager-20260331
  Type: hire
  Proposed by: CAO
  Summary: Marketing Manager to lead Q2 marketing initiative...

Approve or reject?

User: /approve approve hire-marketing-manager

Approved! Marketing Manager activated.

[Stop hook detects unread notification for marketing-manager → blocks exit → next cycle]

=== Cycle 2 of 10 Complete ===
Results:
- CEO: Delegated SEO strategy to Marketing Manager
- Marketing Manager: Received delegation, created sub-tasks
- CAO: Updated budget allocations

Pending work:
- 2 unread notifications (marketing-manager subordinates)
- 0 pending approvals
- 2 new backlog tasks

[Stop hook detects pending work → blocks exit → next cycle]

=== Cycle 3 of 10 Complete ===
Results:
- Marketing Manager: Assigned keyword research to workers
- Workers: Executed tasks, wrote deliverables
- CAO: Org health review — no issues

Pending work:
- 0 unread notifications
- 0 pending approvals
- 0 new backlog tasks

<promise>ORG_IDLE</promise>

Organisation idle after 3 cycles. All work processed.
```
