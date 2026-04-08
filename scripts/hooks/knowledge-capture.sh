#!/usr/bin/env bash
# knowledge-capture.sh — Extract knowledge from agent sessions on SubagentStop
#
# Fires on: SubagentStop
# Purpose: Reads the stopping agent's MEMORY.md, current-state.md, today's
#          thread messages, and completed tasks. Extracts knowledge-worthy
#          content into org/knowledge/captures/YYYY-MM-DD-{agent}.md.
#          Then checks if compilation should be triggered.
#
# This is pure file I/O — no LLM calls. Runs in <2 seconds.
# Exit codes: 0 = success (always — capture failures must not block agent stop)

INPUT=$(cat)
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
TODAY=$(date +%Y-%m-%d)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
TIME_ONLY=$(date +%H:%M)
HOUR=$(date +%H)

# Extract agent name from SubagentStop event
AGENT=$(echo "$INPUT" | jq -r '.agent_name // ""' 2>/dev/null)
if [[ -z "$AGENT" || "$AGENT" == "null" ]]; then
  exit 0  # Cannot identify agent — skip silently
fi

# Skip capture for alignment-board agent (governance only, no operational knowledge)
if [[ "$AGENT" == "alignment-board" ]]; then
  exit 0
fi

# Check if knowledge capture is enabled (read from config)
CONFIG_FILE="$ORG_DIR/config.md"
if [[ -f "$CONFIG_FILE" ]]; then
  ENABLED=$(grep "knowledge_capture_enabled:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
  if [[ "$ENABLED" == "false" ]]; then
    exit 0
  fi
fi

# === Paths ===
AGENT_DIR="$ORG_DIR/agents/$AGENT"
CAPTURE_DIR="$ORG_DIR/knowledge/captures"
CAPTURE_FILE="$CAPTURE_DIR/$TODAY-$AGENT.md"

# Ensure directories exist
mkdir -p "$CAPTURE_DIR"

# If agent workspace doesn't exist, skip
if [[ ! -d "$AGENT_DIR" ]]; then
  exit 0
fi

# === Collect knowledge-worthy content ===
CONTENT=""

# --- 1. MEMORY.md: Extract key facts, decisions, heuristics ---
MEMORY_FILE="$AGENT_DIR/MEMORY.md"
if [[ -f "$MEMORY_FILE" ]]; then
  # Extract sections using state-based awk (start on header, stop on next header)
  DECISIONS=$(awk '/^## Strategic Decisions/{f=1; next} /^##/{f=0} f' "$MEMORY_FILE" | grep '^ *-' | grep "$TODAY" | head -5)
  HEURISTICS=$(awk '/^## Process Heuristics/{f=1; next} /^##/{f=0} f' "$MEMORY_FILE" | grep '^ *-' | head -5)
  LEARNINGS=$(awk '/^## Learnings/{f=1; next} /^##/{f=0} f' "$MEMORY_FILE" | grep '^ *-' | head -5)

  if [[ -n "$DECISIONS" || -n "$LEARNINGS" || -n "$HEURISTICS" ]]; then
    CONTENT="${CONTENT}\n### From MEMORY.md"
    [[ -n "$DECISIONS" ]] && CONTENT="${CONTENT}\n**Decisions:**\n${DECISIONS}"
    [[ -n "$LEARNINGS" ]] && CONTENT="${CONTENT}\n**Learnings:**\n${LEARNINGS}"
    [[ -n "$HEURISTICS" ]] && CONTENT="${CONTENT}\n**Heuristics:**\n${HEURISTICS}"
    CONTENT="${CONTENT}\n"
  fi
fi

# --- 2. current-state.md: Extract reasoning traces and active decisions ---
STATE_FILE="$AGENT_DIR/activity/current-state.md"
if [[ -f "$STATE_FILE" ]]; then
  ACTIVE_DECISION=$(awk '/^## Active Decision/{f=1; next} /^##/{f=0} f' "$STATE_FILE" | head -10)
  REASONING=$(awk '/^## Reasoning Trace/{f=1; next} /^##/{f=0} f' "$STATE_FILE" | head -10)
  COMPLETED=$(awk '/^## Completed This Cycle/{f=1; next} /^##/{f=0} f' "$STATE_FILE" | head -10)

  if [[ -n "$ACTIVE_DECISION" || -n "$REASONING" || -n "$COMPLETED" ]]; then
    CONTENT="${CONTENT}\n### From Current State"
    [[ -n "$ACTIVE_DECISION" ]] && CONTENT="${CONTENT}\n**Active Decision:**\n${ACTIVE_DECISION}"
    [[ -n "$REASONING" ]] && CONTENT="${CONTENT}\n**Reasoning:**\n${REASONING}"
    [[ -n "$COMPLETED" ]] && CONTENT="${CONTENT}\n**Completed:**\n${COMPLETED}"
    CONTENT="${CONTENT}\n"
  fi
fi

# --- 3. Thread messages: Extract today's messages by this agent ---
THREAD_CONTENT=""
if [[ -d "$ORG_DIR/threads" ]]; then
  # Search for messages from this agent in today's threads
  THREAD_MSGS=$(grep -rl "\[MSG-${TODAY//\-/}.*-${AGENT}\]" "$ORG_DIR/threads/" 2>/dev/null | head -5)
  for THREAD_FILE in $THREAD_MSGS; do
    THREAD_NAME=$(basename "$THREAD_FILE" .md)
    THREAD_DIR=$(basename "$(dirname "$THREAD_FILE")")
    # Extract this agent's messages (first line of each message block)
    MSGS=$(grep -A2 "\[MSG-${TODAY//\-/}.*-${AGENT}\]" "$THREAD_FILE" 2>/dev/null | grep -v '^--$' | head -6)
    if [[ -n "$MSGS" ]]; then
      THREAD_CONTENT="${THREAD_CONTENT}\n- Thread ${THREAD_DIR}/${THREAD_NAME}: $(echo "$MSGS" | head -1 | cut -c1-120)"
    fi
  done

  if [[ -n "$THREAD_CONTENT" ]]; then
    CONTENT="${CONTENT}\n### Key Communications${THREAD_CONTENT}\n"
  fi
fi

# --- 4. Completed tasks: Check for tasks moved to done/ today ---
DONE_DIR="$AGENT_DIR/tasks/done"
if [[ -d "$DONE_DIR" ]]; then
  TASKS_DONE=""
  for TASK_FILE in "$DONE_DIR"/*.md; do
    [[ ! -f "$TASK_FILE" ]] && continue
    # Check if task was completed today (look for today's date in the file)
    if grep -q "$TODAY" "$TASK_FILE" 2>/dev/null; then
      TASK_TITLE=$(grep "^title:" "$TASK_FILE" 2>/dev/null | head -1 | sed 's/^title: *//')
      TASK_ID=$(basename "$TASK_FILE" .md)
      [[ -z "$TASK_TITLE" ]] && TASK_TITLE="$TASK_ID"
      TASKS_DONE="${TASKS_DONE}\n- ${TASK_ID}: ${TASK_TITLE}"
    fi
  done

  if [[ -n "$TASKS_DONE" ]]; then
    CONTENT="${CONTENT}\n### Task Outcomes${TASKS_DONE}\n"
  fi
fi

# === Only write capture if there's actual content ===
if [[ -z "$CONTENT" ]]; then
  exit 0  # Nothing worth capturing
fi

# === Write or append to capture file ===
if [[ ! -f "$CAPTURE_FILE" ]]; then
  # Create new capture file with frontmatter
  cat > "$CAPTURE_FILE" << HEADER
---
agent: $AGENT
date: $TODAY
capture_count: 1
last_capture: $TIMESTAMP
compiled: false
---

# Knowledge Capture — $AGENT — $TODAY
HEADER
else
  # Increment capture count and reset compiled flag (new content needs compilation)
  CURRENT_COUNT=$(grep "capture_count:" "$CAPTURE_FILE" 2>/dev/null | awk '{print $2}')
  CURRENT_COUNT=${CURRENT_COUNT:-0}
  NEW_COUNT=$((CURRENT_COUNT + 1))
  sed -i "s|capture_count: .*|capture_count: $NEW_COUNT|" "$CAPTURE_FILE" 2>/dev/null
  sed -i "s|last_capture: .*|last_capture: $TIMESTAMP|" "$CAPTURE_FILE" 2>/dev/null
  sed -i "s|compiled: true|compiled: false|" "$CAPTURE_FILE" 2>/dev/null
fi

# Append session content
echo "" >> "$CAPTURE_FILE"
echo "## Session $TIME_ONLY" >> "$CAPTURE_FILE"
echo -e "$CONTENT" >> "$CAPTURE_FILE"

# === Check if compilation should trigger ===
# Read thresholds from config
COMPILE_THRESHOLD=5
COMPILE_HOUR=18
if [[ -f "$CONFIG_FILE" ]]; then
  CFG_THRESHOLD=$(grep "knowledge_compile_threshold:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
  CFG_HOUR=$(grep "knowledge_compile_hour:" "$CONFIG_FILE" 2>/dev/null | awk '{print $2}')
  [[ -n "$CFG_THRESHOLD" ]] && COMPILE_THRESHOLD="$CFG_THRESHOLD"
  [[ -n "$CFG_HOUR" ]] && COMPILE_HOUR="$CFG_HOUR"
fi

# Count uncompiled captures
UNCOMPILED_COUNT=0
for CAP in "$CAPTURE_DIR"/*.md; do
  [[ ! -f "$CAP" ]] && continue
  if grep -q "compiled: false" "$CAP" 2>/dev/null; then
    UNCOMPILED_COUNT=$((UNCOMPILED_COUNT + 1))
  fi
done

# Determine if we should compile
SHOULD_COMPILE=false
if [[ "$UNCOMPILED_COUNT" -ge "$COMPILE_THRESHOLD" ]]; then
  SHOULD_COMPILE=true
fi
if [[ "10#$HOUR" -ge "10#$COMPILE_HOUR" && "$UNCOMPILED_COUNT" -gt 0 ]]; then
  SHOULD_COMPILE=true
fi

# Trigger background compilation if needed (and not already running)
LOCK_FILE="$ORG_DIR/knowledge/.compile-lock"
# Resolve compile script path relative to this hook's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPILE_SCRIPT="$SCRIPT_DIR/../knowledge-compile.sh"

if [[ "$SHOULD_COMPILE" == "true" && -f "$COMPILE_SCRIPT" && ! -f "$LOCK_FILE" ]]; then
  # Spawn compilation in background — non-blocking
  nohup bash "$COMPILE_SCRIPT" > "$ORG_DIR/knowledge/.compile-output.log" 2>&1 &
fi

exit 0
