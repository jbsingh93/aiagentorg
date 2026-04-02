#!/usr/bin/env bats
# Tests for alignment-check.sh — verifies initiatives/tasks reference alignment

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/alignment-check.sh"

@test "board is always allowed" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/initiatives/test.md","content":"no alignment reference"}}'
  [ "$status" -eq 0 ]
}

@test "alignment-board agent is always allowed" {
  export ORGAGENT_CURRENT_AGENT="alignment-board"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/initiatives/test.md","content":"no reference"}}'
  [ "$status" -eq 0 ]
}

@test "initiative with alignment reference is allowed" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/initiatives/growth.md","content":"initiative: q2-growth\nThis serves the mission."}}'
  [ "$status" -eq 0 ]
}

@test "task with initiative field is allowed" {
  export ORGAGENT_CURRENT_AGENT="marketing-mgr"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/agents/worker1/tasks/backlog/task.md","content":"initiative: seo-strategy\nWrite blog post."}}'
  [ "$status" -eq 0 ]
}

@test "initiative without alignment reference gets warning" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/initiatives/random.md","content":"Just do this thing without reason."}}'
  [ "$status" -eq 1 ]
  [[ "$output" == *"ALIGNMENT CHECK"* ]]
}

@test "non-initiative/task path is allowed without check" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_input":{"file_path":"org/agents/worker1/MEMORY.md","content":"no alignment here"}}'
  [ "$status" -eq 0 ]
}
