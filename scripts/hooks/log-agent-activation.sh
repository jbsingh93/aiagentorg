#!/usr/bin/env bash
# log-agent-activation.sh — Log agent start to audit log
INPUT=$(cat)
AGENT=$(echo "$INPUT" | jq -r '.agent_name // "unknown"')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
ACTION="agent-start"
echo "| $TIMESTAMP | SYSTEM | $ACTION | $AGENT | Agent session started |" >> org/board/audit-log.md
exit 0
