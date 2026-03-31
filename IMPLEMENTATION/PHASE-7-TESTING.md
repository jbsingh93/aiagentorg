# Phase 7: Testing & Verification

**Objective:** End-to-end verification of all flows. Confirm every component works together.
**Files to create:** 0 (this phase runs tests, doesn't create implementation files)
**Depends on:** Phases 1-6 (everything must be built)
**Estimated effort:** 4-6 hours

---

## Reference

- **Verification plan:** `TO-DO/01-MASTER-PLAN.md` → Verification Plan (14 scenarios)
- **Edge cases:** `TO-DO/17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` → Part 4

---

## Pre-Test Setup

Before running any tests:

```bash
# 1. Ensure all files exist
bash -c 'source IMPLEMENTATION/verify-all.sh'  # (or manually check each phase)

# 2. Ensure npm dependencies installed
npm install

# 3. Ensure jq is available (required by hooks)
jq --version || echo "INSTALL JQ: winget install jqlang.jq"

# 4. Ensure claude CLI is available
claude --version
```

---

## Test Scenarios

### Scenario 1: Scaffolding (Distribution)

- [ ] **Test:** `node create-orgagent/bin/index.js /tmp/test-co`
- **Expected:** Directory created with all template files
- **Verify:**
  ```bash
  ls /tmp/test-co/.claude/settings.json
  ls /tmp/test-co/.claude/agents/ceo.md
  ls /tmp/test-co/.claude/skills/onboard/SKILL.md
  ls /tmp/test-co/scripts/heartbeat.sh
  ls /tmp/test-co/gui/server.js
  ls /tmp/test-co/package.json
  ```

---

### Scenario 2: Onboarding

- [ ] **Test:** Open Claude Code in project, type `/onboard`
- **Expected:** Interactive conversation → org/ folder populated
- **Verify:**
  ```bash
  # All critical org files exist
  for f in org/config.md org/alignment.md org/orgchart.md org/budgets/overview.md org/budgets/spending-log.md org/board/audit-log.md; do
    [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
  done
  
  # CEO workspace complete
  for f in SOUL.md IDENTITY.md INSTRUCTIONS.md HEARTBEAT.md MEMORY.md; do
    [ -f "org/agents/ceo/$f" ] && echo "OK: ceo/$f" || echo "MISSING: ceo/$f"
  done
  
  # CAO workspace complete
  for f in SOUL.md IDENTITY.md INSTRUCTIONS.md HEARTBEAT.md MEMORY.md; do
    [ -f "org/agents/cao/$f" ] && echo "OK: cao/$f" || echo "MISSING: cao/$f"
  done
  
  # Directories exist
  for d in org/agents/ceo/tasks/backlog org/agents/ceo/inbox org/agents/ceo/activity org/threads/executive org/threads/requests; do
    [ -d "$d" ] && echo "OK: $d" || echo "MISSING: $d"
  done
  
  # Orgchart has CEO + CAO
  grep "@ceo" org/orgchart.md && echo "OK: CEO in orgchart"
  grep "@cao" org/orgchart.md && echo "OK: CAO in orgchart"
  
  # Config has currency (not hardcoded USD)
  grep "currency:" org/config.md
  ```

---

### Scenario 3: Status Check

- [ ] **Test:** Type `/status` in Claude Code
- **Expected:** Shows org overview with CEO + CAO, 0 tasks, budget summary
- **Verify:** Output shows org name, 2 agents, budget info, no errors

---

### Scenario 4: CEO Heartbeat

- [ ] **Test:** Type `/heartbeat ceo`
- **Expected:** CEO reads state, reviews initiatives, creates initial plan, writes report
- **Verify:**
  ```bash
  # Activity stream created
  ls org/agents/ceo/activity/$(date +%Y-%m-%d).md
  
  # Current-state.md exists
  [ -f org/agents/ceo/activity/current-state.md ] && echo "OK"
  
  # Report written
  ls org/agents/ceo/reports/daily-$(date +%Y-%m-%d).md
  
  # Spending logged
  tail -3 org/budgets/spending-log.md
  
  # Audit log has entries
  tail -5 org/board/audit-log.md
  ```

---

### Scenario 5: CAO Hire Proposal

- [ ] **Test:** Tell Claude: "Ask the CAO to assess hiring needs and propose a marketing manager"
- **Alternative:** `/heartbeat cao` after CEO has sent hiring request
- **Expected:** CAO creates agent workspace + definition + approval proposal
- **Verify:**
  ```bash
  # Approval file exists
  ls org/board/approvals/approval-hire-*
  
  # Agent workspace created (pending approval)
  ls org/agents/marketing-manager/SOUL.md 2>/dev/null
  
  # Orgchart updated
  grep "marketing-manager" org/orgchart.md
  grep "pending-approval" org/orgchart.md
  
  # Thread created
  ls org/threads/executive/thread-hiring-*
  ```

---

### Scenario 6: Board Approve Hire

- [ ] **Test:** Type `/approve` then approve the marketing manager hire
- **Expected:** Agent activated, orgchart updated, supervisor notified
- **Verify:**
  ```bash
  # Status changed to active
  grep "active" org/agents/marketing-manager/IDENTITY.md
  
  # Orgchart shows active
  grep "active, @marketing-manager" org/orgchart.md
  
  # Approval moved to decisions/
  ls org/board/decisions/approval-hire-marketing-manager*
  
  # Budget updated
  grep "marketing-manager" org/budgets/overview.md
  ```

---

### Scenario 7: Delegation Chain

- [ ] **Test:** "Tell the CEO to delegate SEO strategy to the marketing manager"
- **Expected:** Task created in marketing-manager's backlog, thread message sent
- **Verify:**
  ```bash
  # Task exists
  ls org/agents/marketing-manager/tasks/backlog/task-*
  
  # Thread has directive message
  grep "\[directive\]" org/threads/marketing/thread-*
  
  # Notification in marketing-manager's inbox
  ls org/agents/marketing-manager/inbox/notif-*
  ```

---

### Scenario 8: Full Heartbeat Cycle

- [ ] **Test:** `/heartbeat` (full org cycle)
- **Expected:** All 4 phases run — CEO → Managers → Workers → CAO
- **Verify:**
  ```bash
  # Multiple agents ran (check activity streams)
  for agent in ceo marketing-manager cao; do
    [ -f "org/agents/$agent/activity/$(date +%Y-%m-%d).md" ] && echo "OK: $agent ran" || echo "MISSING: $agent"
  done
  
  # Spending log has multiple entries
  wc -l org/budgets/spending-log.md
  ```

---

### Scenario 9: Budget Enforcement

- [ ] **Test:** Set an agent's budget to 0 in overview.md, then try to create a task for them
- **Expected:** budget-check.sh hook blocks task creation
- **Verify:** Error message mentions "Budget exhausted"

---

### Scenario 10: Audit Trail

- [ ] **Test:** Perform several actions, then check audit log
- **Expected:** Every file operation logged in audit-log.md AND agent activity streams
- **Verify:**
  ```bash
  # Audit log has entries
  wc -l org/board/audit-log.md
  
  # Activity streams have entries
  wc -l org/agents/ceo/activity/$(date +%Y-%m-%d).md
  ```

---

### Scenario 11: GUI Dashboard

- [ ] **Test:** `/dashboard` then open http://localhost:3000
- **Expected:** Dark-theme dashboard with all 8 views rendering data
- **Verify:**
  - Overview tab shows org summary
  - Org chart tab shows tree visualization
  - Tasks tab shows kanban board
  - Threads tab shows conversation threads
  - Budget tab shows charts
  - Board tab shows pending approvals
  - Audit tab shows activity history
  - Activity tab shows agent activity streams

---

### Scenario 12: Scheduled Heartbeat

- [ ] **Test:** `/loop 5m /heartbeat` (short interval for testing)
- **Expected:** Heartbeat runs automatically every 5 minutes
- **Verify:** Check spending-log.md grows over time, activity streams have new entries

---

### Scenario 13: Agent Replacement

- [ ] **Test:** "Tell the CAO to replace the marketing manager with a new one"
- **Expected:** Old agent terminated, new agent created, tasks transferred
- **Verify:**
  ```bash
  # Old agent terminated
  grep "terminated" org/agents/marketing-manager/IDENTITY.md
  
  # New agent or same agent with new config
  # Tasks reassigned
  ```

---

### Scenario 14: Board Reject

- [ ] **Test:** CAO proposes a hire, then `/approve reject hire-xyz "Not needed"`
- **Expected:** Proposal rejected, moved to decisions/, CAO informed on next heartbeat
- **Verify:**
  ```bash
  # Rejection recorded
  grep "rejected" org/board/decisions/approval-hire-*
  grep "Not needed" org/board/decisions/approval-hire-*
  ```

---

## Edge Case Tests

### EC-1: First Heartbeat (No Threads, No Tasks)

- [ ] **Test:** Run `/heartbeat ceo` immediately after `/onboard`
- **Expected:** CEO reads initiatives, creates first strategic thread, sends message to CAO
- **Verify:** Thread file exists in org/threads/executive/

### EC-2: /onboard Run Twice

- [ ] **Test:** Run `/onboard` when org/ already exists
- **Expected:** Skill detects existing org, STOPS with warning message
- **Verify:** Existing org files NOT overwritten

### EC-3: Chain-of-Command Violation

- [ ] **Test:** Try to send a message from a worker directly to the CEO
- **Expected:** message-routing-check.sh BLOCKS the write with chain-of-command error
- **Verify:** Error message says "route through your supervisor"

### EC-4: Unauthorized Data Access

- [ ] **Test:** Worker agent tries to read org/budgets/overview.md (not in their access_read)
- **Expected:** data-access-check.sh BLOCKS the read
- **Verify:** Error message says "ACCESS DENIED"

### EC-5: Unauthorized Skill Use

- [ ] **Test:** A worker agent tries to invoke /hire-agent
- **Expected:** skill-access-check.sh BLOCKS
- **Verify:** Error message says "Only CAO or Board"

---

## Success Criteria

All 14 scenarios pass + all 5 edge case tests pass = **Phase 7 COMPLETE**

After Phase 7 completion:
1. Update root `CLAUDE.md` status to "Implementation complete"
2. Create git commit with all files
3. Tag as v1.0.0
4. Optionally: publish to npm with `cd create-orgagent && npm publish`
