#!/usr/bin/env bash
# alignment-protect.sh — Protect the constitutional document
# ONLY the human can edit org/alignment.md. No agent. No exception.
# Also prevents creating files that could bypass alignment (e.g., org/alignment-v2.md)
# Exit codes: 0 = allow, 1 = warn, 2 = block

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Board (human) can always edit — this is the ONLY exception
if [[ "$AGENT" == "board" ]]; then
  exit 0
fi

# If no target path detected, allow (safety fallback)
if [[ -z "$TARGET" ]]; then
  exit 0
fi

# Block writes to alignment.md (the constitutional document)
if [[ "$TARGET" == *"alignment.md"* ]]; then
  echo "ALIGNMENT PROTECTION: Only the human board can modify org/alignment.md. If you believe the alignment needs updating, create a request in org/board/approvals/ with type: alignment-amendment. The human will review and make the change." >&2
  exit 2
fi

# Block creation of alternative alignment files (drift prevention)
# Catches: alignment-v2.md, new-alignment.md, alignment-override.md, etc.
if [[ "$TARGET" == *"alignment"* && "$TARGET" == *".md"* ]]; then
  echo "ALIGNMENT PROTECTION: Cannot create files with 'alignment' in the name. This prevents drift from the constitutional document. Use org/board/approvals/ to propose changes." >&2
  exit 2
fi

exit 0
