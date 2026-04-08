---
name: consolidate-memory
description: "Consolidate agent memory: daily logs → weekly summaries → monthly summaries → MEMORY.md refresh. Prevents unbounded memory growth while preserving institutional knowledge. Run by CAO during heartbeat maintenance."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[agent-name] (optional — consolidate specific agent, or all if omitted)"
---

# Consolidate Memory — Tiered Memory Management

This skill manages the memory lifecycle for OrgAgent agents. It consolidates daily episodic memory into hierarchical summaries and refreshes MEMORY.md, preventing unbounded growth while preserving institutional knowledge.

## Memory Architecture

```
Daily Logs (memory/YYYY-MM-DD.md)  →  raw episodic memory
    ↓ (after 7 days)
Weekly Summaries (memory/weekly/YYYY-WNN.md)  →  key decisions, learnings, patterns
    ↓ (after 4 weeks)
Monthly Summaries (memory/monthly/YYYY-MM.md)  →  enduring facts, strategic context
    ↓ (promote durable facts)
MEMORY.md  →  semantic memory index, <200 lines
```

## When to Run

- As part of the CAO's Phase 4 heartbeat (every N heartbeat cycles, configurable)
- Manually via `/consolidate-memory` (board or CAO)
- When an agent's MEMORY.md exceeds 200 lines (triggered by memory-size-check hook)

## Pre-flight

1. Read `org/config.md` for consolidation settings:
   - `memory_consolidation_interval` (default: 7 heartbeat cycles)
   - `memory_daily_retention_days` (default: 30)
   - `activity_archive_after_days` (default: 30)
   - `memory_max_lines` (default: 200)
2. If `$ARGUMENTS` specifies an agent name, consolidate only that agent
3. Otherwise, consolidate ALL agents

## Phase 1: Daily-to-Weekly Consolidation

For each agent with 7+ unconsolidated daily memory logs:

1. Read all files in `org/agents/{name}/memory/` that match `YYYY-MM-DD.md` and do NOT have `consolidated: true` in frontmatter
2. Group by ISO week number
3. For each complete week (7 days) of unconsolidated logs:
   a. Read all 7 daily logs
   b. Extract and synthesize:
      - **Key Decisions**: What strategic or tactical decisions were made?
      - **Task Outcomes**: What tasks were completed? What were the results?
      - **Learnings**: What worked? What didn't? What was surprising?
      - **Mistakes/Failures**: What went wrong? What to avoid?
      - **Behavioral Patterns**: Any recurring themes in the agent's work?
      - **Important Communications**: Significant thread exchanges
   c. Write `org/agents/{name}/memory/weekly/YYYY-WNN.md`:

```markdown
---
agent: {name}
period: {start_date} to {end_date}
consolidated_from:
  - {daily_log_1}
  - {daily_log_2}
  - ...
created: {now}
consolidated: false
---

# Weekly Summary — Week {NN}, {YYYY}

## Key Decisions
- {decision_1} ({date})
- {decision_2} ({date})

## Task Outcomes
- {task_id}: {outcome_summary}

## Learnings
- {learning_1}
- {learning_2}

## Issues & Failures
- {issue_1}

## Patterns
- {pattern_1}
```

   d. Mark each daily log as consolidated: add `consolidated: true` to its frontmatter
   e. Move consolidated daily logs to `org/agents/{name}/memory/archive/`

## Phase 2: Weekly-to-Monthly Consolidation

For agents with 4+ unconsolidated weekly summaries:

1. Read all weekly summaries with `consolidated: false`
2. For each complete month:
   a. Synthesize the weekly summaries into a monthly view
   b. Extract: enduring facts, strategic patterns, process improvements, recurring issues
   c. Write `org/agents/{name}/memory/monthly/YYYY-MM.md`:

```markdown
---
agent: {name}
period: {YYYY-MM}
consolidated_from:
  - {weekly_1}
  - {weekly_2}
  - ...
created: {now}
---

# Monthly Summary — {Month} {YYYY}

## Enduring Facts
- {fact_1}

## Strategic Context
- {context_1}

## Process Improvements
- {improvement_1}

## Heuristics Extracted
- RULE: {heuristic_1} (learned from: {source})
```

   d. Mark weekly summaries as `consolidated: true`

## Phase 3: MEMORY.md Refresh

After consolidation:

1. Read current MEMORY.md
2. Read the latest monthly summary (if new)
3. For each entry in MEMORY.md, assess:
   - **KEEP**: Still relevant and referenced recently
   - **UPDATE**: Facts that have new information
   - **REMOVE**: Stale facts not referenced in recent summaries
   - **ADD**: New durable facts from monthly summaries
4. Apply Mem0-style operations:
   - ADD new entries under the appropriate section
   - UPDATE existing entries with new information
   - DELETE entries that are stale (>3 months without reference for Learnings, >1 month for Active Context)
   - NOOP for entries that are still current
5. **NEVER remove entries in Key Facts section** — these are critical and permanent
6. **Promote heuristics**: If a monthly summary contains RULE entries (ExpeL pattern), add them to the Process Heuristics section
7. Ensure MEMORY.md stays under 200 lines
8. Update frontmatter: `last_consolidated`, `consolidation_count`, `archived_before`

## Phase 4: Activity Stream Archival

For each agent:
1. Find activity stream files (`activity/YYYY-MM-DD.md`) older than `activity_archive_after_days`
2. Create `activity/archive/` directory if it doesn't exist
3. Move old files to `activity/archive/`
4. Do NOT delete — archive is always searchable

## Phase 5: Shared Knowledge Base Update

If `org/knowledge/` exists:
1. Review all agents' monthly summaries for cross-cutting patterns
2. Update `org/knowledge/org-wide/lessons-learned.md` with new org-wide learnings
3. Update department knowledge bases (`org/knowledge/{dept}/`) with department patterns
4. Check if `org/knowledge/raw/` has uncompiled fragments (captured by the knowledge-capture hook during SubagentStop events)
5. If uncompiled fragments exist, run `/compile-knowledge` to synthesize raw fragments into the topic files and update `org/knowledge/index.md`
6. The knowledge-capture hook automatically extracts insights from every agent session — Phase 5 is where those raw captures get integrated into the permanent knowledge base

## MEMORY.md Target Format

```markdown
---
agent: {name}
last_consolidated: {YYYY-MM-DD}
consolidation_count: {N}
archived_before: {YYYY-MM-DD}
---

# Memory — {Agent Title}

## Key Facts
<!-- importance: critical, never auto-prune -->
- {permanent_fact_1}
- {permanent_fact_2}

## Strategic Decisions
<!-- importance: high, prune after 3 months without reference -->
- {YYYY-MM-DD}: {decision} ({reasoning})

## Learnings
<!-- importance: medium, prune after 2 months -->
- {learning_1}

## Active Context
<!-- importance: variable, refresh each consolidation -->
- {current_context_1}

## Process Heuristics
<!-- importance: high, extracted from experience -->
- RULE: {heuristic} (learned {date}: {source_context})

## Detailed Notes Index
<!-- Pointers to topic files, loaded on demand -->
- [Weekly W{NN}](memory/weekly/{YYYY}-W{NN}.md) — {summary}
- [Monthly {Month}](memory/monthly/{YYYY-MM}.md) — {summary}
```

## Important Rules

- **NEVER delete original daily logs** — always move to archive
- **NEVER remove Key Facts** — these are permanent
- **ALWAYS include source dates** on heuristics and decisions
- **ALWAYS keep MEMORY.md under 200 lines** — use the Detailed Notes Index for overflow
- **The archive is always searchable** via Grep — agents can find old information
- **Run master-gpt-prompter principles** when writing summaries — be precise, use domain vocabulary
