#!/usr/bin/env bats
# Tests for integrity-check.sh — validates org filesystem state

load ../hooks/helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

SCRIPT="scripts/integrity-check.sh"

@test "org with missing agent definitions returns degraded (not critical)" {
  # Fixture agents don't have .claude/agents/*.md files — expected warnings
  run bash "$SCRIPT"
  # Should be degraded (warnings about missing definitions) but NOT critical
  [ "$status" -eq 1 ]
  [[ "$output" == *'"status":"degraded"'* ]]
}

@test "missing config.md is critical" {
  rm -f "$TEST_ORG_DIR/config.md"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *'"status":"critical"'* ]]
  [[ "$output" == *"config.md"* ]]
}

@test "missing alignment.md is critical" {
  rm -f "$TEST_ORG_DIR/alignment.md"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"alignment.md"* ]]
}

@test "missing orgchart.md is critical" {
  rm -f "$TEST_ORG_DIR/orgchart.md"
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"orgchart.md"* ]]
}

@test "missing agent workspace detected" {
  # Add an agent to orgchart that has no workspace
  echo '      - **Ghost Agent** (active) @ghost-agent -- Missing workspace' >> "$TEST_ORG_DIR/orgchart.md"
  run bash "$SCRIPT"
  [[ "$output" == *"ghost-agent"* ]]
  [[ "$output" == *"no workspace"* ]]
}

@test "missing IDENTITY.md detected as warning" {
  rm -f "$TEST_ORG_DIR/agents/worker1/IDENTITY.md"
  run bash "$SCRIPT"
  [[ "$output" == *"worker1"* ]]
  [[ "$output" == *"IDENTITY.md"* ]]
}

@test "missing task directories are auto-repaired" {
  rm -rf "$TEST_ORG_DIR/agents/ceo/tasks"
  run bash "$SCRIPT"
  # Check that directories were recreated
  [ -d "$TEST_ORG_DIR/agents/ceo/tasks/backlog" ]
  [ -d "$TEST_ORG_DIR/agents/ceo/tasks/active" ]
  [ -d "$TEST_ORG_DIR/agents/ceo/tasks/done" ]
  [[ "$output" == *'"repairs":'* ]]
}

@test "orphan agent workspace detected" {
  mkdir -p "$TEST_ORG_DIR/agents/orphan-agent/activity"
  run bash "$SCRIPT"
  [[ "$output" == *"orphan-agent"* ]]
  [[ "$output" == *"not in orgchart"* ]]
}

@test "budget inconsistency detected" {
  # Set inconsistent budget values
  cat > "$TEST_ORG_DIR/budgets/overview.md" << 'EOF'
---
total_budget_usd: 100.00
total_spent_usd: 15.00
total_remaining_usd: 50.00
---
EOF
  run bash "$SCRIPT"
  [[ "$output" == *"Budget inconsistency"* ]]
}

@test "invalid agent status detected" {
  sed -i 's/status: active/status: invalid-state/' "$TEST_ORG_DIR/agents/worker1/IDENTITY.md"
  run bash "$SCRIPT"
  [[ "$output" == *"invalid status"* ]]
}
