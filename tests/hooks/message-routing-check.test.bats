#!/usr/bin/env bats
# Tests for message-routing-check.sh — enforces chain-of-command communication

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/message-routing-check.sh"

# Helper to create a Write-to-inbox JSON payload
inbox_json() {
  local target_agent="$1"
  local content="${2:-type: thread-notification}"
  echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"org/agents/$target_agent/inbox/msg-001.md\",\"content\":\"$content\"}}"
}

# --- Non-inbox writes should pass through ---

@test "non-Write tool is allowed" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/agents/ceo/inbox/msg.md"}}'
  [ "$status" -eq 0 ]
}

@test "Write to non-inbox path is allowed" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"org/agents/worker1/tasks/active/task.md"}}'
  [ "$status" -eq 0 ]
}

# --- Board access ---

@test "board can message anyone" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< "$(inbox_json ceo)"
  [ "$status" -eq 0 ]
}

# --- CAO access ---

@test "CAO can message anyone (workforce authority)" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< "$(inbox_json worker1)"
  [ "$status" -eq 0 ]
}

# --- Chain-of-command: upward ---

@test "worker can message their supervisor" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< "$(inbox_json marketing-mgr)"
  [ "$status" -eq 0 ]
}

@test "manager can message their supervisor (alignment-board in this orgchart)" {
  export ORGAGENT_CURRENT_AGENT="marketing-mgr"
  run bash "$HOOK" <<< "$(inbox_json alignment-board)"
  [ "$status" -eq 0 ]
}

# --- Chain-of-command: downward ---

@test "manager can message their direct report" {
  export ORGAGENT_CURRENT_AGENT="marketing-mgr"
  run bash "$HOOK" <<< "$(inbox_json worker1)"
  [ "$status" -eq 0 ]
}

@test "CEO can message managers" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< "$(inbox_json marketing-mgr)"
  [ "$status" -eq 0 ]
}

# --- Chain-of-command: peer ---

@test "workers with same supervisor can message each other" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< "$(inbox_json seo-agent)"
  [ "$status" -eq 0 ]
}

# --- Chain-of-command: violations ---

@test "worker CANNOT message CEO directly (skip-level)" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< "$(inbox_json ceo)"
  [ "$status" -eq 2 ]
  [[ "$output" == *"CHAIN-OF-COMMAND"* ]]
}

@test "worker CANNOT message board directly" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  # board doesn't have an inbox dir in the pattern, but test the logic
  run bash "$HOOK" <<< "$(inbox_json alignment-board)"
  [ "$status" -eq 2 ]
}

# --- No orgchart = bootstrapping, allow ---

@test "missing orgchart allows all messages (bootstrapping)" {
  rm -f "$TEST_ORG_DIR/orgchart.md"
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< "$(inbox_json ceo)"
  [ "$status" -eq 0 ]
}
