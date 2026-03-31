#!/usr/bin/env bash
# require-board-approval.sh — Blocks writes to board decisions unless writer is board (human)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "board" ]]; then
  exit 0  # Allow — human board can write decisions
else
  echo "Only the board can write to decisions/. Current agent: $AGENT" >&2
  exit 2  # Block
fi
