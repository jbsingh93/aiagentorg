#!/usr/bin/env bash
# skill-access-check.sh — Only CAO or board can use agent management skills
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
if [[ "$AGENT" == "cao" || "$AGENT" == "board" ]]; then
  exit 0  # Allow
else
  echo "Only CAO or Board can use agent management skills. Current: $AGENT" >&2
  exit 2  # Block
fi
