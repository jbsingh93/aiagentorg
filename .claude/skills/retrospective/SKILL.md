---
name: retrospective
description: "Conduct a periodic retrospective: review measured outcomes, identify patterns, extract learnings, adjust strategy. Run by CEO weekly or monthly."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[weekly|monthly] (default: weekly)"
---

# Retrospective — Outcome Review & Strategic Adjustment

This skill conducts a periodic review of measured outcomes, identifies patterns across the org, extracts learnings, and proposes strategic adjustments. It closes the double-loop: not just adjusting actions, but adjusting goals and strategy themselves.

## When to Run

- Weekly: review the past 7 days of outcomes and activity
- Monthly: deeper review of the past 30 days, strategic adjustments
- Triggered by CEO heartbeat when `retrospective_frequency` interval is reached
- Manually via `/retrospective` by board or CEO

## Pre-flight

1. Determine period: `$ARGUMENTS` = "weekly" or "monthly" (default: weekly)
2. Calculate date range: today minus 7 days (weekly) or 30 days (monthly)
3. Read `org/config.md` for `retrospective_frequency` setting
4. Check the last retrospective file to avoid duplicating work

## Step 1: Gather Outcome Data

1. Read ALL outcome records from `org/outcomes/` created within the period
2. Read ALL initiative files from `org/initiatives/` — extract current KR progress
3. Read ALL completed tasks (from `org/agents/*/tasks/done/`) completed within the period
4. Read budget spending for the period from `org/budgets/spending-log.md`
5. Count tasks: completed, blocked, still active
6. Count agent invocations from activity streams

## Step 2: Analyze Patterns

For each initiative:
- Calculate progress: how much closer are we to each key result?
- Compare current pace vs target deadline — are we on track?
- Identify the top contributing tasks and agents

Across the org:
- Which departments are most productive?
- Which agents are consistently delivering vs struggling?
- Are there recurring blockers or failure patterns?
- Is budget being spent efficiently (cost per completed task)?

## Step 3: Identify What Worked and What Didn't

**What worked:**
- Tasks that achieved or exceeded their acceptance criteria
- Approaches that produced measurable positive outcomes
- Communication patterns that reduced coordination overhead

**What didn't work:**
- Tasks that were completed but didn't move KRs
- Approaches that consumed budget without measurable results
- Bottlenecks that delayed work chains

## Step 4: Extract Strategic Adjustments

Based on the analysis, propose:
- **Continue:** Approaches that are working — double down
- **Stop:** Approaches that aren't producing results — cut losses
- **Start:** New approaches suggested by the data
- **Adjust:** Existing plans that need course correction

## Step 5: Write Retrospective File

Write to `org/retrospectives/retro-{YYYY-WNN}.md` (weekly) or `retro-{YYYY-MM}.md` (monthly):

```markdown
---
id: retro-{YYYY-WNN or YYYY-MM}
period: {start_date} to {end_date}
type: {weekly|monthly}
conducted_by: {agent or board}
created: {YYYY-MM-DD}
---

# {Weekly|Monthly} Retrospective — {period description}

## Executive Summary
{2-3 sentence overview of the period}

## Initiative Progress

| Initiative | KR | Target | Current | Progress | Status |
|-----------|-----|--------|---------|----------|--------|
| {name} | {kr description} | {target} | {current} | {%} | {on-track|at-risk|behind|achieved} |

## Outcomes Measured This Period
- {outcome-id}: {summary} ({confidence})

## What Worked
- {success_1}
- {success_2}

## What Didn't Work
- {failure_1}
- {failure_2}

## Patterns Detected
- {pattern_1}
- {pattern_2}

## Strategic Adjustments
- **Continue:** {what to keep doing}
- **Stop:** {what to stop doing}
- **Start:** {new approaches to try}
- **Adjust:** {course corrections}

## Learnings Extracted
{List of heuristics added to agent MEMORY.md files}

## Budget Efficiency
- Total spent this period: ${amount}
- Tasks completed: {N}
- Cost per completed task: ${amount/N}
- Budget utilization: {spent/allocated %}

## Next Period Priorities
1. {priority_1}
2. {priority_2}
3. {priority_3}
```

## Step 6: Update Agent Memories

For each learning extracted:
1. Determine which agent benefits from this learning
2. Add to their MEMORY.md under Process Heuristics
3. Include the retrospective ID as source reference

## Step 7: Update Initiative Status

For each initiative reviewed:
1. Update the overall status based on KR progress
2. If behind: flag for CEO attention in the next heartbeat
3. If achieved: mark as complete, celebrate in thread

## Configuration

In `org/config.md`:
```yaml
retrospective_frequency: weekly    # weekly | biweekly | monthly
outcome_tracking: true             # enable/disable the outcome system
```
