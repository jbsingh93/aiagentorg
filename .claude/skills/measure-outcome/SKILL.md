---
name: measure-outcome
description: "Record a measured outcome for a completed task or initiative key result. Creates an outcome record in org/outcomes/ linking the measurement to tasks and initiatives. Closes the feedback loop."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "<task-id or initiative-id>"
---

# Measure Outcome — Record Real-World Results

This skill records measured outcomes for completed tasks and initiative key results. It creates structured outcome records that feed back into the planning cycle.

## Why This Matters

Without outcome measurement, the org optimizes for task completion, not goal achievement. A "done" task that didn't achieve its goal is a failed investment. Outcome records close the feedback loop: Plan → Execute → Measure → Learn → Plan better.

## Pre-flight

1. Read `$ARGUMENTS` to get the task ID or initiative ID
2. If task ID: read the task file from `org/agents/*/tasks/done/{task-id}.md`
3. If initiative ID: read the initiative from `org/initiatives/{initiative-id}.md`
4. Verify the task is in `done` status (cannot measure incomplete work)
5. Create `org/outcomes/` directory if it doesn't exist

## Step 1: Gather Measurement Data

Ask or determine:
- **What was the goal?** (from task acceptance_criteria or initiative key_result)
- **What was the baseline?** (what was the state before the task)
- **What is the current state?** (measured value now)
- **How was this measured?** (data source, method, tool)
- **What is the confidence?** high (objective data), medium (proxy metric), low (subjective assessment)

For internal metrics (file counts, budget utilization), measure automatically:
- Count files in a directory: `find org/content/published/ -name "*.md" | wc -l`
- Budget spent: read from `org/budgets/overview.md`
- Tasks completed: count files in `org/agents/*/tasks/done/`

For external metrics, check if a connector exists:
- Web traffic → Google Analytics connector
- Revenue → Shopify/Stripe connector
- If no connector exists, note that manual measurement is needed

## Step 2: Create Outcome Record

Write to `org/outcomes/outcome-{YYYYMMDD}-{NNN}.md`:

```markdown
---
id: outcome-{YYYYMMDD}-{NNN}
initiative: {initiative-id}
key_result: "{key result description}"
task_ids:
  - {task-id-1}
  - {task-id-2}
measured_by: {agent-name or board}
measured_on: {YYYY-MM-DD}
measurement_method: "{description of how measured}"
confidence: {high|medium|low}
---

## Measurement

- **Metric:** {what was measured}
- **Baseline:** {starting value} ({date})
- **Target:** {goal value}
- **Actual:** {measured value}
- **Progress:** {percentage toward target}
- **Confidence:** {high|medium|low} ({reason for confidence level})

## Analysis

{What do the numbers tell us? Why did we hit/miss the target?
What factors contributed to the result?}

## Learnings

- {Learning 1 — what to repeat or avoid}
- {Learning 2}

## Status

- **On track:** {Yes/No/Partially}
- **Projected completion:** {date if ongoing}
- **Risk factors:** {what could derail progress}
```

## Step 3: Update Task File

Add outcome metadata to the completed task's frontmatter:

```yaml
status: measured
measured: {YYYY-MM-DD}
outcome_record: outcome-{YYYYMMDD}-{NNN}
outcome_summary: "{one-line summary of result}"
```

## Step 4: Update Initiative Key Result (if applicable)

If the outcome relates to an initiative key result, update the initiative file:

```yaml
key_results:
  - id: kr-01
    description: "{description}"
    baseline: {value}
    target: {value}
    current: {measured_value}     # UPDATE this
    last_measured: {YYYY-MM-DD}   # UPDATE this
    status: {on-track|at-risk|behind|achieved}  # UPDATE this
    outcome_records:
      - outcome-{YYYYMMDD}-{NNN}  # APPEND this
```

## Step 5: Extract Learnings to Agent Memory

If the outcome reveals a reusable insight, add it to the measuring agent's MEMORY.md under Process Heuristics:

```markdown
## Process Heuristics
- RULE: {heuristic} (learned {date}: {brief context from outcome record})
```

Follow the ExpeL pattern: contrast what worked vs what didn't, extract the discriminative rule.

## Confidence Levels

| Level | Meaning | Examples |
|-------|---------|---------|
| **high** | Objective, independently verifiable data | Analytics traffic count, file count, revenue number |
| **medium** | Proxy metrics or partially objective data | Estimated engagement, sampled quality score |
| **low** | Subjective assessment or expert judgment | Quality rating by reviewer, strategic alignment score |

## Who Should Measure

- **Task assigner** (manager who delegated) measures task outcomes
- **CEO** measures initiative-level outcomes
- **Automated** for internal metrics (file counts, budget, task throughput)
- **Board** for strategic outcomes and org-wide KPIs
