#!/usr/bin/env bash
# ============================================================================
# integrity-check.sh — Validate org filesystem state integrity
# ============================================================================
# Runs as Phase -1 of every heartbeat cycle (before Alignment Board).
# Checks structural validity, cross-file consistency, and required files.
#
# Exit codes:
#   0 = healthy (all checks pass)
#   1 = degraded (issues found but auto-repaired or non-critical)
#   2 = critical (manual intervention required)
#
# Output: JSON report to stdout
# ============================================================================

set -uo pipefail

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
ISSUES=()
REPAIRS=()
CRITICAL=0

# ============================================================================
# Helpers
# ============================================================================

timestamp() { date -u +"%Y-%m-%dT%H:%M:%S"; }

add_issue() {
  local severity="$1" description="$2"
  ISSUES+=("$(printf '{"severity":"%s","description":"%s"}' "$severity" "$description")")
  if [[ "$severity" == "critical" ]]; then
    CRITICAL=1
  fi
}

add_repair() {
  local description="$1"
  REPAIRS+=("$(printf '{"description":"%s","timestamp":"%s"}' "$description" "$(timestamp)")")
}

log_recovery() {
  local action="$1"
  local recovery_log="$ORG_DIR/board/recovery-log.md"
  if [[ -d "$ORG_DIR/board" ]]; then
    echo "| $(timestamp) | integrity-check | $action |" >> "$recovery_log"
  fi
}

# ============================================================================
# Check 1: Required org-level files exist
# ============================================================================
check_org_files() {
  local required_files=("config.md" "alignment.md" "orgchart.md")
  for f in "${required_files[@]}"; do
    if [[ ! -f "$ORG_DIR/$f" ]]; then
      add_issue "critical" "Missing required org file: $ORG_DIR/$f"
    fi
  done

  # Budget files
  if [[ ! -f "$ORG_DIR/budgets/overview.md" ]]; then
    add_issue "warning" "Missing budget overview: $ORG_DIR/budgets/overview.md"
  fi

  # Board directories
  for d in "board/approvals" "board/decisions"; do
    if [[ ! -d "$ORG_DIR/$d" ]]; then
      mkdir -p "$ORG_DIR/$d"
      add_repair "Created missing directory: $ORG_DIR/$d"
    fi
  done
}

# ============================================================================
# Check 2: Every active agent in orgchart has a complete workspace
# ============================================================================
check_agent_workspaces() {
  [[ ! -f "$ORG_DIR/orgchart.md" ]] && return

  # Extract active agent IDs from orgchart
  local agents
  agents=$(grep "(active" "$ORG_DIR/orgchart.md" | grep -o '@[a-z0-9-]*' | sed 's/@//' || true)

  for agent in $agents; do
    local agent_dir="$ORG_DIR/agents/$agent"

    # Check workspace directory exists
    if [[ ! -d "$agent_dir" ]]; then
      add_issue "critical" "Active agent '$agent' in orgchart has no workspace: $agent_dir"
      continue
    fi

    # Check required identity files
    for f in SOUL.md IDENTITY.md INSTRUCTIONS.md HEARTBEAT.md MEMORY.md; do
      if [[ ! -f "$agent_dir/$f" ]]; then
        add_issue "warning" "Agent '$agent' missing required file: $f"
      fi
    done

    # Check required directories
    for d in activity tasks/backlog tasks/active tasks/done inbox; do
      if [[ ! -d "$agent_dir/$d" ]]; then
        mkdir -p "$agent_dir/$d"
        add_repair "Created missing directory for $agent: $d"
      fi
    done

    # Check current-state.md exists
    if [[ ! -f "$agent_dir/activity/current-state.md" ]]; then
      add_issue "warning" "Agent '$agent' missing activity/current-state.md"
    fi

    # Check agent definition exists
    if [[ ! -f ".claude/agents/$agent.md" ]]; then
      add_issue "warning" "Agent '$agent' missing definition: .claude/agents/$agent.md"
    fi
  done
}

# ============================================================================
# Check 3: Orphan detection (workspace exists but not in orgchart)
# ============================================================================
check_orphan_agents() {
  [[ ! -f "$ORG_DIR/orgchart.md" ]] && return
  [[ ! -d "$ORG_DIR/agents" ]] && return

  local orgchart_agents
  orgchart_agents=$(grep -o '@[a-z0-9-]*' "$ORG_DIR/orgchart.md" | sed 's/@//' || true)

  for agent_dir in "$ORG_DIR"/agents/*/; do
    [[ ! -d "$agent_dir" ]] && continue
    local agent_name
    agent_name=$(basename "$agent_dir")
    if ! echo "$orgchart_agents" | grep -qw "$agent_name"; then
      add_issue "warning" "Orphan agent workspace: '$agent_name' not in orgchart.md"
    fi
  done
}

# ============================================================================
# Check 4: YAML frontmatter validity (basic check)
# ============================================================================
check_yaml_frontmatter() {
  [[ ! -d "$ORG_DIR/agents" ]] && return

  for identity_file in "$ORG_DIR"/agents/*/IDENTITY.md; do
    [[ ! -f "$identity_file" ]] && continue
    local agent_name
    agent_name=$(basename "$(dirname "$identity_file")")

    # Check file starts with ---
    local first_line
    first_line=$(head -1 "$identity_file")
    if [[ "$first_line" != "---" ]]; then
      add_issue "warning" "Agent '$agent_name' IDENTITY.md missing opening frontmatter delimiter (---)"
    fi

    # Check required fields exist
    for field in name status; do
      if ! grep -q "^${field}:" "$identity_file"; then
        add_issue "warning" "Agent '$agent_name' IDENTITY.md missing required field: $field"
      fi
    done

    # Check status is valid
    local status
    status=$(grep "^status:" "$identity_file" | head -1 | awk '{print $2}')
    case "$status" in
      active|pending-approval|paused|terminated) ;;
      *) add_issue "warning" "Agent '$agent_name' has invalid status: '$status'" ;;
    esac
  done
}

# ============================================================================
# Check 5: Task files are in correct directories
# ============================================================================
check_task_consistency() {
  [[ ! -d "$ORG_DIR/agents" ]] && return

  for agent_dir in "$ORG_DIR"/agents/*/; do
    [[ ! -d "$agent_dir" ]] && continue
    local agent_name
    agent_name=$(basename "$agent_dir")

    for status_dir in backlog active done; do
      local task_dir="$agent_dir/tasks/$status_dir"
      [[ ! -d "$task_dir" ]] && continue
      for task_file in "$task_dir"/*.md; do
        [[ ! -f "$task_file" ]] && continue
        local file_status
        file_status=$(grep "^status:" "$task_file" | head -1 | awk '{print $2}')
        if [[ -n "$file_status" && "$file_status" != "$status_dir" ]]; then
          add_issue "warning" "Task $(basename "$task_file") in $agent_name/$status_dir/ has status: $file_status (mismatch)"
        fi
      done
    done
  done
}

# ============================================================================
# Check 6: Budget arithmetic consistency
# ============================================================================
check_budget_consistency() {
  local budget_file="$ORG_DIR/budgets/overview.md"
  [[ ! -f "$budget_file" ]] && return

  # Check total_budget_usd and total_spent_usd fields exist in frontmatter
  local total_budget total_spent total_remaining
  total_budget=$(grep "^total_budget_usd:" "$budget_file" | awk '{print $2}')
  total_spent=$(grep "^total_spent_usd:" "$budget_file" | awk '{print $2}')
  total_remaining=$(grep "^total_remaining_usd:" "$budget_file" | awk '{print $2}')

  if [[ -n "$total_budget" && -n "$total_spent" && -n "$total_remaining" ]]; then
    local expected_remaining
    expected_remaining=$(awk "BEGIN {printf \"%.2f\", $total_budget - $total_spent}")
    if [[ "$expected_remaining" != "$total_remaining" ]]; then
      add_issue "warning" "Budget inconsistency: total_remaining ($total_remaining) != total_budget ($total_budget) - total_spent ($total_spent) = $expected_remaining"
    fi
  fi
}

# ============================================================================
# Run all checks
# ============================================================================
check_org_files
check_agent_workspaces
check_orphan_agents
check_yaml_frontmatter
check_task_consistency
check_budget_consistency

# ============================================================================
# Output JSON report
# ============================================================================
ISSUE_COUNT=${#ISSUES[@]}
REPAIR_COUNT=${#REPAIRS[@]}

if [[ $CRITICAL -eq 1 ]]; then
  STATUS="critical"
elif [[ $ISSUE_COUNT -gt 0 ]]; then
  STATUS="degraded"
else
  STATUS="healthy"
fi

# Build JSON arrays
ISSUES_JSON="["
for i in "${!ISSUES[@]}"; do
  [[ $i -gt 0 ]] && ISSUES_JSON+=","
  ISSUES_JSON+="${ISSUES[$i]}"
done
ISSUES_JSON+="]"

REPAIRS_JSON="["
for i in "${!REPAIRS[@]}"; do
  [[ $i -gt 0 ]] && REPAIRS_JSON+=","
  REPAIRS_JSON+="${REPAIRS[$i]}"
done
REPAIRS_JSON+="]"

echo "{\"status\":\"$STATUS\",\"issues\":$ISSUE_COUNT,\"repairs\":$REPAIR_COUNT,\"details\":$ISSUES_JSON,\"auto_repairs\":$REPAIRS_JSON}"

# Log repairs to recovery log
for repair in "${REPAIRS[@]}"; do
  log_recovery "AUTO-REPAIR: $repair"
done

# Exit code
if [[ $CRITICAL -eq 1 ]]; then
  exit 2
elif [[ $ISSUE_COUNT -gt 0 ]]; then
  exit 1
else
  exit 0
fi
