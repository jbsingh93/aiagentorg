#!/usr/bin/env bash
# require-cao-or-board.sh - Only CAO or board can write agent definitions
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "cao" || "$AGENT" == "board" ]]; then
  exit 0  # Allow
fi

# Extract target path from tool input
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Only block writes to .claude/agents/
if [[ "$TARGET" == *".claude/agents/"* ]]; then
  echo "Only CAO or Board can modify agent definitions. Current: $AGENT" >&2
  exit 2  # Block
fi

exit 0  # Not an agent definition write - allow
