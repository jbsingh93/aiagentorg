#!/usr/bin/env bats
# Tests for heartbeat.sh — selective invocation and orgchart parsing

load ../hooks/helpers/setup

setup() { setup_org; }
teardown() { teardown_org; }

# Source the heartbeat functions without running the main flow
# We extract has_pending_work by sourcing just the function definitions
eval "$(sed -n '/^has_pending_work/,/^}/p' scripts/heartbeat.sh)"
eval "$(sed -n '/^ALWAYS_RUN_AGENTS/p' scripts/heartbeat.sh)"

# --- has_pending_work tests ---

@test "CEO always has pending work (in ALWAYS_RUN list)" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  run has_pending_work "ceo"
  [ "$status" -eq 0 ]
}

@test "CAO always has pending work (in ALWAYS_RUN list)" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  run has_pending_work "cao"
  [ "$status" -eq 0 ]
}

@test "worker with empty inbox and no tasks has no work" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  run has_pending_work "worker1"
  [ "$status" -eq 1 ]
}

@test "worker with unread inbox notification has work" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  cat > "$TEST_ORG_DIR/agents/worker1/inbox/notif-001.md" << 'EOF'
---
type: thread-notification
read: false
---
New message
EOF
  run has_pending_work "worker1"
  [ "$status" -eq 0 ]
}

@test "worker with read notification but no tasks has no work" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  cat > "$TEST_ORG_DIR/agents/worker1/inbox/notif-001.md" << 'EOF'
---
type: thread-notification
read: true
---
Old message
EOF
  run has_pending_work "worker1"
  [ "$status" -eq 1 ]
}

@test "worker with backlog task has work" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  cat > "$TEST_ORG_DIR/agents/worker1/tasks/backlog/task-001.md" << 'EOF'
---
id: task-001
status: backlog
---
EOF
  run has_pending_work "worker1"
  [ "$status" -eq 0 ]
}

@test "worker with active task has work" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  cat > "$TEST_ORG_DIR/agents/worker1/tasks/active/task-002.md" << 'EOF'
---
id: task-002
status: active
---
EOF
  run has_pending_work "worker1"
  [ "$status" -eq 0 ]
}

@test "worker with only done tasks has no work" {
  ALWAYS_RUN_AGENTS="ceo cao alignment-board"
  ORG_DIR="$TEST_ORG_DIR"
  cat > "$TEST_ORG_DIR/agents/worker1/tasks/done/task-003.md" << 'EOF'
---
id: task-003
status: done
---
EOF
  run has_pending_work "worker1"
  [ "$status" -eq 1 ]
}
