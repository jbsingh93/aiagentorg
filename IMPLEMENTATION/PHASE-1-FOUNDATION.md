# Phase 1: Foundation

**Objective:** Create the project scaffolding — the files Claude Code reads on startup.
**Files to create:** 7
**Depends on:** Nothing (this is first)
**Estimated effort:** 1-2 hours

---

## Task 1.1: `.claude/CLAUDE.md` — Agent Initialization Guide

- [x] **Create file:** `.claude/CLAUDE.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 3
- **Purpose:** Universal initialization guide loaded by Claude Code into EVERY session (board + agents)
- **Key content:**
  - Agent initialization: 7-step context loading sequence (SOUL → IDENTITY → INSTRUCTIONS → etc.)
  - Board (human) quick reference: skill list
  - Environment variables: ORGAGENT_CURRENT_AGENT, ORGAGENT_ORG_DIR
  - Language/currency directives (read from org/config.md)
  - Observability requirements (current-state.md, threads)
  - Tool/access request instructions
  - Reference to master-gpt-prompter
- **Dependencies:** None
- **Verify:** Run `claude` in project dir, confirm CLAUDE.md is loaded (check `/config`)

---

## Task 1.2: `.claude/settings.json` — Hooks, Permissions, Environment

- [x] **Create file:** `.claude/settings.json`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 5 (complete copy-paste JSON)
- **Also reference:** `TO-DO/16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` (hook registration details)
- **Key content:**
  - `permissions.allow`: Read, Write, Edit, Glob, Grep, Bash patterns for common operations
  - `hooks.PreToolUse`: 5 hooks (data-access-check, require-board-approval, require-cao-or-board, skill-access-check, message-routing-check)
  - `hooks.PostToolUse`: 3 hooks (activity-logger, remind-state-update, budget-check)
  - `hooks.SubagentStart`: log-agent-activation
  - `hooks.SubagentStop`: log-agent-deactivation
  - `hooks.Stop`: require-state-and-communication
  - `env.ORGAGENT_ORG_DIR`: "org"
- **IMPORTANT:** Do NOT overwrite `.claude/settings.local.json` — that's the user's local overrides
- **Dependencies:** None (hooks reference scripts that don't exist yet — that's OK, they'll be created in Phase 4)
- **Verify:** Run `claude`, check `/hooks` shows all 11 registered hooks

---

## Task 1.3: `.claude/rules/governance.md` — Governance Rules

- [x] **Create file:** `.claude/rules/governance.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 2 (exact content provided)
- **Key content:**
  - Delegation chain rules (follow orgchart, no skip-level)
  - Budget rules (don't exceed, changes need approval)
  - Audit & logging rules (activity-logger is automatic, current-state is mandatory, threads are mandatory)
  - Approval rules (per oversight_level, board decisions sacred)
  - Agent definition rules (CAO/board only)
  - Communication rules (chain-of-command via threads)
- **Dependencies:** None
- **Verify:** Run `claude`, rules should auto-load (check with `/config`)

---

## Task 1.4: `.claude/rules/structured-autonomy.md` — Autonomy Constraints

- [x] **Create file:** `.claude/rules/structured-autonomy.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 2 (exact content provided)
- **Key content:**
  - Mandate boundaries (operate within INSTRUCTIONS.md scope)
  - Self-modification prohibited (no changing own SOUL/IDENTITY)
  - Tool & data access (only IDENTITY.md-listed, hook-enforced)
  - Communication boundaries (threads only, chain-of-command)
  - Observability requirements (current-state.md, threads — hook-enforced)
  - Decision authority hierarchy (workers → managers → CEO → board)
  - Error handling (log, don't retry blindly, escalate)
  - Agent Teams restriction (exceptional cases only)
- **Dependencies:** None
- **Verify:** Check auto-loaded alongside governance.md

---

## Task 1.5: `package.json` — Node.js Dependencies

- [x] **Create file:** `package.json`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 6 (exact JSON provided)
- **Key content:**
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
- **Dependencies:** None
- **After creating:** Run `npm install` to create node_modules/
- **Verify:** `npm ls` shows express, marked, gray-matter installed

---

## Task 1.6: `.gitignore` — Git Ignore Rules

- [x] **Create file:** `.gitignore`
- **Spec:** `TO-DO/11-DISTRIBUTION-PLAN.md` (gitignore section)
- **Content:**
  ```
  node_modules/
  .claude/settings.local.json
  .claude/agent-memory/
  .claude/agent-memory-local/
  .DS_Store
  Thumbs.db
  *.tmp
  *.swp
  ```
- **Dependencies:** None
- **Verify:** `git status` doesn't show node_modules/

---

## Task 1.7: Update Root `CLAUDE.md`

- [ ] **Update file:** `CLAUDE.md` (already exists)
- **Action:** Update status from "Ready for implementation" to "Implementation in progress — Phase 1 complete"
- **Dependencies:** All Phase 1 tasks
- **Verify:** Read file, confirm status is updated

---

## Phase 1 Verification

After completing all tasks:

```bash
# All foundation files exist
for f in .claude/CLAUDE.md .claude/settings.json .claude/rules/governance.md .claude/rules/structured-autonomy.md package.json .gitignore; do
  if [ -f "$f" ]; then echo "OK: $f"; else echo "MISSING: $f"; fi
done

# npm dependencies installed
npm ls --depth=0

# Claude Code loads config correctly
# (manual check: run `claude`, type `/hooks`, verify 11 hooks listed)
```
