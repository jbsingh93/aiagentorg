#!/usr/bin/env bats
# Tests for skill-access-check.sh — only CAO or board can use agent management skills

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/skill-access-check.sh"

@test "board can use management skills" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "CAO can use management skills" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
}

@test "CEO blocked from management skills" {
  export ORGAGENT_CURRENT_AGENT="ceo"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Only CAO or Board"* ]]
}

@test "worker blocked from management skills" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK"
  [ "$status" -eq 2 ]
}
