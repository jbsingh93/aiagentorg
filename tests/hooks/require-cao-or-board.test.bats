#!/usr/bin/env bats
# Tests for require-cao-or-board.sh — only CAO or board can write agent definitions

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/require-cao-or-board.sh"

@test "board can write agent definitions" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":".claude/agents/new-agent.md"}}'
  [ "$status" -eq 0 ]
}

@test "CAO can write agent definitions" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":".claude/agents/new-agent.md"}}'
  [ "$status" -eq 0 ]
}

@test "CEO blocked from writing agent definitions" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":".claude/agents/ceo.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"Only CAO or Board"* ]]
}

@test "worker blocked from writing agent definitions" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":".claude/agents/worker1.md"}}'
  [ "$status" -eq 2 ]
}

@test "CEO can write to non-agent paths" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/agents/ceo/MEMORY.md"}}'
  [ "$status" -eq 0 ]
}
