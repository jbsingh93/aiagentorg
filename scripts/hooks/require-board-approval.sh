#!/usr/bin/env bash
# require-board-approval.sh - Blocks writes to board decisions unless writer is board (human)
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then
  exit 0  # Allow
fi

# Extract target path from tool input
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

# Only block writes to org/board/decisions/
if [[ "$TARGET" == *"org/board/decisions/"* ]]; then
  echo "Only the board can write to decisions/. Current agent: $AGENT" >&2
  exit 2  # Block
fi

exit 0  # Not a decisions/ write - allow
