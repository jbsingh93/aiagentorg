---
name: compile-knowledge
description: "Compile knowledge captures into structured, indexed knowledge articles. Processes raw agent session captures from org/knowledge/captures/ into atomic concept articles and cross-cutting connection articles. Can be triggered manually or runs automatically via hook."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[--all] (optional — recompile all captures, even previously compiled)"
---

# Compile Knowledge — Knowledge Base Compilation

This skill triggers compilation of raw knowledge captures into structured, indexed articles in the org-wide knowledge base.

## When to Run

- **Automatically**: The `knowledge-capture.sh` hook triggers compilation in the background when capture threshold is reached or at end-of-day
- **Manually**: Board or CAO can run `/compile-knowledge` at any time
- **Forced recompile**: `/compile-knowledge --all` recompiles everything (useful after schema changes)

## What It Does

1. Finds all uncompiled capture files in `org/knowledge/captures/` (files with `compiled: false`)
2. Checks SHA-256 hashes to skip captures that haven't changed since last compile
3. Invokes `scripts/knowledge-compile.sh` which uses Claude to:
   - Extract 2-5 key concepts per capture into atomic articles (`org/knowledge/concepts/`)
   - Create connection articles for cross-cutting insights (`org/knowledge/connections/`)
   - Update the master index (`org/knowledge/index.md`)
   - Append to the build log (`org/knowledge/log.md`)
4. Marks captures as compiled and updates `org/knowledge/state.json`

## Execution

### Step 1: Pre-flight Check

1. Read `org/knowledge/state.json` to see current compilation state
2. Count uncompiled captures:
   ```bash
   grep -rl "compiled: false" org/knowledge/captures/ 2>/dev/null | wc -l
   ```
3. If no uncompiled captures and `--all` was not specified, report "Nothing to compile" and exit

### Step 2: Run Compilation

```bash
bash scripts/knowledge-compile.sh
```

If `$ARGUMENTS` contains `--all`:
```bash
# Reset all captures to uncompiled first
for f in org/knowledge/captures/*.md; do
  sed -i 's/compiled: true/compiled: false/' "$f" 2>/dev/null
done
bash scripts/knowledge-compile.sh
```

### Step 3: Report Results

1. Read `org/knowledge/state.json` for updated stats
2. Read `org/knowledge/log.md` (last entry) for compilation details
3. Report to the user:
   - Number of captures compiled
   - Number of articles created/updated
   - Total articles in knowledge base
   - Any errors from `.compile-errors.log`

## Important Rules

- **Board and CAO only** can run this skill manually (other agents trigger it indirectly via the capture hook)
- **Never delete** existing articles during compilation — only create and update
- **Budget tracking**: Compilation costs are tracked in `state.json` (each compile uses Claude API)
- **Lock protection**: Only one compilation can run at a time (`.compile-lock` file)
- **Incremental by default**: Only processes changed captures unless `--all` is specified
