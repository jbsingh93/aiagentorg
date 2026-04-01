#!/usr/bin/env bash
# spending-governor.sh — Enforce real-money spending limits
# Checks: Does this agent have authority to approve this amount?
# Reads spending_limits from org/config.md
# Exit codes: 0 = allow, 1 = warn, 2 = block

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Board always allowed
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Alignment board agent allowed (it governs spending)
if [[ "$AGENT" == "alignment-board" ]]; then exit 0; fi

# Only check writes that indicate spending (look for spending-related content)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null)
if ! echo "$CONTENT" | grep -qi "spend\|purchase\|payment\|cost\|invoice\|subscription"; then
  exit 0  # Not a spending action
fi

# Read spending limits from config
CONFIG="$ORG_DIR/config.md"
if [[ ! -f "$CONFIG" ]]; then exit 0; fi

BOARD_THRESHOLD=$(grep "board_required_above:" "$CONFIG" 2>/dev/null | awk '{print $2}' || echo "0")

# Default to 0 if not found or empty
if [[ -z "$BOARD_THRESHOLD" ]]; then
  BOARD_THRESHOLD="0"
fi

# If board_required_above is 0, all spending needs board approval
if [[ "$BOARD_THRESHOLD" == "0" ]]; then
  echo "SPENDING BLOCKED: All real-money spending requires board approval (board_required_above: 0). Create a spending proposal in org/board/approvals/." >&2
  exit 2
fi

exit 0
