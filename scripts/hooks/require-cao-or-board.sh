#!/usr/bin/env bash
# require-cao-or-board.sh — Only CAO or board can write agent definitions
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "cao" || "$AGENT" == "board" ]]; then
  exit 0  # Allow
else
  echo "Only CAO or Board can modify agent definitions. Current: $AGENT" >&2
  exit 2  # Block
fi
