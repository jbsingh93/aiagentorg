#!/usr/bin/env bash
# knowledge-compile.sh — Compile knowledge captures into structured articles
#
# This script is spawned in the background by knowledge-capture.sh when
# enough captures accumulate or at end-of-day. It can also be invoked
# manually via /compile-knowledge skill.
#
# Process:
#   1. Acquire compile lock (prevent concurrent compilations)
#   2. Find all uncompiled captures (compiled: false)
#   3. Compute SHA-256 hashes to skip unchanged files
#   4. Invoke claude -p with the compile prompt + captures + existing articles
#   5. Mark captures as compiled, update state.json
#   6. Release lock
#
# Requirements: claude CLI, jq, sha256sum (or shasum on macOS)

set -euo pipefail

ORG_DIR="${ORGAGENT_ORG_DIR:-org}"
KNOWLEDGE_DIR="$ORG_DIR/knowledge"
CAPTURE_DIR="$KNOWLEDGE_DIR/captures"
CONCEPTS_DIR="$KNOWLEDGE_DIR/concepts"
CONNECTIONS_DIR="$KNOWLEDGE_DIR/connections"
QA_DIR="$KNOWLEDGE_DIR/qa"
INDEX_FILE="$KNOWLEDGE_DIR/index.md"
LOG_FILE="$KNOWLEDGE_DIR/log.md"
STATE_FILE="$KNOWLEDGE_DIR/state.json"
LOCK_FILE="$KNOWLEDGE_DIR/.compile-lock"
# Resolve prompt template path relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_TEMPLATE="$SCRIPT_DIR/knowledge-compile-prompt.md"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
TODAY=$(date +%Y-%m-%d)

# === Lock management ===
acquire_lock() {
  if [[ -f "$LOCK_FILE" ]]; then
    # Check if lock is stale (older than 10 minutes)
    LOCK_AGE=0
    NOW=$(date +%s)
    # GNU stat uses -c, macOS/BSD stat uses -f
    LOCK_MTIME=$(stat -c %Y "$LOCK_FILE" 2>/dev/null) || \
    LOCK_MTIME=$(stat -f %m "$LOCK_FILE" 2>/dev/null) || \
    LOCK_MTIME="0"
    LOCK_AGE=$((NOW - LOCK_MTIME))
    if [[ $LOCK_AGE -lt 600 ]]; then
      echo "Compilation already in progress (lock acquired ${LOCK_AGE}s ago). Exiting."
      exit 0
    fi
    echo "Stale lock detected (${LOCK_AGE}s old). Removing and proceeding."
    rm -f "$LOCK_FILE"
  fi
  echo "$$" > "$LOCK_FILE"
}

release_lock() {
  # Only delete the lock if this process owns it (prevents concurrent process B
  # from deleting process A's lock when B exits after failing to acquire)
  if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE" 2>/dev/null)" == "$$" ]]; then
    rm -f "$LOCK_FILE"
  fi
}

# Clean up lock on exit (success or failure)
trap release_lock EXIT

# === Hash function (cross-platform, consistent algorithm) ===
# Detect hash command once, reuse for all calls to avoid algorithm mismatch
if command -v sha256sum &>/dev/null; then
  _HASH_CMD="sha256sum"
elif command -v shasum &>/dev/null; then
  _HASH_CMD="shasum -a 256"
else
  _HASH_CMD=""
fi

file_hash() {
  if [[ -n "$_HASH_CMD" ]]; then
    $_HASH_CMD "$1" | cut -c1-16
  else
    echo "nohash"
  fi
}

# === Main ===
echo "=== Knowledge Compilation Started at $TIMESTAMP ==="

# Ensure directories exist
mkdir -p "$CONCEPTS_DIR" "$CONNECTIONS_DIR" "$QA_DIR"

# Acquire lock
acquire_lock

# Find uncompiled captures
UNCOMPILED=()
for CAP in "$CAPTURE_DIR"/*.md; do
  [[ ! -f "$CAP" ]] && continue
  if grep -q "compiled: false" "$CAP" 2>/dev/null; then
    UNCOMPILED+=("$CAP")
  fi
done

if [[ ${#UNCOMPILED[@]} -eq 0 ]]; then
  echo "No uncompiled captures found. Nothing to do."
  exit 0
fi

echo "Found ${#UNCOMPILED[@]} uncompiled capture(s)."

# Read state for hash-based deduplication
if [[ ! -f "$STATE_FILE" ]]; then
  echo '{"compiled_captures":{},"total_cost_usd":0,"last_compile":null,"article_count":0,"compile_count":0}' > "$STATE_FILE"
fi

# Check hashes — skip captures that haven't changed since last compile
TO_COMPILE=()
for CAP in "${UNCOMPILED[@]}"; do
  CAP_NAME=$(basename "$CAP")
  CURRENT_HASH=$(file_hash "$CAP")
  STORED_HASH=$(jq -r ".compiled_captures[\"$CAP_NAME\"].hash // \"\"" "$STATE_FILE" 2>/dev/null)

  if [[ "$CURRENT_HASH" != "$STORED_HASH" ]]; then
    TO_COMPILE+=("$CAP")
  else
    echo "Skipping $CAP_NAME (unchanged since last compile)"
  fi
done

if [[ ${#TO_COMPILE[@]} -eq 0 ]]; then
  echo "All captures unchanged since last compile. Nothing to do."
  exit 0
fi

echo "Compiling ${#TO_COMPILE[@]} capture(s)..."

# === Build compilation prompt ===
# Read existing index
EXISTING_INDEX=""
if [[ -f "$INDEX_FILE" ]]; then
  EXISTING_INDEX=$(cat "$INDEX_FILE")
fi

# Read existing articles (for context — so the compiler can update rather than duplicate)
EXISTING_ARTICLES=""
for ARTICLE_DIR in "$CONCEPTS_DIR" "$CONNECTIONS_DIR"; do
  for ARTICLE in "$ARTICLE_DIR"/*.md; do
    [[ ! -f "$ARTICLE" ]] && continue
    REL_PATH=$(echo "$ARTICLE" | sed "s|$KNOWLEDGE_DIR/||")
    EXISTING_ARTICLES="${EXISTING_ARTICLES}
### ${REL_PATH}
\`\`\`markdown
$(cat "$ARTICLE")
\`\`\`
"
  done
done

# Read captures to compile
CAPTURE_CONTENT=""
for CAP in "${TO_COMPILE[@]}"; do
  CAP_NAME=$(basename "$CAP")
  CAPTURE_CONTENT="${CAPTURE_CONTENT}
### ${CAP_NAME}
\`\`\`markdown
$(cat "$CAP")
\`\`\`
"
done

# Read the prompt template
if [[ ! -f "$PROMPT_TEMPLATE" ]]; then
  echo "ERROR: Prompt template not found at $PROMPT_TEMPLATE"
  exit 1
fi
BASE_PROMPT=$(cat "$PROMPT_TEMPLATE")

# Build full prompt with injected context
FULL_PROMPT="${BASE_PROMPT}

## Current Knowledge Base Index

${EXISTING_INDEX:-"(empty — no articles compiled yet)"}

## Existing Articles

${EXISTING_ARTICLES:-"(no existing articles)"}

## Captures to Compile

${CAPTURE_CONTENT}

## File Paths

- Concepts directory: ${CONCEPTS_DIR}
- Connections directory: ${CONNECTIONS_DIR}
- Index file: ${INDEX_FILE}
- Log file: ${LOG_FILE}
- Current timestamp: ${TIMESTAMP}
"

# === Invoke Claude for compilation ===
echo "Invoking Claude for compilation..."

# Use claude -p with allowed tools for file operations
COMPILE_EXIT=0
COMPILE_OUTPUT=$(claude -p "$FULL_PROMPT" \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --output-format text \
  2>"$KNOWLEDGE_DIR/.compile-errors.log") || COMPILE_EXIT=$?

if [[ $COMPILE_EXIT -ne 0 ]]; then
  echo "ERROR: Claude compilation failed (exit $COMPILE_EXIT). Captures NOT marked as compiled."
  echo "Check $KNOWLEDGE_DIR/.compile-errors.log for details."
  exit 1
fi

echo "Claude compilation finished."

# === Post-compilation: update state ===

# Mark captures as compiled (only in YAML frontmatter, not body text)
for CAP in "${TO_COMPILE[@]}"; do
  sed -i '1,/^---$/{ s/compiled: false/compiled: true/; }' "$CAP" 2>/dev/null

  CAP_NAME=$(basename "$CAP")
  CURRENT_HASH=$(file_hash "$CAP")

  # Update state.json with this capture's hash
  TEMP_STATE=$(mktemp) || { echo "ERROR: mktemp failed"; continue; }
  if jq --arg name "$CAP_NAME" \
        --arg hash "$CURRENT_HASH" \
        --arg time "$TIMESTAMP" \
        '.compiled_captures[$name] = {"hash": $hash, "compiled_at": $time}' \
        "$STATE_FILE" > "$TEMP_STATE"; then
    mv "$TEMP_STATE" "$STATE_FILE"
  else
    echo "WARNING: jq failed updating state for $CAP_NAME"
    rm -f "$TEMP_STATE"
  fi
done

# Update compile count and timestamp
ARTICLE_COUNT=$(find "$CONCEPTS_DIR" "$CONNECTIONS_DIR" "$QA_DIR" -name "*.md" 2>/dev/null | wc -l)
TEMP_STATE=$(mktemp) || { echo "ERROR: mktemp failed"; exit 1; }
if jq --arg time "$TIMESTAMP" \
      --argjson count "$ARTICLE_COUNT" \
      '.last_compile = $time | .article_count = $count | .compile_count += 1' \
      "$STATE_FILE" > "$TEMP_STATE"; then
  mv "$TEMP_STATE" "$STATE_FILE"
else
  echo "WARNING: jq failed updating compile count"
  rm -f "$TEMP_STATE"
fi

# Append to build log
echo "" >> "$LOG_FILE"
echo "## [$TIMESTAMP] Compilation #$(jq '.compile_count' "$STATE_FILE")" >> "$LOG_FILE"
echo "- Captures compiled: ${#TO_COMPILE[@]}" >> "$LOG_FILE"
for CAP in "${TO_COMPILE[@]}"; do
  echo "  - $(basename "$CAP")" >> "$LOG_FILE"
done
echo "- Articles total: $ARTICLE_COUNT" >> "$LOG_FILE"

echo "=== Compilation complete. $ARTICLE_COUNT articles in knowledge base. ==="
