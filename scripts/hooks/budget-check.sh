#!/usr/bin/env bash
# budget-check.sh — Warns if agent budget is exhausted (PostToolUse on task creation)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then
  exit 0  # Board always allowed
fi
# Read agent's remaining budget from overview (last data column = Remaining)
BUDGET_FILE="${ORGAGENT_ORG_DIR:-org}/budgets/overview.md"
REMAINING=$(grep "$AGENT" "$BUDGET_FILE" 2>/dev/null | awk -F'|' '{gsub(/[$[:space:]]/, "", $5); print $5}')
if [[ -n "$REMAINING" ]] && awk "BEGIN {exit !($REMAINING <= 0)}" 2>/dev/null; then
  echo "Budget exhausted for agent: $AGENT. Remaining: $REMAINING" >&2
  exit 2  # Block
fi
exit 0
