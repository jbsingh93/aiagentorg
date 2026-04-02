#!/usr/bin/env bash
# Shared test setup for OrgAgent hook tests

# Create a temporary org directory for each test
setup_org() {
  export TEST_ORG_DIR="$BATS_TMPDIR/test-org-$$-$RANDOM"
  export ORGAGENT_ORG_DIR="$TEST_ORG_DIR"
  mkdir -p "$TEST_ORG_DIR"

  # Create shared org directories
  mkdir -p "$TEST_ORG_DIR/budgets" "$TEST_ORG_DIR/board/approvals" "$TEST_ORG_DIR/board/decisions" \
           "$TEST_ORG_DIR/threads/executive" "$TEST_ORG_DIR/threads/marketing" \
           "$TEST_ORG_DIR/initiatives" "$TEST_ORG_DIR/connectors"

  # Create agent workspaces
  for agent in ceo cao alignment-board worker1 marketing-mgr seo-agent; do
    local agent_dir="$TEST_ORG_DIR/agents/$agent"
    mkdir -p "$agent_dir/activity" "$agent_dir/tasks/backlog" "$agent_dir/tasks/active" \
             "$agent_dir/tasks/done" "$agent_dir/inbox" "$agent_dir/reports" "$agent_dir/memory"
  done

  # CEO IDENTITY
  cat > "$TEST_ORG_DIR/agents/ceo/IDENTITY.md" << 'IDEOF'
---
name: ceo
title: Chief Executive Officer
status: active
model: opus
department: executive
reports_to: board
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebSearch
access_read:
  - org/
  - .claude/
access_write:
  - org/agents/ceo/
  - org/initiatives/
  - org/threads/
created: 2026-04-01
---
IDEOF

  # CAO IDENTITY
  cat > "$TEST_ORG_DIR/agents/cao/IDENTITY.md" << 'IDEOF'
---
name: cao
title: Chief Agents Officer
status: active
model: opus
department: executive
reports_to: ceo
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
access_read:
  - org/
  - .claude/agents/
  - .claude/skills/master-gpt-prompter/
access_write:
  - org/agents/cao/
  - org/agents/
  - org/orgchart.md
  - org/budgets/overview.md
  - .claude/agents/
created: 2026-04-01
---
IDEOF

  # Worker1 IDENTITY (restricted access)
  cat > "$TEST_ORG_DIR/agents/worker1/IDENTITY.md" << 'IDEOF'
---
name: worker1
title: SEO Specialist
status: active
model: haiku
department: marketing
reports_to: marketing-mgr
tools:
  - Read
  - Write
  - Edit
  - Grep
  - WebSearch
access_read:
  - org/agents/worker1/
  - org/threads/marketing/
  - org/connectors/
access_write:
  - org/agents/worker1/
  - org/threads/marketing/
created: 2026-04-01
---
IDEOF

  # Marketing Manager IDENTITY
  cat > "$TEST_ORG_DIR/agents/marketing-mgr/IDENTITY.md" << 'IDEOF'
---
name: marketing-mgr
title: Marketing Manager
status: active
model: sonnet
department: marketing
reports_to: ceo
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
access_read:
  - org/agents/marketing-mgr/
  - org/agents/worker1/
  - org/agents/seo-agent/
  - org/threads/
access_write:
  - org/agents/marketing-mgr/
  - org/threads/marketing/
created: 2026-04-01
---
IDEOF

  # SEO Agent IDENTITY
  cat > "$TEST_ORG_DIR/agents/seo-agent/IDENTITY.md" << 'IDEOF'
---
name: seo-agent
title: SEO Agent
status: active
model: haiku
department: marketing
reports_to: marketing-mgr
tools:
  - Read
  - Write
  - WebSearch
access_read:
  - org/agents/seo-agent/
  - org/threads/marketing/
access_write:
  - org/agents/seo-agent/
  - org/threads/marketing/
created: 2026-04-01
---
IDEOF

  # Alignment Board IDENTITY
  cat > "$TEST_ORG_DIR/agents/alignment-board/IDENTITY.md" << 'IDEOF'
---
name: alignment-board
title: Alignment Board
status: active
model: opus
department: governance
reports_to: board
access_read:
  - org/
access_write:
  - org/agents/alignment-board/
  - org/board/
created: 2026-04-01
---
IDEOF

  # Orgchart (indented with 2 spaces per level)
  # Board (depth 0) -> CEO (depth 1) -> managers (depth 2) -> workers (depth 3)
  cat > "$TEST_ORG_DIR/orgchart.md" << 'ORGEOF'
# Organisation Chart

- **Board** (human) @board
  - **CEO** (active) @ceo -- Strategic leadership
  - **Alignment Board** (active) @alignment-board -- Constitutional governance
    - **CAO** (active) @cao -- Workforce management
    - **Marketing Manager** (active) @marketing-mgr -- Marketing department
      - **SEO Specialist** (active) @worker1 -- SEO tasks
      - **SEO Agent** (active) @seo-agent -- SEO automation
ORGEOF

  # Config
  cat > "$TEST_ORG_DIR/config.md" << 'CFGEOF'
---
name: Test Org
language: en
industry: testing
created: 2026-04-01
oversight_level: approve-everything
heartbeat_interval: 30m
tone: professional
default_agent_model: sonnet
ceo_model: opus
cao_model: opus
spending_limits:
  board_required_above: 500
  ceo_approval_limit: 500
  manager_approval_limit: 100
currency: USD
---
CFGEOF

  # Alignment document
  cat > "$TEST_ORG_DIR/alignment.md" << 'ALEOF'
---
version: 1
last_modified: 2026-04-01
modified_by: board
---
# Mission
Test organisation for automated testing.
ALEOF

  # Budget overview
  cat > "$TEST_ORG_DIR/budgets/overview.md" << 'BUDEOF'
---
total_budget_usd: 100.00
total_allocated_usd: 60.00
total_spent_usd: 15.00
total_remaining_usd: 85.00
---

| Agent | Allocated | Spent | Remaining |
|-------|-----------|-------|-----------|
| ceo | $20.00 | $5.00 | $15.00 |
| cao | $20.00 | $5.00 | $15.00 |
| worker1 | $10.00 | $5.00 | $5.00 |
| marketing-mgr | $10.00 | $0.00 | $10.00 |
BUDEOF

  # Spending log
  cat > "$TEST_ORG_DIR/budgets/spending-log.md" << 'SPLEOF'
| Timestamp | Agent | Action | Cost | Running Total |
|-----------|-------|--------|------|---------------|
| 2026-04-01T10:00:00 | ceo | heartbeat | $5.00 | $5.00 |
| 2026-04-01T10:05:00 | cao | heartbeat | $5.00 | $10.00 |
| 2026-04-01T10:10:00 | worker1 | heartbeat | $5.00 | $15.00 |
SPLEOF

  # Audit log
  cat > "$TEST_ORG_DIR/board/audit-log.md" << 'AUDEOF'
| Timestamp | Agent | Action | Target | Details |
|-----------|-------|--------|--------|---------|
| 2026-04-01T10:00:00 | board | onboard | org | Organisation created |
AUDEOF

  # Current state files
  local today=$(date +%Y-%m-%d)
  for agent in ceo cao alignment-board worker1 marketing-mgr seo-agent; do
    cat > "$TEST_ORG_DIR/agents/$agent/activity/current-state.md" << STEOF
---
agent: $agent
last_updated: ${today}T10:00:00
status: idle
---
STEOF
  done
}

teardown_org() {
  rm -rf "$TEST_ORG_DIR"
}
