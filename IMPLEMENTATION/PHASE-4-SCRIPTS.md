# Phase 4: Scripts — Heartbeat + 11 Hook Scripts

**Objective:** Create the heartbeat orchestration script and all governance/observability hook scripts.
**Files to create:** 12
**Depends on:** Phase 1 (settings.json references these scripts)
**Can run in parallel with:** Phase 2 and Phase 3
**Estimated effort:** 3-4 hours

**IMPORTANT:** All scripts must be Windows Git Bash compatible. No `bc`, no `date -I`, use `jq -n` for math, `date -u +"%Y-%m-%dT%H:%M:%S"` for timestamps.

---

## Task 4.1: `scripts/heartbeat.sh` — Multi-Phase Orchestration

- [ ] **Create file:** `scripts/heartbeat.sh`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Section 7 (lines 604-714, full script provided)
- **Also:** `TO-DO/16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` (budget update integration)
- **Key content:**
  - Shebang: `#!/usr/bin/env bash` (portable)
  - `set -euo pipefail`
  - `run_agent()` function: sets ORGAGENT_CURRENT_AGENT, CLAUDE_CODE_DISABLE_AUTO_MEMORY=1, runs `claude --agent`, captures output, logs cost to spending-log.md
  - Single-agent mode: `heartbeat.sh <name>` runs just that agent
  - Full mode: parse orgchart → Phase 1 (CEO sequential) → Phase 2 (managers parallel) → Phase 3 (workers parallel) → Phase 4 (CAO sequential)
  - `parse_orgchart()` function: extracts agents by depth using grep + sed (portable, no `-oP`)
  - Pre-check: skip agents whose `.claude/agents/{name}.md` doesn't exist
  - Error handling: `|| true` on claude invocations, log failures to audit-log.md
  - Budget update: after each agent, append cost to spending-log.md
  - Edge case: empty parallel arrays (guard with `[[ ${#pids[@]} -gt 0 ]]`)
- **Windows fixes from spec:**
  - Replace `grep -oP '@\K...'` with `grep -o '@[a-z0-9-]*' | sed 's/@//'`
  - Replace `date -Iseconds` with `date -u +"%Y-%m-%dT%H:%M:%S"`
  - Replace `bc -l` with `jq -n` for arithmetic
- **Dependencies:** Phase 1 (settings.json for env vars)
- **Verify:** `bash scripts/heartbeat.sh` (will fail without org/ — that's expected pre-onboarding)

---

## Task 4.2: `scripts/hooks/activity-logger.sh` — Log Every Action

- [ ] **Create file:** `scripts/hooks/activity-logger.sh`
- **Spec:** `TO-DO/16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` → Layer 1, hook code (lines 82-159)
- **Key content:**
  - Reads JSON from stdin (jq parsing)
  - Extracts: tool name, target file path, action type
  - Creates agent activity directory with `mkdir -p` (first-run safe)
  - Appends to `org/agents/{AGENT}/activity/YYYY-MM-DD.md`
  - Also appends to `org/board/audit-log.md`
  - Extracts first 80 chars of content as summary for Write operations
  - **MUST exit 0 always** — logging failure must never block agent work
- **Replaces:** Old `audit-log.sh` (doc 01 version)
- **Dependencies:** None
- **Verify:** Create a test file, check activity/ and audit-log.md get entries

---

## Task 4.3: `scripts/hooks/remind-state-update.sh` — Periodic Reminder

- [ ] **Create file:** `scripts/hooks/remind-state-update.sh`
- **Spec:** `TO-DO/16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` → Enforcement Hooks, Hook 2 (full code)
- **Key content:**
  - Fires on PostToolUse for Write|Edit
  - Counts write operations in today's activity file
  - Every 5th write: checks if current-state.md is stale (>2 minutes since last update)
  - If stale: outputs JSON with `hookSpecificOutput.reason` warning message, exits 1 (warn, non-blocking)
  - Board sessions skip (ORGAGENT_CURRENT_AGENT unset/board)
- **Dependencies:** None
- **Verify:** Trigger 5+ writes, check warning appears

---

## Task 4.4: `scripts/hooks/require-state-and-communication.sh` — Session End Block + Ralph Wiggum Loop

- [ ] **Create file:** `scripts/hooks/require-state-and-communication.sh`
- **Spec:** `TO-DO/16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` → Hook 3 + `TO-DO/18-CONTINUOUS-OPERATION-RALPH-WIGGUM.md` → Section 4.1 (complete enhanced code)
- **DUAL BEHAVIOR — this is the most complex hook:**
  - **Part 1 (Agent sessions):** Validates current-state.md updated + thread communication. Blocks if stale.
  - **Part 2 (Board sessions, org-run mode):** Ralph Wiggum loop logic:
    - Read `org/.loop-state.md` for iteration count + max
    - Check for completion promise `<promise>ORG_IDLE</promise>` in Claude's output
    - Check for pending work: unread notifications, pending approvals, recent backlog tasks
    - If pending work + under max iterations → block exit with JSON: `{"decision":"block","reason":"..."}`
    - If quiescent → allow exit, delete loop state file
    - Stale loop detection: auto-stop if 3 cycles produce no changes
  - **Part 3 (Board sessions, NOT org-run mode):** Allow exit normally
- **Dependencies:** None
- **Verify:** 
  - Agent session blocked if state not updated (Part 1)
  - `/run-org` loop continues when work exists (Part 2)
  - `/run-org` stops when quiescent (Part 2)

---

## Task 4.5: `scripts/hooks/data-access-check.sh` — File Access Control

- [ ] **Create file:** `scripts/hooks/data-access-check.sh`
- **Spec:** `TO-DO/12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` → Section 3, hook code
- **Key content:**
  - Fires on PreToolUse for Read, Write, Edit, Glob, Grep
  - Board = full access (exit 0 immediately)
  - Extracts target path from tool_input (different field per tool type)
  - Reads agent's IDENTITY.md to get `access_read`/`access_write` arrays
  - Parses arrays using awk (extract lines between `access_read:` and next `^[a-z]`)
  - Checks if target path starts with any allowed path (prefix match)
  - If not allowed: exit 2 with "ACCESS DENIED" message suggesting request workflow
- **Dependencies:** None (but agents need IDENTITY.md with access lists — created by /onboard)
- **Verify:** Agent can't read files outside their access_read list

---

## Task 4.6: `scripts/hooks/message-routing-check.sh` — Chain-of-Command Messaging

- [ ] **Create file:** `scripts/hooks/message-routing-check.sh`
- **Spec:** `TO-DO/15-CHAT-LAYER-CHAIN-OF-COMMAND.md` → Section 4, hook code (lines 195-286)
- **Key content:**
  - Fires on PreToolUse for Write to `org/agents/*/inbox/*`
  - Board and CAO = full access
  - Extracts target agent from path
  - Reads orgchart.md to determine relationships (supervisor, depth)
  - `get_supervisor()` function walks orgchart upward
  - 6 rules checked: can message supervisor, can message direct reports, can message department peers, CEO can message managers, managers can cross-dept, urgent bypass for CEO+
  - If no rule matches: exit 2 with "CHAIN-OF-COMMAND VIOLATION" message
- **Dependencies:** None
- **Verify:** Worker can't write to CEO's inbox (blocked by hook)

---

## Task 4.7: `scripts/hooks/require-board-approval.sh`

- [ ] **Create file:** `scripts/hooks/require-board-approval.sh`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Hook script logic (lines 566-576)
- **Key content:** 6-line script. If ORGAGENT_CURRENT_AGENT is not "board", exit 2. Blocks writes to org/board/decisions/.
- **Dependencies:** None
- **Verify:** Agent can't write to decisions/ (blocked)

---

## Task 4.8: `scripts/hooks/require-cao-or-board.sh`

- [ ] **Create file:** `scripts/hooks/require-cao-or-board.sh`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Hook script logic (lines 578-588)
- **Key content:** If ORGAGENT_CURRENT_AGENT is not "cao" or "board", exit 2. Blocks writes to .claude/agents/.
- **Dependencies:** None
- **Verify:** Regular agent can't write to .claude/agents/ (blocked)

---

## Task 4.9: `scripts/hooks/skill-access-check.sh`

- [ ] **Create file:** `scripts/hooks/skill-access-check.sh`
- **Spec:** `TO-DO/12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` → Section 3, skill-access-check code
- **Key content:** If ORGAGENT_CURRENT_AGENT is not "cao" or "board", exit 2. Blocks hire/fire/reconfigure skills.
- **Dependencies:** None
- **Verify:** Regular agent can't invoke `/hire-agent` (blocked)

---

## Task 4.10: `scripts/hooks/budget-check.sh`

- [ ] **Create file:** `scripts/hooks/budget-check.sh`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Hook script logic (lines 602-616)
- **Key content:**
  - Fires on PostToolUse for Write to org/agents/*/tasks/*
  - Board = skip
  - Reads agent's remaining budget from overview.md table
  - If remaining <= 0: exit 2 (BLOCK task creation)
  - **Windows fix:** Use `jq -n` instead of `bc -l` for comparison
- **Dependencies:** None
- **Verify:** Agent with 0 budget can't create tasks (blocked)

---

## Task 4.11: `scripts/hooks/log-agent-activation.sh`

- [ ] **Create file:** `scripts/hooks/log-agent-activation.sh`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Hook script logic (lines 618-627)
- **Key content:** Reads agent_name from stdin JSON, appends "agent-start" entry to audit-log.md. Exit 0 always.
- **Dependencies:** None
- **Verify:** Agent start logged in audit-log.md

---

## Task 4.12: `scripts/hooks/log-agent-deactivation.sh`

- [ ] **Create file:** `scripts/hooks/log-agent-deactivation.sh`
- **Spec:** Same as 4.11 but action = "agent-stop"
- **Key content:** Same structure, different action string.
- **Dependencies:** None
- **Verify:** Agent stop logged in audit-log.md

---

## Phase 4 Verification

```bash
# All scripts exist
echo "--- heartbeat ---"
[ -f scripts/heartbeat.sh ] && echo "OK" || echo "MISSING"

echo "--- hooks ---"
for hook in activity-logger remind-state-update require-state-and-communication data-access-check message-routing-check require-board-approval require-cao-or-board skill-access-check budget-check log-agent-activation log-agent-deactivation; do
  [ -f "scripts/hooks/$hook.sh" ] && echo "OK: $hook" || echo "MISSING: $hook"
done

# All scripts are valid bash (syntax check)
for f in scripts/heartbeat.sh scripts/hooks/*.sh; do
  bash -n "$f" && echo "SYNTAX OK: $f" || echo "SYNTAX ERROR: $f"
done

# Total: 12 scripts
echo "Total scripts: $(ls -1 scripts/heartbeat.sh scripts/hooks/*.sh 2>/dev/null | wc -l)"
```
