# OrgAgent — Master Implementation Checklist

**Project:** Dynamic AI Agent Organisation built on Claude Code
**Status:** Specification complete. Implementation ready.
**Spec Location:** `TO-DO/` (18 documents)

---

## How to Use This Checklist

1. Work through phases IN ORDER (1 → 2 → 3 → 4 → 5 → 6 → 7)
2. Within each phase, tasks can be done in the listed order
3. Each task has a checkbox `[ ]` — mark `[x]` when complete
4. Each task references the TO-DO spec doc(s) to read before implementing
5. After each phase, run the verification steps before moving on
6. **CRITICAL:** Read `.claude/skills/master-gpt-prompter/SKILL.md` before writing ANY file that an LLM will read (SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md, skill bodies, rules)

---

## Pre-Implementation Notes

**DO NOT overwrite these existing files:**
- `.claude/skills/master-gpt-prompter/` (user's existing skill + references)
- `.claude/skills/skill-creator/` (user's existing skill)
- `.claude/skills/ultimate-skill-creator/` (user's existing skill)
- `.claude/skills/vibe-security-checker/` (user's existing skill)
- `.claude/skills/dansk-lovgivning-ekspert/` (user's existing skill)
- `.claude/settings.local.json` (user's local overrides)

**Environment:** Windows 11, Git Bash. All bash scripts must be portable (no `bc`, no `date -I`, use `jq -n` for math, `date -u +"%Y-%m-%dT%H:%M:%S"` for timestamps).

---

## Phase Summary

| Phase | Name | Files | Depends On | Checklist |
|-------|------|-------|-----------|-----------|
| 1 | Foundation | 7 | Nothing | [PHASE-1-FOUNDATION.md](PHASE-1-FOUNDATION.md) |
| 2 | Skills | 16 | Phase 1 | [PHASE-2-SKILLS.md](PHASE-2-SKILLS.md) |
| 3 | Core Agents | 2 | Phase 1 | [PHASE-3-AGENTS.md](PHASE-3-AGENTS.md) |
| 4 | Scripts | 12 | Phase 1 | [PHASE-4-SCRIPTS.md](PHASE-4-SCRIPTS.md) |
| 5 | GUI Dashboard | 12 | Phases 1-4 | [PHASE-5-GUI.md](PHASE-5-GUI.md) |
| 6 | Distribution | 3 | Phases 1-5 | [PHASE-6-DISTRIBUTION.md](PHASE-6-DISTRIBUTION.md) |
| 7 | Testing | 0 (tests) | Phases 1-6 | [PHASE-7-TESTING.md](PHASE-7-TESTING.md) |
| **Total** | | **~52** | | |

**Note:** Phases 2, 3, and 4 can be worked on in parallel after Phase 1 is done. Phase 5 requires all prior phases. Phase 6 packages everything. Phase 7 verifies.

---

## Progress Tracker

### Phase 1: Foundation
- [ ] `.claude/CLAUDE.md` — Agent initialization guide
- [ ] `.claude/settings.json` — Hooks, permissions, env vars
- [ ] `.claude/rules/governance.md` — Governance rules
- [ ] `.claude/rules/structured-autonomy.md` — Autonomy constraints
- [ ] `package.json` — Node.js dependencies
- [ ] `.gitignore` — Git ignore rules
- [ ] Update root `CLAUDE.md` — Reflect implementation state

### Phase 2: Skills (16)
- [ ] `.claude/skills/onboard/SKILL.md`
- [ ] `.claude/skills/heartbeat/SKILL.md`
- [ ] `.claude/skills/delegate/SKILL.md`
- [ ] `.claude/skills/escalate/SKILL.md`
- [ ] `.claude/skills/report/SKILL.md`
- [ ] `.claude/skills/message/SKILL.md`
- [ ] `.claude/skills/approve/SKILL.md`
- [ ] `.claude/skills/budget-check/SKILL.md`
- [ ] `.claude/skills/hire-agent/SKILL.md`
- [ ] `.claude/skills/fire-agent/SKILL.md`
- [ ] `.claude/skills/reconfigure-agent/SKILL.md`
- [ ] `.claude/skills/review-work/SKILL.md`
- [ ] `.claude/skills/status/SKILL.md`
- [ ] `.claude/skills/dashboard/SKILL.md`
- [ ] `.claude/skills/task/SKILL.md`
- [ ] master-gpt-prompter — ALREADY EXISTS (verify, do not overwrite)

### Phase 3: Core Agents
- [ ] `.claude/agents/ceo.md` — CEO definition
- [ ] `.claude/agents/cao.md` — CAO definition

### Phase 4: Scripts (12)
- [ ] `scripts/heartbeat.sh` — Multi-phase orchestration
- [ ] `scripts/hooks/activity-logger.sh`
- [ ] `scripts/hooks/remind-state-update.sh`
- [ ] `scripts/hooks/require-state-and-communication.sh`
- [ ] `scripts/hooks/data-access-check.sh`
- [ ] `scripts/hooks/message-routing-check.sh`
- [ ] `scripts/hooks/require-board-approval.sh`
- [ ] `scripts/hooks/require-cao-or-board.sh`
- [ ] `scripts/hooks/skill-access-check.sh`
- [ ] `scripts/hooks/budget-check.sh`
- [ ] `scripts/hooks/log-agent-activation.sh`
- [ ] `scripts/hooks/log-agent-deactivation.sh`

### Phase 5: GUI Dashboard (12)
- [ ] `gui/server.js`
- [ ] `gui/public/index.html`
- [ ] `gui/public/style.css`
- [ ] `gui/public/app.js`
- [ ] `gui/api/orgchart.js`
- [ ] `gui/api/agents.js`
- [ ] `gui/api/tasks.js`
- [ ] `gui/api/messages.js`
- [ ] `gui/api/budget.js`
- [ ] `gui/api/audit.js`
- [ ] `gui/api/approvals.js`
- [ ] `gui/api/agent.js`

### Phase 6: Distribution (3)
- [ ] `create-orgagent/package.json`
- [ ] `create-orgagent/bin/index.js`
- [ ] `README.md`

### Phase 7: Testing (14 scenarios)
- [ ] Scenario 1: Scaffolding
- [ ] Scenario 2: Onboarding
- [ ] Scenario 3: Status
- [ ] Scenario 4: CEO Heartbeat
- [ ] Scenario 5: CAO Hire
- [ ] Scenario 6: Board Approve
- [ ] Scenario 7: Delegation
- [ ] Scenario 8: Full Heartbeat
- [ ] Scenario 9: Budget Check
- [ ] Scenario 10: Audit Log
- [ ] Scenario 11: GUI
- [ ] Scenario 12: Scheduled Heartbeat
- [ ] Scenario 13: Agent Replace
- [ ] Scenario 14: Board Reject

---

## Spec Document Reference Map

Which TO-DO doc to read for each component:

| Component | Primary Spec | Supporting Specs |
|-----------|-------------|-----------------|
| **Foundation** | `01-MASTER-PLAN.md` | `17` (settings.json, package.json, rules content) |
| **Agent Init Guide** | `17` (Part 3) | `09` (Decision 34) |
| **Settings.json** | `16` (Part 5) | `01`, `12`, `15` |
| **Rules files** | `17` (Part 2) | `09` (Decision 21) |
| **Onboard skill** | `14` (full spec) | `10` (file formats), `13` (prompting) |
| **Heartbeat skill** | `01` (lines 348-386) | `16` (observability) |
| **Communication skills** | `17` (Part 1) | `15` (chat layer), `10` (formats) |
| **CAO skills** | `17` (Part 1) | `12` (permissions), `14` (CAO workspace) |
| **Agent definitions** | `14` (Steps 2.10-2.12) | `01` (Section 3-4), `10` (format 18) |
| **Heartbeat script** | `01` (lines 604-714) | `16` (budget update) |
| **Hook scripts** | `16` (Layer 1), `12`, `15`, `01` | `09` (enforcement decisions) |
| **GUI** | `01` (Section 8) | `10` (all file formats for API parsing) |
| **Distribution** | `11` (full spec) | — |
| **Testing** | `01` (verification plan) | All docs |

---

## Architecture Quick Reference

```
.claude/
  CLAUDE.md              ← Agent initialization guide (Phase 1)
  settings.json          ← Hooks + permissions (Phase 1)
  rules/                 ← Governance + autonomy (Phase 1)
  agents/ceo.md, cao.md  ← Agent definitions (Phase 3)
  skills/                ← 16 skills (Phase 2) + existing user skills

org/                     ← Created by /onboard at runtime, NOT during implementation
  alignment.md, config.md, orgchart.md
  board/, initiatives/, budgets/, messages/, rules/
  threads/executive/, threads/requests/, threads/{dept}/
  agents/ceo/, agents/cao/

scripts/
  heartbeat.sh           ← Multi-phase orchestration (Phase 4)
  hooks/*.sh             ← 11 hook scripts (Phase 4)

gui/
  server.js              ← Express server (Phase 5)
  public/                ← HTML/CSS/JS (Phase 5)
  api/                   ← 8 API routes (Phase 5)

package.json             ← Dependencies (Phase 1)
.gitignore               ← Git ignores (Phase 1)
README.md                ← Documentation (Phase 6)
```

**Note:** The `org/` directory is NOT created during implementation — it's created at runtime when a user runs `/onboard`. Implementation creates the TEMPLATE (everything under `.claude/`, `scripts/`, `gui/`).
