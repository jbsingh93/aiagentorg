#!/usr/bin/env bats
# Tests for alignment-protect.sh — protects the constitutional document

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/alignment-protect.sh"

@test "board can edit alignment.md" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/alignment.md"}}'
  [ "$status" -eq 0 ]
}

@test "CEO blocked from editing alignment.md" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/alignment.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"ALIGNMENT PROTECTION"* ]]
}

@test "alignment-board agent blocked from editing alignment.md" {
  export ORGAGENT_CURRENT_AGENT="alignment-board"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/alignment.md"}}'
  [ "$status" -eq 2 ]
}

@test "agent blocked from creating alternative alignment files" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/alignment-v2.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"drift"* ]]
}

@test "agent blocked from creating new-alignment.md" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/new-alignment.md"}}'
  [ "$status" -eq 2 ]
}

@test "agent allowed to write non-alignment files" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/agents/ceo/tasks/backlog/task.md"}}'
  [ "$status" -eq 0 ]
}

@test "empty target path is allowed" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{}}'
  [ "$status" -eq 0 ]
}
