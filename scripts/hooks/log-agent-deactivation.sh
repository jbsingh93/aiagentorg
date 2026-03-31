#!/usr/bin/env bash
# log-agent-deactivation.sh — Log agent stop to audit log
INPUT=$(cat)
AGENT=$(echo "$INPUT" | jq -r '.agent_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
ACTION="agent-stop"
echo "| $TIMESTAMP | SYSTEM | $ACTION | $AGENT | Agent session stopped |" >> org/board/audit-log.md
exit 0
