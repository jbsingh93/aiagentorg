#!/usr/bin/env bats
# Tests for require-board-approval.sh — only board can write to decisions/

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/require-board-approval.sh"

@test "board can write to decisions" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/board/decisions/decision-001.md"}}'
  [ "$status" -eq 0 ]
}

@test "CEO blocked from writing to decisions" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/board/decisions/decision-001.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Only the board"* ]]
}

@test "CAO blocked from writing to decisions" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/board/decisions/decision-001.md"}}'
  [ "$status" -eq 2 ]
}

@test "agent can write to approvals (not decisions)" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/board/approvals/proposal-001.md"}}'
  [ "$status" -eq 0 ]
}

@test "agent can write to non-board paths" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/agents/worker1/tasks/active/task.md"}}'
  [ "$status" -eq 0 ]
}
