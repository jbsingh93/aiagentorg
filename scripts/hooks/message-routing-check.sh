#!/usr/bin/env bash
# message-routing-check.sh — Enforce chain-of-command communication rules
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
TARGET_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Only check Write operations to inbox directories
if [[ "$TOOL" != "Write" ]]; then exit 0; fi
if [[ "$TARGET_PATH" != *"/inbox/"* ]]; then exit 0; fi

# Board has full access
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Extract target agent from path (org/agents/{target}/inbox/...)
TARGET_AGENT=$(echo "$TARGET_PATH" | grep -o 'agents/[^/]*' | sed 's/agents\///')
if [[ -z "$TARGET_AGENT" ]]; then exit 0; fi

# CAO can message anyone (workforce management authority)
if [[ "$AGENT" == "cao" ]]; then exit 0; fi

# Read orgchart to determine relationships
ORGCHART="$ORG_DIR/orgchart.md"
if [[ ! -f "$ORGCHART" ]]; then exit 0; fi  # No orgchart = allow (bootstrapping)

# Find the sender's supervisor
SENDER_LINE=$(grep "@$AGENT" "$ORGCHART" | head -1)
SENDER_DEPTH=$(echo "$SENDER_LINE" | sed 's/[^ ].*//' | wc -c)
# Depth in chars / 2 = hierarchy level

# Find the target's supervisor
TARGET_LINE=$(grep "@$TARGET_AGENT" "$ORGCHART" | head -1)
TARGET_DEPTH=$(echo "$TARGET_LINE" | sed 's/[^ ].*//' | wc -c)

# Get sender's supervisor (line above with less indentation)
get_supervisor() {
  local agent_id="$1"
  local agent_line_num=$(grep -n "@$agent_id" "$ORGCHART" | head -1 | cut -d: -f1)
  local agent_depth=$(sed -n "${agent_line_num}p" "$ORGCHART" | sed 's/[^ ].*//' | wc -c)

  # Walk up the file to find the first line with less indentation
  local n=$((agent_line_num - 1))
  while [ $n -gt 0 ]; do
    local line_depth=$(sed -n "${n}p" "$ORGCHART" | sed 's/[^ ].*//' | wc -c)
    if [ "$line_depth" -lt "$agent_depth" ]; then
      sed -n "${n}p" "$ORGCHART" | grep -o '@[a-z0-9-]*' | sed 's/@//'
      return
    fi
    n=$((n - 1))
  done
  echo "board"
}

SENDER_SUPERVISOR=$(get_supervisor "$AGENT")
TARGET_SUPERVISOR=$(get_supervisor "$TARGET_AGENT")

# Rule 1: Can always message your direct supervisor
if [[ "$TARGET_AGENT" == "$SENDER_SUPERVISOR" ]]; then exit 0; fi

# Rule 2: Can always message your direct reports
# (target's supervisor is the sender)
if [[ "$AGENT" == "$TARGET_SUPERVISOR" ]]; then exit 0; fi

# Rule 3: Can message peers in the same department
# (same supervisor)
if [[ "$SENDER_SUPERVISOR" == "$TARGET_SUPERVISOR" ]]; then exit 0; fi

# Rule 4: CEO can message any manager
if [[ "$AGENT" == "ceo" ]]; then
  # Check if target is a manager (depth 2 in orgchart = depth level ~6 chars)
  if [[ "$TARGET_DEPTH" -le 8 ]]; then exit 0; fi
fi

# Rule 5: Managers can message peer managers (cross-department)
# Both at depth 2, both report to CEO
if [[ "$SENDER_SUPERVISOR" == "ceo" && "$TARGET_SUPERVISOR" == "ceo" ]]; then exit 0; fi

# Rule 6: Check for urgent messages (bypass allowed)
# Read the message content to check if it's marked urgent
MESSAGE_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
if echo "$MESSAGE_CONTENT" | grep -q "priority: urgent"; then
  if [[ "$AGENT" == "ceo" || "$SENDER_DEPTH" -le 6 ]]; then
    exit 0  # CEO and executives can send urgent to anyone
  fi
fi

# Not allowed — chain-of-command violation
echo "CHAIN-OF-COMMAND VIOLATION: Agent '$AGENT' cannot directly message '$TARGET_AGENT'. Message your supervisor '$SENDER_SUPERVISOR' to route this communication." >&2
exit 2
