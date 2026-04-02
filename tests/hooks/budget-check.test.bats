#!/usr/bin/env bats
# Tests for budget-check.sh — warns/blocks if agent budget exhausted

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/budget-check.sh"

@test "board is always allowed" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "agent with remaining budget is allowed" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "agent with exhausted budget is blocked" {
  # Create a budget where worker1 has 0 remaining
  cat > "$TEST_ORG_DIR/budgets/overview.md" << 'EOF'
| Agent | Allocated | Spent | Remaining |
|-------|-----------|-------|-----------|
| ceo | $20.00 | $5.00 | $15.00 |
| exhausted-agent | $10.00 | $10.00 | $0.00 |
EOF
  export ORGAGENT_CURRENT_AGENT="exhausted-agent"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Budget exhausted"* ]]
}

@test "agent with negative budget is blocked" {
  cat > "$TEST_ORG_DIR/budgets/overview.md" << 'EOF'
| Agent | Allocated | Spent | Remaining |
|-------|-----------|-------|-----------|
| overspent | $10.00 | $15.00 | $-5.00 |
EOF
  export ORGAGENT_CURRENT_AGENT="overspent"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
}

@test "agent not in budget file is allowed (no data = no block)" {
  export ORGAGENT_CURRENT_AGENT="unknown-agent"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}
