#!/usr/bin/env bash
# alignment-check.sh — Verify decisions reference alignment principles
# Fires on: Write to org/initiatives/ and org/agents/*/tasks/backlog/
# Purpose: Ensure every initiative and major task traces to the mission
# Exit codes: 0 = allow, 1 = warn, 2 = block

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null)

# Board always allowed
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Alignment board agent always allowed (it IS the governance)
if [[ "$AGENT" == "alignment-board" ]]; then exit 0; fi

# Only check writes to initiatives and task backlogs
if [[ "$TARGET" != *"initiatives/"* && "$TARGET" != *"tasks/backlog/"* ]]; then
  exit 0
fi

# Check if content references alignment (initiative field or alignment keyword)
if echo "$CONTENT" | grep -qi "initiative:\|alignment\|mission\|values\|strategic"; then
  exit 0  # Has alignment reference
fi

# Warn (don't block) — the agent should justify
echo '{"hookSpecificOutput":{"reason":"ALIGNMENT CHECK: This initiative/task does not reference any alignment principle (mission, values, strategic goals). Add an initiative: field or explain how this serves the mission."}}' >&2
exit 1
