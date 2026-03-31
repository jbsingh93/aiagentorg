#!/usr/bin/env bash
# data-access-check.sh — Enforce data access control per agent
INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Board has full access
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Extract target path from tool input
case "$TOOL" in
  Read|Glob)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // .tool_input.pattern // ""')
    ACCESS_TYPE="read"
    ;;
  Grep)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.path // ""')
    ACCESS_TYPE="read"
    ;;
  Write|Edit)
    TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    ACCESS_TYPE="write"
    ;;
  *)
    exit 0  # Non-file tools are not access-controlled here
    ;;
esac

# If no target path, allow (some tools have optional paths)
if [[ -z "$TARGET" || "$TARGET" == "null" ]]; then exit 0; fi

# Read agent's access list from IDENTITY.md
IDENTITY_FILE="$ORG_DIR/agents/$AGENT/IDENTITY.md"
if [[ ! -f "$IDENTITY_FILE" ]]; then
  echo "No IDENTITY.md found for agent: $AGENT" >&2
  exit 2
fi

# Extract allowed paths based on access type
if [[ "$ACCESS_TYPE" == "read" ]]; then
  ALLOWED=$(awk '/^access_read:/,/^[a-z]/' "$IDENTITY_FILE" | grep '^ *-' | sed 's/^ *- *//')
else
  ALLOWED=$(awk '/^access_write:/,/^[a-z]/' "$IDENTITY_FILE" | grep '^ *-' | sed 's/^ *- *//')
fi

# Check if target matches any allowed path
while IFS= read -r allowed_path; do
  [[ -z "$allowed_path" ]] && continue
  # Check if target starts with the allowed path (prefix match)
  if [[ "$TARGET" == "$allowed_path"* || "$TARGET" == *"$allowed_path"* ]]; then
    exit 0  # Allowed
  fi
done <<< "$ALLOWED"

# Not allowed
echo "ACCESS DENIED: Agent '$AGENT' cannot $ACCESS_TYPE '$TARGET'. Request access from your superior." >&2
exit 2
