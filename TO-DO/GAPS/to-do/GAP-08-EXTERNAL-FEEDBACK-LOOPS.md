# GAP-08: No External Feedback Loops — Outcome Tracking & Closed-Loop Learning

**Date:** 2026-04-02
**Status:** Research complete, ready for implementation
**Priority:** HIGH — Without this, the org optimizes for task completion, not goal achievement
**Dependencies:** Task lifecycle (exists), initiative files (exist), report skill (exists)
**Estimated Effort:** Phase 1: 4-6 hours, Phase 2: 6-10 hours, Phase 3: future

---

## 1. The Problem

OrgAgent's task lifecycle is **open-loop**: `backlog → active → done`. Tasks terminate at "done" with NO measurement of whether they achieved their real-world goals.

1. **No outcome tracking:** When a marketing campaign is "done," no one measures whether it drove traffic
2. **No customer/user feedback integration:** The org produces output but has no way to measure quality against reality
3. **No A/B testing or performance metrics:** No mechanism to compare approaches
4. **No learning from outcomes:** Agents optimize for "task completed" not "task achieved its goal"
5. **No feedback loop from outcomes back to planning:** The CEO plans strategy based on alignment and inbox, not on measured results from previous work
6. **Initiative Key Results are aspirational text** — no baselines, no targets, no current values, no measurement dates

### Current State

- Task files have: id, title, priority, status, assigned_to, assigned_by, initiative, deadline, acceptance_criteria
- Initiative files have: id, name, status, owner, objectives, key_results — but key_results are prose text with no measurement framework
- Reports (`/report` skill) gather task data, activity logs, budget, and threads — but no outcome data
- The CEO's heartbeat includes "review initiative progress" but has nothing to measure against
- No `org/outcomes/` or `org/metrics/` directory exists
- No concept of "measured" or "evaluated" task status

---

## 2. Research Findings

### 2.1 The Agent Loop — OODA + Learning

**Source:** Multiple (Fast.io, Moveworks, Atlan)

The industry-standard agent decision cycle is **Observe-Orient-Decide-Act-Learn (OODA+L)**:

1. **Observe:** Detect events and gather data
2. **Orient:** Analyze context, assess situation
3. **Decide:** Choose action based on analysis
4. **Act:** Execute the chosen action
5. **Learn:** Measure outcomes, extract lessons, feed back into future decisions

OrgAgent implements phases 1-4 via its heartbeat cycle. **Phase 5 (Learn) is completely missing.** This is the gap.

### 2.2 Meta's Ranking Engineer Agent (REA)

**Source:** [Meta Engineering Blog — REA](https://engineering.fb.com/2025/12/16/production-engineering/ranking-engineer-agent-rea/)

Meta's REA provides the production gold standard for closed-loop AI agent systems:

- **Centralized experiment-outcome database:** "Persistent memory accumulates knowledge across the agent's full operation history"
- **Hypothesis generator draws on outcome insights:** The agent proposes changes based on measured results from previous experiments
- **Feedback-driven iteration:** After each experiment, results are stored and inform the next experiment's design
- **Confidence scoring:** Each outcome is assigned a confidence level based on statistical significance

**OrgAgent mapping:** Create `org/outcomes/` as the centralized outcome database. After each initiative milestone, agents record measured outcomes. The CEO's planning draws on this data.

### 2.3 OKR Tracking in Automated Systems

**Source:** Multiple (Workboard, Lattice, Anthropic internal practices)

The OKR (Objectives and Key Results) framework provides the structure for measurable goals:

**Current OrgAgent initiative format (from TO-DO/10-FILE-FORMAT-SPECIFICATIONS.md):**
```yaml
key_results:
  - "Increase organic traffic by 30%"
  - "Publish 20 SEO-optimized articles"
  - "Achieve top-10 Google ranking for 5 target keywords"
```

**Enhanced format with measurement:**
```yaml
key_results:
  - description: "Increase organic traffic by 30%"
    baseline: 1000          # visits/month at start
    target: 1300            # 30% increase
    current: 0              # updated by outcome records
    unit: "visits/month"
    measurement_method: "Google Analytics via connector"
    last_measured: null
    confidence: null
  - description: "Publish 20 SEO-optimized articles"
    baseline: 0
    target: 20
    current: 0
    unit: "articles"
    measurement_method: "count files in org/content/published/"
    last_measured: null
    confidence: "high"      # easy to measure objectively
```

### 2.4 Feedback-Driven Agent Improvement

**Source:** [arXiv — ExpeL: LLM Agents Are Experiential Learners](https://arxiv.org/abs/2308.10144)

ExpeL contrasts successful and failed trajectories, extracting discriminative "rules of thumb":

- After a task succeeds: extract what approach worked and why
- After a task fails: extract what went wrong and what to avoid
- Store rules in memory for future use
- **No parameter updates needed** — works with API-based models like Claude

**OrgAgent mapping:** When a task outcome is measured (positive or negative), the responsible agent extracts a learning and adds it to MEMORY.md under "Process Heuristics."

Example:
```markdown
## Process Heuristics
- RULE: SEO articles targeting long-tail keywords (4+ words) achieve first-page ranking 3x faster than short-tail (learned 2026-04-15: measured organic traffic after 30 days, long-tail articles averaged position 7 vs short-tail position 23)
- RULE: Social media posts with Danish cultural references get 2x engagement (learned 2026-04-20: A/B test showed 4.2% vs 1.8% engagement rate)
```

### 2.5 Closed-Loop AI Systems

**Source:** Multiple (OODA loop implementations, reinforcement learning from human feedback)

Key patterns:

**Belief Decay:** Confidence scores decay over time. An outcome measured 6 months ago is less trustworthy than one measured last week. Formula: `effective_confidence = original_confidence * e^(-0.1 * months_since_measurement)`.

**Retrospective Cycles:** Periodically (weekly or monthly), the CEO or relevant manager reviews all measured outcomes, identifies patterns, and updates strategy. This is the "double-loop learning" pattern — not just adjusting actions, but adjusting the goals and strategy themselves.

**Outcome Attribution:** When multiple tasks contribute to a single key result, attribution is complex. Simple heuristic: credit the task whose completion most closely preceded the measured improvement.

### 2.6 Analytics and Metrics for AI Organisations

**Source:** [Unite.AI — Autonomous Agent KPI Dashboard](https://www.unite.ai/)

Metrics an AI org should track:

**Operational Metrics (already tracked by OrgAgent):**
- Task completion rate
- Budget utilization
- Agent uptime / heartbeat participation
- Communication volume

**Outcome Metrics (NOT tracked — this is the gap):**
- Initiative progress (% of key results achieved)
- Task outcome quality (did the deliverable achieve its goal?)
- Time-to-value (days from task creation to measured outcome)
- Learning rate (how many heuristics extracted per period?)
- Strategy accuracy (how often does the CEO's plan produce desired outcomes?)

---

## 3. New Concepts

### 3.1 Outcome Records (`org/outcomes/`)

A new directory containing structured measurements linking completed tasks to initiative key results:

```markdown
---
id: outcome-20260415-001
initiative: initiative-q2-organic-growth
key_result: "Increase organic traffic by 30%"
task_ids:
  - task-20260401-003
  - task-20260408-007
measured_by: marketing-manager
measured_on: 2026-04-15
measurement_method: "Google Analytics via connector"
---

## Measurement

- **Metric:** Monthly organic visits
- **Baseline:** 1,000 (2026-04-01)
- **Target:** 1,300
- **Actual:** 1,150
- **Progress:** 50% of target (150 of 300 needed visits gained)
- **Confidence:** high (objective measurement from analytics)

## Analysis

The SEO articles published in Week 14-15 contributed approximately 120 of the 150 new visits. Social media campaigns contributed ~30. Long-tail keyword articles outperformed short-tail by 3x.

## Learnings

- Long-tail keywords (4+ words) achieve first-page ranking much faster
- Danish-language content performs better than English for the target audience
- Publishing frequency matters more than individual article quality for traffic growth

## Status

- **On track:** Yes, if current pace continues
- **Projected completion:** 2026-05-15
- **Risk factors:** Google algorithm update could impact rankings
```

### 3.2 Enhanced Initiative Key Results

Transform initiative key_results from aspirational text to measurable targets:

```yaml
key_results:
  - id: kr-01
    description: "Increase organic traffic by 30%"
    baseline: 1000
    target: 1300
    current: 1150
    unit: "visits/month"
    measurement_method: "Google Analytics via connector"
    measurement_frequency: "weekly"
    last_measured: 2026-04-15
    status: on-track        # on-track | at-risk | behind | achieved | abandoned
    confidence: high
    outcome_records:
      - outcome-20260415-001
```

### 3.3 Retrospective Files (`org/retrospectives/`)

Periodic analysis documents that synthesize outcomes into strategic insights:

```markdown
---
id: retro-2026-W15
period: 2026-04-07 to 2026-04-13
conducted_by: ceo
participants:
  - ceo
  - marketing-manager
---

# Weekly Retrospective — Week 15

## What Worked
- SEO article production pace exceeded target (5/week vs 4/week target)
- Long-tail keyword strategy validated by traffic data

## What Didn't Work
- Social media engagement below expectations (1.8% vs 3% target)
- Instagram posting time optimization not yet showing results

## Patterns Detected
- Content quality inversely correlates with production speed — articles written in 2+ heartbeat cycles have 40% more engagement than single-cycle articles
- Danish cultural references significantly boost engagement

## Strategic Adjustments
- Shift social media budget from Instagram to LinkedIn for B2B segment
- Slow down article production pace to focus on quality
- Double down on long-tail keyword strategy

## Learnings Extracted (added to agent memories)
- marketing-manager: "Quality > quantity for SEO articles" (MEMORY.md updated)
- seo-agent: "Long-tail keywords 3x more effective" (MEMORY.md updated)
```

---

## 4. Task Lifecycle Extension

Current: `backlog → active → done`

Proposed: `backlog → active → done → measured → closed`

| Status | Meaning | Location |
|---|---|---|
| `backlog` | Waiting to be started | `tasks/backlog/` |
| `active` | Currently being worked on | `tasks/active/` |
| `done` | Deliverable completed | `tasks/done/` |
| `measured` | Outcome measured, learning extracted | `tasks/done/` (field change only) |
| `closed` | Fully processed, archived | `tasks/done/` (field change only) |

The `measured` and `closed` statuses are field changes in the task frontmatter, NOT directory moves. The task stays in `done/` but its frontmatter tracks the measurement lifecycle:

```yaml
status: measured
completed: 2026-04-10
measured: 2026-04-15
outcome_record: outcome-20260415-001
outcome_summary: "50% progress toward traffic target. Long-tail strategy validated."
```

---

## 5. `/retrospective` Skill

A new skill that guides periodic outcome review:

**Trigger:** Board requests (`/retrospective`) or CEO heartbeat (weekly/monthly based on config).

**Process:**
1. Read all outcome records from the period
2. Read initiative progress (current vs target for each KR)
3. Identify patterns: what approaches worked? what failed?
4. Draft strategic adjustments
5. Extract learnings and update relevant agent MEMORY.md files
6. Write retrospective file to `org/retrospectives/`
7. Update initiative status (on-track / at-risk / behind / achieved)

---

## 6. Who Measures Outcomes?

**Three options (Decision 72):**

| Option | Who Measures | Pros | Cons |
|---|---|---|---|
| A: Task assignee | The agent who completed the task | Knows the work best | May lack objectivity, self-evaluation bias |
| B: Task assigner | The manager who delegated | More objective, sees broader context | May not understand implementation details |
| C: Dedicated analyst | A "metrics agent" hired by CAO | Most objective, specialized | Adds org overhead, another agent to pay for |

**Recommended:** Option B (task assigner) for most tasks. The manager who delegated evaluates the outcome. For strategic initiatives, the CEO measures. For operational metrics that can be automated (file counts, connector data), automate the measurement.

---

## 7. Measurement Methods

Outcomes need data. Where does it come from?

### 7.1 Internal Metrics (Automatic)

Measurable from the filesystem itself:
- Count of files in a directory (articles published, tasks completed)
- Budget spent vs allocated
- Communication volume (thread messages per period)
- Task throughput (tasks completed per period)
- Agent uptime (heartbeat participation rate)

### 7.2 External Metrics (Via Connectors)

Require external service connectors (per GAP-04/TO-DO/21):
- Web traffic (Google Analytics connector)
- Social media engagement (platform API connectors)
- Revenue/orders (Shopify/Stripe connector)
- Email metrics (email service connector)
- Customer satisfaction (survey tool connector)

### 7.3 Subjective Assessment (Human/Agent Judgment)

When objective measurement isn't possible:
- Quality assessment by reviewing agent
- Customer feedback interpretation
- Strategic alignment evaluation

Each outcome record includes `confidence` field: `high` (objective measurement), `medium` (proxy metrics), `low` (subjective assessment).

---

## 8. CEO Heartbeat Integration

Add to the CEO's heartbeat checklist:

```markdown
## Step 8: Review Outcomes and Adjust Strategy

1. Check `org/outcomes/` for new outcome records since last heartbeat
2. For each initiative:
   - Compare current KR values against targets
   - Assess if the initiative is on-track, at-risk, or behind
   - If behind: identify root cause and adjust strategy
3. If weekly retrospective is due (check last retro date):
   - Conduct retrospective following the `/retrospective` skill
   - Update initiative priorities based on measured outcomes
4. Update MEMORY.md with new strategic insights from outcome data
```

---

## 9. Configuration

Add to `org/config.md`:

```yaml
outcome_tracking: true               # Enable/disable outcome tracking
retrospective_frequency: weekly       # weekly | biweekly | monthly
measurement_reminder_days: 7          # Days after task completion to remind for measurement
auto_measure_internal: true           # Automatically measure internal metrics (file counts, etc.)
```

---

## 10. New Directory Structure

```
org/
  outcomes/                          # NEW: Outcome measurement records
    outcome-YYYYMMDD-NNN.md          # Individual outcome measurements
  retrospectives/                    # NEW: Periodic review documents
    retro-YYYY-WNN.md               # Weekly retrospectives
    retro-YYYY-MM.md                # Monthly retrospectives
  initiatives/                       # EXISTING: Enhanced with measurable KRs
    initiative-*.md                  # Updated format with baseline/target/current
```

---

## 11. Implementation Plan

### Phase 1: Core Outcome Tracking (4-6 hours)

1. Create `org/outcomes/` directory and outcome record file format spec
2. Enhance initiative key_results format with baseline/target/current/measurement fields
3. Extend task frontmatter with `measured`, `outcome_record`, `outcome_summary` fields
4. Create `/measure-outcome` skill that guides agents through recording an outcome
5. Add outcome review step to CEO heartbeat checklist
6. Update system-reference.md with outcome tracking documentation

### Phase 2: Retrospective & Learning (6-10 hours)

7. Create `org/retrospectives/` directory and retrospective file format spec
8. Create `/retrospective` skill with full review workflow
9. Add retrospective scheduling to CEO heartbeat (check if weekly retro is due)
10. Implement learning extraction: outcomes → heuristics in MEMORY.md (ExpeL pattern)
11. Enhance `/report` skill to include outcome data alongside task data
12. Add outcome metrics to GUI dashboard (initiative progress visualization)
13. Update initiative file format spec in TO-DO/10-FILE-FORMAT-SPECIFICATIONS.md

### Phase 3: Advanced (Future)

14. Build internal metric auto-measurement (file counts, budget utilization, throughput)
15. Integrate with external connectors for automated metric collection
16. Add belief decay to outcome records (old measurements lose confidence)
17. Implement A/B testing framework for comparing approaches
18. Add outcome attribution model (which tasks contributed most to KR progress)
19. Build `org/metrics/` dashboard with historical trend data

---

## 12. Architecture Decisions

### Decision 72: Task Assigner Measures Outcomes
**Decision:** The manager who delegated a task is responsible for measuring its outcome. For strategic initiatives, the CEO measures. Automated internal metrics are collected automatically.
**Reasoning:** The assigner has the broader context to evaluate whether the task achieved its goal, not just whether it was completed. Self-evaluation (assignee measures) introduces bias. A dedicated metrics agent adds overhead for most orgs.

### Decision 73: Extended Task Status (done → measured → closed)
**Decision:** Add `measured` and `closed` statuses to the task lifecycle. These are frontmatter field changes, not directory moves.
**Reasoning:** The task stays in `done/` for easy querying. The status field tracks whether the outcome has been measured and learnings extracted. This preserves backwards compatibility while closing the feedback loop.

### Decision 74: Outcome Records as Separate Files
**Decision:** Outcome measurements are stored as separate files in `org/outcomes/`, not embedded in task files. Each outcome record references the task(s) and initiative it relates to.
**Reasoning:** A single outcome often spans multiple tasks. Keeping outcomes separate allows for cross-task analysis, initiative-level aggregation, and retrospective review without parsing individual task files.

### Decision 75: Retrospectives as CEO Heartbeat Responsibility
**Decision:** The CEO conducts retrospectives as part of their heartbeat cycle when the configured frequency triggers (weekly/monthly). The `/retrospective` skill guides the process.
**Reasoning:** Retrospectives are strategic analysis — the CEO's domain. They synthesize outcomes from across the org into strategic insights and adjustments. Managers contribute data; the CEO synthesizes it.

### Decision 76: Confidence Scoring on All Outcomes
**Decision:** Every outcome record includes a `confidence` field: high (objective measurement), medium (proxy metrics), low (subjective assessment). Confidence decays over time.
**Reasoning:** Not all measurements are equally trustworthy. A Google Analytics traffic count is high-confidence. A manager's subjective quality assessment is low-confidence. Decision-making should weight high-confidence outcomes more heavily.

---

## 13. Sources

- [Meta: Ranking Engineer Agent (REA)](https://engineering.fb.com/2025/12/16/production-engineering/ranking-engineer-agent-rea/)
- [ExpeL: LLM Agents Are Experiential Learners (arXiv)](https://arxiv.org/abs/2308.10144)
- [Event-Driven AI Agent Architecture (Fast.io)](https://fast.io/resources/ai-agent-event-driven-architecture/)
- [Ambient Agent Triggers (Moveworks)](https://www.moveworks.com/us/en/resources/blog/webhooks-triggers-for-ambient-agents)
- [OODA Loop for AI Agents (Medium)](https://medium.com/@richardhightower/ooda-loop-ai-agents)
- [AI Agent Analytics Dashboard (Unite.AI)](https://www.unite.ai/)
- [OKR Tracking Best Practices (Workboard)](https://www.workboard.com/okr-tracking/)
