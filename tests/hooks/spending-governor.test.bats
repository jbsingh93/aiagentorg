#!/usr/bin/env bats
# Tests for spending-governor.sh — enforces real-money spending limits

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/spending-governor.sh"

@test "board always allowed to spend" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_input":{"content":"purchase subscription for $1000"}}'
  [ "$status" -eq 0 ]
}

@test "alignment-board always allowed" {
  export ORGAGENT_CURRENT_AGENT="alignment-board"
  run bash "$HOOK" <<< '{"tool_input":{"content":"spend $50 on tools"}}'
  [ "$status" -eq 0 ]
}

@test "non-spending content is allowed" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_input":{"content":"This is a regular task update with no spending."}}'
  [ "$status" -eq 0 ]
}

@test "spending content blocked when board_required_above is 0" {
  # Override config with 0 threshold
  cat > "$TEST_ORG_DIR/config.md" << 'EOF'
---
spending_limits:
  board_required_above: 0
---
EOF
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"content":"purchase a domain for the company"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"SPENDING BLOCKED"* ]]
}

@test "spending content allowed when threshold is non-zero" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"content":"purchase a domain for $10"}}'
  [ "$status" -eq 0 ]
}

@test "missing config allows spending" {
  rm -f "$TEST_ORG_DIR/config.md"
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_input":{"content":"payment for subscription"}}'
  [ "$status" -eq 0 ]
}
