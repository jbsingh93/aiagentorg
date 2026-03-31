# Phase 2: Skills (16 total)

**Objective:** Create all 16 skill SKILL.md files that provide structured workflows.
**Files to create:** 15 new skills (1 already exists: master-gpt-prompter)
**Depends on:** Phase 1 (settings.json must exist for hook references in skills)
**Estimated effort:** 4-6 hours

**CRITICAL:** Before writing ANY skill, read `.claude/skills/master-gpt-prompter/SKILL.md` and apply its prompt engineering principles. Every skill body is an LLM prompt — it must be maximally potent.

---

## Task 2.1: `/onboard` — Deep Alignment & Org Bootstrap

- [ ] **Create file:** `.claude/skills/onboard/SKILL.md`
- **Spec:** `TO-DO/14-ONBOARDING-SKILL-FULL-SPEC.md` (entire document — ~600 lines)
- **This is the MOST COMPLEX skill.** Read the full spec carefully.
- **Key content:**
  - Frontmatter: name, description, disable-model-invocation: true, allowed-tools
  - Phase 1: 11-area alignment conversation with example questions
  - 20-point completion checklist
  - Phase 2: Bootstrap org — create ALL directories and files
    - org/config.md, alignment.md, orgchart.md, budgets/, initiatives/, board/, threads/, rules/
    - CEO workspace (SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY)
    - CAO workspace (SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY)
    - .claude/agents/ceo.md and cao.md
  - Phase 3: Verification + handoff message
  - Edge case: Guard against running twice (check if org/ exists)
- **Dependencies:** Phase 1 complete
- **Verify:** Run `/onboard` in Claude Code, answer alignment questions, verify org/ is created

---

## Task 2.2: `/heartbeat` — Run Org Heartbeat Cycle

- [ ] **Create file:** `.claude/skills/heartbeat/SKILL.md`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Section 5, skill definition (lines 348-386)
- **Key content:**
  - Frontmatter: name, description, disable-model-invocation: true, allowed-tools: Bash/Read/Glob/Grep
  - argument-hint: "[agent-name] (optional)"
  - Body: If agent name given → `bash scripts/heartbeat.sh $ARGUMENTS`. If omitted → `bash scripts/heartbeat.sh`
  - Report results when complete
- **Dependencies:** Phase 1 + scripts/heartbeat.sh (Phase 4)
- **Verify:** `/heartbeat ceo` runs a single agent heartbeat

---

## Task 2.3: `/delegate` — Create Task + Notify Subordinate

- [ ] **Create file:** `.claude/skills/delegate/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "delegate" section
- **Key content:**
  - 7-step workflow: determine params → validate chain-of-command → generate task ID → create task file → communicate via thread → send notification → confirm
  - Validates assignee is a subordinate of the assigner
  - Creates task in target's tasks/backlog/
  - Appends directive message to department thread
  - Sends lightweight notification to target's inbox/
- **Dependencies:** Phase 1
- **Verify:** `/delegate marketing-manager "Create SEO strategy"` creates task + thread + notification

---

## Task 2.4: `/escalate` — Escalate Through Chain-of-Command

- [ ] **Create file:** `.claude/skills/escalate/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "escalate" section
- **Also:** `TO-DO/15-CHAT-LAYER-CHAIN-OF-COMMAND.md` → Section 8
- **Key content:**
  - Strictly upward: agent → direct supervisor → supervisor's supervisor → board
  - Creates escalation message in thread with [escalation] type
  - Board escalation writes to org/board/approvals/
  - Includes chain trail (who escalated at each level)
- **Dependencies:** Phase 1
- **Verify:** `/escalate seo-agent "Need WebSearch tool"` creates escalation in thread

---

## Task 2.5: `/report` — Write Status Report

- [ ] **Create file:** `.claude/skills/report/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "report" section
- **Also:** `TO-DO/10-FILE-FORMAT-SPECIFICATIONS.md` → Format 16 (status reports)
- **Key content:**
  - Gathers data from: tasks (active/done/backlog), current-state.md, activity stream, budget, threads
  - Writes to `org/agents/{name}/reports/daily-{YYYY-MM-DD}.md`
  - Structured format: Summary, Completed, In Progress, Backlog, Budget, Blockers, Decisions, Escalations
- **Dependencies:** Phase 1
- **Verify:** `/report ceo` generates a status report file

---

## Task 2.6: `/message` — Send Inter-Agent Message

- [ ] **Create file:** `.claude/skills/message/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1 (message integrated into delegate/escalate patterns)
- **Also:** `TO-DO/15-CHAT-LAYER-CHAIN-OF-COMMAND.md` → Section 7 (enhanced message skill)
- **Key content:**
  - Validates chain-of-command before sending (who can message whom)
  - Determines message type (directive, report, request, escalation, discussion, etc.)
  - Finds or creates thread in correct department folder
  - Appends message with greppable ID: `[MSG-YYYYMMDD-HHMMSS-{sender}]`
  - Sends lightweight notification to recipient's inbox
  - Updates thread index
- **Dependencies:** Phase 1
- **Verify:** `/message ceo marketing-manager "Prioritize SEO"` creates thread + notification

---

## Task 2.7: `/approve` — Board Approval Workflow

- [ ] **Create file:** `.claude/skills/approve/SKILL.md`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Section 5, approve skill (lines 388-413)
- **Key content:**
  - Lists pending proposals from org/board/approvals/
  - Accepts: approve/reject + proposal-id + reason
  - Updates frontmatter: status, decided_by, decided_date, decision_reason
  - Moves approved/rejected proposals to org/board/decisions/
  - If no args: interactive listing of pending items
- **Dependencies:** Phase 1
- **Verify:** `/approve` lists pending approvals

---

## Task 2.8: `/budget-check` — Verify Budget Status

- [ ] **Create file:** `.claude/skills/budget-check/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "budget-check" section
- **Key content:**
  - Reads org/config.md for currency
  - Reads org/budgets/overview.md for allocations
  - Reads org/budgets/spending-log.md for transactions
  - Presents: total budget, allocated, spent, remaining, per-agent breakdown
  - Warnings for agents over 80%
  - Last N transactions
- **Dependencies:** Phase 1
- **Verify:** `/budget-check` shows budget overview

---

## Task 2.9: `/hire-agent` — CAO: Create New Agent

- [ ] **Create file:** `.claude/skills/hire-agent/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "hire-agent" section
- **Also:** `TO-DO/12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` (tool/access determination)
- **Also:** `TO-DO/14-ONBOARDING-SKILL-FULL-SPEC.md` (workspace template patterns)
- **Key content:**
  - **Restricted to CAO/board** (hook-enforced)
  - 10-step workflow: understand request → validate feasibility → consult manager → design agent (master-gpt-prompter) → create workspace (mkdir + 5 files) → create agent definition → update orgchart → request approval → communicate → update budget
  - Uses master-gpt-prompter for all agent files
  - Creates activity/ dir (not outbox/)
  - Least privilege for tools and data access
- **Dependencies:** Phase 1
- **Verify:** `/hire-agent "SEO specialist"` creates workspace + definition + approval

---

## Task 2.10: `/fire-agent` — CAO: Deactivate Agent

- [ ] **Create file:** `.claude/skills/fire-agent/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "fire-agent" section
- **Key content:**
  - **Restricted to CAO/board**
  - Reassigns active+backlog tasks to supervisor
  - Sets IDENTITY.md status: terminated
  - Updates orgchart
  - Removes budget allocation
  - Requests board approval
  - Communicates in threads
- **Dependencies:** Phase 1
- **Verify:** `/fire-agent sales-manager "Budget constraints"` deactivates agent

---

## Task 2.11: `/reconfigure-agent` — CAO: Modify Agent

- [ ] **Create file:** `.claude/skills/reconfigure-agent/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "reconfigure-agent" section
- **Key content:**
  - **Restricted to CAO/board**
  - Reads current config, applies changes (tools, access, behavior, model, role)
  - Must follow master-gpt-prompter when rewriting SOUL/INSTRUCTIONS
  - Logs change to approvals
  - Communicates to agent and supervisor
- **Dependencies:** Phase 1
- **Verify:** `/reconfigure-agent seo-agent "Add WebSearch tool"` updates IDENTITY + definition

---

## Task 2.12: `/review-work` — Manager: Review Subordinate Output

- [ ] **Create file:** `.claude/skills/review-work/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "review-work" section
- **Key content:**
  - Finds completed tasks in subordinate's tasks/done/
  - Reads task + deliverables
  - Evaluates against acceptance criteria
  - Approves or requests revisions via thread
  - If revisions: moves task back to active/, clears completed date
- **Dependencies:** Phase 1
- **Verify:** `/review-work seo-agent task-20260331-001` shows review with feedback

---

## Task 2.13: `/status` — Show Org Overview

- [ ] **Create file:** `.claude/skills/status/SKILL.md`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Section 5, status skill (lines 415-438)
- **Key content:**
  - Reads: config.md (name/settings), orgchart.md (agents), tasks across all agents, pending approvals, budget overview, last 10 audit log entries
  - Presents as concise dashboard summary
- **Dependencies:** Phase 1
- **Verify:** `/status` shows org overview

---

## Task 2.14: `/dashboard` — Start GUI Dashboard

- [ ] **Create file:** `.claude/skills/dashboard/SKILL.md`
- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Section 5, dashboard skill (lines 440-458)
- **Key content:**
  - Runs `node gui/server.js &`
  - Tells user: "Dashboard running at http://localhost:3000"
- **Dependencies:** Phase 1 (Phase 5 for actual GUI)
- **Verify:** `/dashboard` starts server (requires Phase 5 GUI)

---

## Task 2.15: `/task` — Task Management

- [ ] **Create file:** `.claude/skills/task/SKILL.md`
- **Spec:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 1, "task" section
- **Key content:**
  - 4 subcommands: assign (→ delegate), list, view, move
  - `list`: aggregates from all agents' task directories, shows table
  - `view`: reads full task file
  - `move`: moves file between backlog/active/done, updates frontmatter timestamps
- **Dependencies:** Phase 1
- **Verify:** `/task list` shows tasks across all agents

---

## Task 2.16: `/run-org` — Continuous Autonomous Operation

- [ ] **Create file:** `.claude/skills/run-org/SKILL.md`
- **Spec:** `TO-DO/18-CONTINUOUS-OPERATION-RALPH-WIGGUM.md` → Section 4.2 (full SKILL.md provided)
- **Key content:**
  - Pre-flight: check org exists, check no overlapping loop
  - Create `org/.loop-state.md` with iteration counter
  - Run `bash scripts/heartbeat.sh` (first cycle)
  - After cycle: assess pending work (unread notifications, pending approvals, recent backlog tasks)
  - Present approvals to board for decision
  - If no pending work: output `<promise>ORG_IDLE</promise>`
  - If pending work: let Stop hook block exit and trigger next cycle
  - Behavioral rules: NEVER tell user to manually run agents
- **Dependencies:** Phase 1, heartbeat script (Phase 4), enhanced Stop hook (Phase 4)
- **Verify:** `/run-org` runs multiple cycles until quiescent

---

## Task 2.17: `/cancel-org` — Stop Continuous Loop

- [ ] **Create file:** `.claude/skills/cancel-org/SKILL.md`
- **Spec:** `TO-DO/18-CONTINUOUS-OPERATION-RALPH-WIGGUM.md` → Section 4.3
- **Key content:**
  - Check if `org/.loop-state.md` exists
  - If yes: read iteration count, delete file, confirm
  - If no: "No active loop found"
- **Dependencies:** Phase 1
- **Verify:** `/cancel-org` stops a running loop

---

## Task 2.18: master-gpt-prompter — VERIFY ONLY

- [ ] **Verify existing file:** `.claude/skills/master-gpt-prompter/SKILL.md` exists and is functional
- **DO NOT CREATE OR OVERWRITE** — this skill already exists with the user's configuration
- **Action:** Confirm it loads when Claude Code starts
- **Spec reference:** `TO-DO/13-MASTER-PROMPTER-SKILL-SPEC.md` (documents the principles the existing skill embodies)

---

## Phase 2 Verification

```bash
# All skill directories exist with SKILL.md
for skill in onboard heartbeat delegate escalate report message approve budget-check hire-agent fire-agent reconfigure-agent review-work status dashboard task; do
  if [ -f ".claude/skills/$skill/SKILL.md" ]; then echo "OK: $skill"; else echo "MISSING: $skill"; fi
done

# master-gpt-prompter already exists
if [ -f ".claude/skills/master-gpt-prompter/SKILL.md" ]; then echo "OK: master-gpt-prompter (existing)"; fi

# Total: 16 skills
echo "Total skills: $(ls -d .claude/skills/*/SKILL.md 2>/dev/null | wc -l)"
```
