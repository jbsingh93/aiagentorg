#!/usr/bin/env bats
# Tests for data-access-check.sh — enforces per-agent file access control

load helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

HOOK="scripts/hooks/data-access-check.sh"

# --- Board Access ---

@test "board has full read access" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/budgets/overview.md"}}'
  [ "$status" -eq 0 ]
}

@test "board has full write access" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"org/board/decisions/test.md"}}'
  [ "$status" -eq 0 ]
}

# --- Worker Access ---

@test "worker can read own workspace" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/agents/worker1/IDENTITY.md"}}'
  [ "$status" -eq 0 ]
}

@test "worker can write to own workspace" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"org/agents/worker1/tasks/active/task-001.md"}}'
  [ "$status" -eq 0 ]
}

@test "worker blocked from reading budget" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/budgets/overview.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"ACCESS DENIED"* ]]
}

@test "worker blocked from writing to other agent workspace" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":"org/agents/ceo/tasks/backlog/task.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"ACCESS DENIED"* ]]
}

@test "worker can read allowed thread directory" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/threads/marketing/chat.md"}}'
  [ "$status" -eq 0 ]
}

@test "worker blocked from reading executive threads" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/threads/executive/strategy.md"}}'
  [ "$status" -eq 2 ]
}

# --- CAO Access ---

@test "CAO can read entire org directory" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/budgets/overview.md"}}'
  [ "$status" -eq 0 ]
}

@test "CAO can write agent definitions" {
  export ORGAGENT_CURRENT_AGENT="cao"
  run bash "$HOOK" <<< '{"tool_name":"Write","tool_input":{"file_path":".claude/agents/new-agent.md"}}'
  [ "$status" -eq 0 ]
}

# --- Edge Cases ---

@test "non-file tool is allowed" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}'
  [ "$status" -eq 0 ]
}

@test "missing IDENTITY.md blocks access" {
  export ORGAGENT_CURRENT_AGENT="nonexistent-agent"
  run bash "$HOOK" <<< '{"tool_name":"Read","tool_input":{"file_path":"org/config.md"}}'
  [ "$status" -eq 2 ]
}

@test "Grep tool path is checked" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Grep","tool_input":{"pattern":"test","path":"org/agents/worker1/"}}'
  [ "$status" -eq 0 ]
}

@test "Grep tool blocked for unauthorized path" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash "$HOOK" <<< '{"tool_name":"Grep","tool_input":{"pattern":"test","path":"org/board/decisions/"}}'
  [ "$status" -eq 2 ]
}
