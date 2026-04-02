# External Feedback Loops — Research & Specification

**Date:** 2026-04-02
**Purpose:** Complete research into closing the gap between "task completed" and "task achieved its goal." This document covers outcome tracking, feedback integration, retrospective learning, OKR/KPI frameworks, and closed-loop agent architectures — all mapped to OrgAgent's filesystem-based, markdown-driven architecture.

---

## Table of Contents

1. [The Problem](#1-the-problem)
2. [Research Area 1: AI Agent Outcome Tracking & Feedback Loops](#2-research-area-1-ai-agent-outcome-tracking--feedback-loops)
3. [Research Area 2: OKR and Goal Tracking in Automated Systems](#3-research-area-2-okr-and-goal-tracking-in-automated-systems)
4. [Research Area 3: Feedback-Driven Agent Improvement](#4-research-area-3-feedback-driven-agent-improvement)
5. [Research Area 4: Analytics and Metrics for AI Organisations](#5-research-area-4-analytics-and-metrics-for-ai-organisations)
6. [Research Area 5: Closed-Loop AI Systems](#6-research-area-5-closed-loop-ai-systems)
7. [Codebase Analysis: Current State & Integration Points](#7-codebase-analysis-current-state--integration-points)
8. [Synthesis: The OrgAgent Feedback Loop Architecture](#8-synthesis-the-orgagent-feedback-loop-architecture)
9. [Implementation Proposals](#9-implementation-proposals)
10. [Trade-offs & Decisions Required](#10-trade-offs--decisions-required)

---

## 1. The Problem

### Current State

OrgAgent tasks follow a linear lifecycle:

```
backlog → active → done
```

"Done" is the terminal state. The task file gets a `completed` timestamp and a `Results` section, then it sits in `tasks/done/` forever. There is:

- **No mechanism to verify whether a completed task achieved its intended GOAL**
- **No customer/stakeholder feedback integration** — deliverables are produced but never validated against real-world impact
- **No A/B testing or experimentation framework** — agents cannot compare alternative approaches
- **No metrics collection** — "did the marketing campaign actually drive traffic?" is unanswerable
- **No outcome-to-planning feedback loop** — the CEO's next strategy cycle gets no signal about whether previous strategies worked
- **No retrospective learning** — agents optimize for "task completed" (output) not "goal achieved" (outcome)

### Why This Matters

Without feedback loops, the organisation operates in open-loop mode: it produces outputs but never observes whether those outputs achieve their purpose. This is the equivalent of a company that ships products but never checks sales numbers, customer satisfaction, or market share. Over time, open-loop systems drift — they optimize for the wrong things, repeat mistakes, and cannot learn.

---

## 2. Research Area 1: AI Agent Outcome Tracking & Feedback Loops

### Key Finding: The Agent Loop Is the Core Architecture

The dominant pattern in 2025-2026 agentic AI is the **Agent Loop** — a repeating cycle where agents perceive, reason, decide, act, observe outcomes, learn, and iterate. This is fundamentally different from OrgAgent's current linear task execution.

**The seven-component agent loop architecture** (Gleecus, 2026):
1. **Perception Module** — collects real-time data from APIs, sensors, databases
2. **Reasoning Engine** — applies chain-of-thought and planning algorithms
3. **Decision Policy** — selects optimal actions using heuristics or RL
4. **Action Tools** — executes decisions via external system interfaces
5. **Memory Store** — combines short-term context with long-term storage
6. **Feedback & Reflection** — captures outcomes and self-critique signals
7. **Orchestrator** — manages loop flow, error handling, and safety guardrails

The core cycle: **Perception -> Reasoning -> Decision -> Action -> Observation -> Learning -> Iteration**

**Key insight for OrgAgent:** The heartbeat cycle already provides phases 1-4 (perception through action). What is entirely missing is phases 5-7 (observation of outcomes, learning from them, and iterating strategy).

### Key Finding: Goal Fulfillment as Primary Metric

Goal Fulfillment is emerging as the primary KPI for production AI agents — measuring whether the agent's actions achieved the intended business outcome, not merely whether the task was completed. This aligns perfectly with OrgAgent's initiative-based architecture where tasks trace back to strategic objectives with key results.

### Key Finding: JPMorgan's LOXM as Production Example

JPMorgan's LOXM trading agent demonstrates a production-grade outcome feedback loop: it executes trades, measures P&L outcomes, and feeds those results back into its decision policy at millisecond speeds. The key architectural pattern is: **action -> outcome measurement -> policy update -> improved action.**

### OrgAgent Mapping

| Agent Loop Component | OrgAgent Equivalent | Gap |
|---------------------|---------------------|-----|
| Perception | Heartbeat inbox processing, thread reading | None |
| Reasoning | Agent LLM reasoning + current-state.md | None |
| Decision | MEMORY.md reasoning trace, Active Decision in current-state | None |
| Action | Task execution, deliverable creation | None |
| Observation | **MISSING** | No outcome measurement |
| Learning | **MISSING** | No retrospective analysis |
| Iteration | **MISSING** | No feedback-to-planning loop |

### Sources
- [How Agent Loop Works: The Complete 2026 Guide to Adaptive AI Agents](https://gleecus.com/blogs/agent-loop-adaptive-ai-agents-complete-guide-2026/)
- [The Agent Loop: How AI Thinks, Decides, and Learns From Action](https://www.tredence.com/blog/ai-agent-loop)
- [2026 AI Outlook: How Agents, Context, and Governance Will Shape Real-World AI](https://odsc.medium.com/2026-ai-outlook-how-agents-context-and-governance-will-shape-real-world-ai-0f76d2c716f6)
- [AI Agent Evaluations: The Complete 2025-2026 Guide](https://www.xugj520.cn/en/archives/ai-agent-evaluations-guide-2025.html)
- [AI Evaluation Metrics 2026: Tested by Conversation Experts](https://masterofcode.com/blog/ai-agent-evaluation)

---

## 3. Research Area 2: OKR and Goal Tracking in Automated Systems

### Key Finding: OKR Structure Already Exists in OrgAgent

The initiative file format (`org/initiatives/*.md`) already uses an OKR-like structure:

```yaml
---
id: q2-marketing-growth
title: Q2 Marketing Growth Initiative
owner: ceo
status: active
created: 2026-03-31
target_date: 2026-06-30
---
```

With Key Results defined in the body:
```markdown
## Key Results
1. Organic traffic: 10,000 → 13,000 monthly visitors
2. Social media followers: 0 → 1,000 across 3 platforms
3. Content published: 24 blog posts (2/week)
4. SEO keywords ranking top 10: 15 → 30
```

**The gap:** These Key Results are stated but never measured. There is no `current_value` field, no `measurement_date`, no `progress_percentage`. They are aspirational text, not tracked metrics.

### Key Finding: AI-Powered OKR Tracking Is Mature

Platforms like Brev.io, Tability, and Gtmhub demonstrate that automated OKR tracking with AI agents is production-ready in 2026. Key capabilities:

1. **Automated data collection** — AI agents pull progress data from multiple sources (analytics platforms, CRMs, project management tools) without manual check-ins
2. **Real-time progress tracking** — continuous monitoring of key results with instant updates
3. **Early warning systems** — AI flags at-risk objectives before deadlines, detecting stalling trends
4. **AI-powered nudges** — automated reminders and suggestions when key results fall behind
5. **Contextual understanding** — agents analyze unstructured commentary and status updates to assess real progress

### Key Finding: Relevance AI's OKR Agent Architecture

Relevance AI provides a template for an OKR tracking agent that:
- Views organisational goals in real-time
- Provides progress tracking with early warning systems
- Monitors key results continuously
- Flags potential roadblocks before they become issues

This maps directly to a potential "Metrics Agent" or "Analytics Agent" in OrgAgent.

### OrgAgent Mapping: Initiative File Enhancement

**Current initiative format -> Enhanced with measurable KRs:**

```markdown
---
id: q2-marketing-growth
title: Q2 Marketing Growth Initiative
owner: ceo
status: active
created: 2026-03-31
target_date: 2026-06-30
review_frequency: weekly
last_review: 2026-04-01
overall_progress: 35
health: on-track
---

# Q2 Marketing Growth Initiative

## Objective
Increase organic website traffic by 30% and establish social media presence
on 3 platforms by end of Q2 2026.

## Key Results

### KR-1: Organic Traffic Growth
- baseline: 10000
- target: 13000
- current: 11200
- unit: monthly_visitors
- measurement_source: web-analytics
- last_measured: 2026-04-01
- progress: 40%
- trend: improving

### KR-2: Social Media Followers
- baseline: 0
- target: 1000
- current: 250
- unit: followers
- measurement_source: social-media-dashboard
- last_measured: 2026-04-01
- progress: 25%
- trend: steady

### KR-3: Content Published
- baseline: 0
- target: 24
- current: 8
- unit: blog_posts
- measurement_source: content-audit
- last_measured: 2026-04-01
- progress: 33%
- trend: on-track

### KR-4: SEO Keyword Rankings
- baseline: 15
- target: 30
- current: 22
- unit: keywords_top_10
- measurement_source: seo-tool
- last_measured: 2026-04-01
- progress: 47%
- trend: improving

## Measurement Log
| Date | KR | Previous | Current | Delta | Source | Measured By |
|------|----|----------|---------|-------|--------|-------------|
| 2026-04-01 | KR-1 | 10500 | 11200 | +700 | web-analytics | seo-agent |
| 2026-04-01 | KR-2 | 150 | 250 | +100 | social-dashboard | social-media-agent |
| 2026-04-01 | KR-3 | 6 | 8 | +2 | content-audit | marketing-manager |
| 2026-04-01 | KR-4 | 18 | 22 | +4 | seo-tool | seo-agent |
```

### Sources
- [OKR Tracking AI Agents - Akira AI / Elixir Claw](https://www.akira.ai/ai-agents/okr-ai-agents)
- [How We Built AI Into OKRs Tool to Turn Goals Into Growth](https://www.okrstool.com/blog/ai-powered-okr-tool)
- [OKR Tracking AI Agents - Relevance AI](https://relevanceai.com/agent-templates-tasks/okr-objectives-and-key-results-tracking-ai-agents)
- [Tability — OKRs that don't suck](https://www.tability.io/)
- [Top AI-Powered OKR Tools for Smarter Goal Tracking 2026](https://aijourn.com/okr-tools-for-smarter-goal/)

---

## 4. Research Area 3: Feedback-Driven Agent Improvement

### Key Finding: Three Memory Types for Learning

The 2025-2026 research consensus identifies three types of long-term memory that enable agent learning:

1. **Episodic Memory** — stores structured records of interactions: timestamps, actions taken, environmental conditions, and outcomes. These become case studies for case-based reasoning that improves over time.
2. **Semantic Memory** — factual knowledge about the domain (what the agent knows). In OrgAgent this is MEMORY.md.
3. **Procedural Memory** — how to do things, skill patterns extracted from experience. In OrgAgent this would be learned best-practices.

**Key insight:** OrgAgent has semantic memory (MEMORY.md) but lacks both episodic memory (structured experience records) and procedural memory (learned best-practices).

### Key Finding: The Reflexion Framework

The Reflexion framework (Shinn et al.) introduces a powerful pattern for LLM agent learning from failures:

**Architecture:**
1. **Actor** — the agent that executes tasks (produces action trajectories)
2. **Evaluator** — assesses trajectory quality through environment signals or self-evaluation
3. **Self-Reflection Module** — verbally reflects on task feedback, analyzing failure patterns and generating constructive guidance

**Dual Memory Architecture:**
- **Short-term memory** — trajectory history with fine-grained execution details
- **Long-term memory** — outputs from the Self-Reflection model (distilled lessons)

**Key mechanism:** "Transforms episodic failures into procedural knowledge, bridging the gap between one-shot generation and genuine learning."

**Structured Reflection Process:** Effective systems separate error identification from solution generation using two distinct LLM calls — one analyzing "what went wrong," another generating "improved solutions based on that analysis."

### Key Finding: Self-Evolving Agent Taxonomy

The comprehensive survey by Gao et al. (2025) identifies what, when, and how agents evolve:

**What evolves:**
| Component | OrgAgent Equivalent | Evolvable? |
|-----------|---------------------|------------|
| Model parameters | Not applicable (we use API models) | No — models are external |
| Prompts | SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md | Yes — via CAO reconfiguration |
| Memory | MEMORY.md | Yes — agents maintain this already |
| Tools | IDENTITY.md tool lists | Yes — via tool request workflow |
| Workflow/Architecture | HEARTBEAT.md checklists, task delegation patterns | Yes — via CEO/CAO restructuring |

**When evolution happens:**
- **Intra-task (within a single execution):** Agent reflects during current-state.md updates — already supported
- **Inter-task (across executions):** Agent learns from previous task outcomes — NOT supported today

**How evolution mechanisms work:**
- **Reward-based:** textual feedback, outcome metrics, task completion signals
- **Imitation/demonstration:** learning from successful trajectories (own or peers')
- **Population-based/evolutionary:** not applicable to single-agent systems

### Key Finding: Zalando's Multi-Stage Post-Mortem Pipeline

Zalando's engineering team developed a production-grade system where LLMs analyze thousands of post-mortems to extract patterns. Key architectural decisions:

1. **Multi-stage LLM pipeline** where each stage specializes in a single objective (summarization, classification, analysis, pattern detection) — more effective than single high-end LLMs
2. **Human curation at each stage** for refining prompts, ensuring accuracy, fostering trust
3. **Pattern detection across incidents** — AI identifies systemic issues from individual post-mortems
4. **Continuous improvement** — each post-mortem becomes a learning opportunity that drives improvement

**OrgAgent application:** A post-mortem/retrospective phase in the heartbeat cycle where completed tasks are evaluated against their intended outcomes, patterns are extracted, and learnings are recorded.

### Key Finding: Meta's Ranking Engineer Agent (REA) — Production Outcome Loop

Meta's REA (March 2026) demonstrates the most sophisticated production feedback loop found in this research:

**Architecture:**
1. **Hypothesis Generator** — synthesizes experiment ideas from historical insights database + ML research agent
2. **Planner** — creates detailed experiment plans with estimated GPU compute costs
3. **Executor** — manages asynchronous job execution with hibernate-and-wake pattern
4. **Experiment Logger** — records outcomes, key metrics, and configurations into a centralized database

**The key feedback loop:** "Persistent memory accumulates knowledge across the agent's full operation history and the hypothesis generator draws on these insights to identify patterns, learn from prior successes and failures, and propose increasingly sophisticated hypotheses for each subsequent round."

**Three-phase exploration framework:**
1. **Validation** — individual hypotheses tested in parallel
2. **Combination** — promising hypotheses combined for synergistic improvements
3. **Exploitation** — most promising candidates optimized aggressively

**Result:** Doubled average model accuracy across six models; enabled three engineers to deliver proposals for eight models.

### Key Finding: Belief Decay Prevents Stale Knowledge

A practical OODA loop implementation uses **belief decay** (confidence scores decay with tau=0.95 per cycle) to prevent stale knowledge from dominating decisions. Old learnings gradually lose influence unless reinforced by new evidence.

### Sources
- [Agent Feedback Loops: From OODA to Self-Reflection](https://tao-hpu.medium.com/agent-feedback-loops-from-ooda-to-self-reflection-92eb9dd204f6)
- [A Survey of Self-Evolving Agents](https://arxiv.org/html/2507.21046v4)
- [Awesome-Self-Evolving-Agents Repository](https://github.com/EvoAgentX/Awesome-Self-Evolving-Agents)
- [ICLR 2026 Workshop on AI with Recursive Self-Improvement](https://openreview.net/pdf?id=OsPQ6zTQXV)
- [Building Self-Improving AI Agents: Techniques in RL and Continual Learning](https://www.technology.org/2026/03/02/self-improving-ai-agents-reinforcement-continual-learning/)
- [7 Tips to Build Self-Improving AI Agents with Feedback Loops](https://datagrid.com/blog/7-tips-build-self-improving-ai-agents-feedback-loops)
- [Ranking Engineer Agent (REA) - Meta Engineering](https://engineering.fb.com/2026/03/17/developer-tools/ranking-engineer-agent-rea-autonomous-ai-system-accelerating-meta-ads-ranking-innovation/)
- [Dead Ends or Data Goldmines? — Zalando Engineering](https://engineering.zalando.com/posts/2025/09/dead-ends-or-data-goldmines-ai-powered-postmortem-analysis.html)
- [WHERE LLM AGENTS FAIL AND HOW THEY CAN LEARN FROM FAILURES](https://arxiv.org/pdf/2509.25370)
- [The OODA Loop Pattern for Autonomous AI Agents](https://dev.to/yedanyagamiaicmd/the-ooda-loop-pattern-for-autonomous-ai-agents-how-i-built-a-self-improving-system-2ap3)
- [Memory in the Age of AI Agents](https://arxiv.org/abs/2512.13564)
- [Build agents to learn from experiences using Amazon Bedrock AgentCore episodic memory](https://aws.amazon.com/blogs/machine-learning/build-agents-to-learn-from-experiences-using-amazon-bedrock-agentcore-episodic-memory/)
- [Self-Learning AI Agents - Beam AI](https://beam.ai/agentic-insights/self-learning-ai-agents-transforming-automation-with-continuous-improvement)

---

## 5. Research Area 4: Analytics and Metrics for AI Organisations

### Key Finding: The KPI Framework for AI Agent Organisations

Multiple sources converge on a six-category KPI framework:

#### Category 1: Task Completion & Accuracy
| Metric | Definition | OrgAgent Measurement |
|--------|-----------|---------------------|
| Completion Rate | % of tasks finished without manual intervention | `tasks/done/` count / total tasks assigned |
| Error Rate | Frequency of inaccuracies in automated outputs | Requires outcome validation |
| Compliance Adherence | Actions follow rules and regulations | Hook enforcement already covers this |

#### Category 2: Speed & Responsiveness
| Metric | Definition | OrgAgent Measurement |
|--------|-----------|---------------------|
| Task Execution Time | Average duration from `started` to `completed` | Already in task frontmatter |
| Response Latency | Speed of agent reaction to triggers | Time from notification to first action in activity stream |
| Time Saved for Humans | Hours freed for board/human oversight | Compare human-equivalent time to agent time |

#### Category 3: Predictive Accuracy & Risk Detection
| Metric | Definition | OrgAgent Measurement |
|--------|-----------|---------------------|
| Forecast Precision | Accuracy of predictions vs actual outcomes | Compare initiative KR targets to actual values |
| Risk Detection Rate | % of issues flagged before escalation | Escalation thread analysis |
| Decision Impact Correlation | Alignment of agent recommendations with positive outcomes | Requires outcome tracking |

#### Category 4: Multi-Agent Coordination
| Metric | Definition | OrgAgent Measurement |
|--------|-----------|---------------------|
| Inter-agent Communication Efficiency | Frequency and clarity of data sharing | Thread message analysis |
| Workflow Handoff Success | Seamless task transitions between agents | Task re-assignment and blocker analysis |
| Outcome Consistency | Aligned recommendations across agents | Cross-agent output comparison |

#### Category 5: User/Stakeholder Engagement
| Metric | Definition | OrgAgent Measurement |
|--------|-----------|---------------------|
| Report Usage Rate | How frequently board reviews agent-generated insights | Board interaction frequency |
| Stakeholder Satisfaction | Perceived value of agent outputs | Board feedback on deliverables |
| Decision Adoption Rate | % of agent recommendations implemented | Approval rate in `org/board/decisions/` |

#### Category 6: Operational ROI & Business Impact
| Metric | Definition | OrgAgent Measurement |
|--------|-----------|---------------------|
| Cost per Successful Task | Budget spent per task that achieves its goal | Budget / goal-achieving tasks |
| Revenue Uplift | Incremental growth attributable to agent work | Requires external data integration |
| Process Optimization | Improvements in throughput and resource utilization | Trend analysis over time |

### Key Finding: The 10 Essential KPIs (Pendo, 2026)

Pendo's framework divides into Growth KPIs and Performance KPIs:

**Growth KPIs:**
1. **Conversations** — total interactions (maps to thread message count in OrgAgent)
2. **Visitors/Users** — unique users interacting (maps to distinct agents active per heartbeat)
3. **Accounts** — organizational entities using the system (single-org for OrgAgent, N/A)
4. **Retention Rate** — users returning after initial interaction (maps to agent lifecycle longevity)

**Performance KPIs:**
5. **Unsupported Requests** — prompts agent cannot handle (maps to escalation rate)
6. **Rage Prompting** — frustration indicators (maps to repeated failed attempts in activity stream)
7. **Conversion Rate** — successful task completions vs attempts (maps to tasks completed / tasks assigned)
8. **Average Time to Complete** — mean task duration (directly measurable from task timestamps)
9. **Median Time to Complete** — filters outliers (more representative than average)
10. **Issue Detection** — automated problem surfacing (requires analytics agent)

### Key Finding: Microsoft's Three-Dimensional Framework (Feb 2026)

Microsoft proposes evaluating AI agents on three dimensions beyond traditional speed metrics:
1. **Understanding** — whether the agent comprehends the actual intent/goal
2. **Reasoning** — how the agent processes information and makes decisions
3. **Response Quality** — effectiveness and appropriateness of outputs

**OrgAgent application:** These map to evaluating task deliverables against acceptance criteria (understanding), reasoning traces in current-state.md (reasoning), and outcome measurement (response quality).

### Key Finding: AgentOps — The Observability Standard

The emerging AgentOps discipline (2025-2026) shifts from passive post-mortem analysis to active experimental monitoring. Tools like Langfuse, Braintrust, and Arize provide:
- Detailed traces of agent execution
- Real-time dashboards for metrics
- Cost tracking per operation
- Behavioral anomaly detection
- OpenTelemetry-based portable metrics

**OrgAgent already has Layer 1 (Activity Stream) and Layer 2 (Current State) of observability. What's missing is Layer 4: Outcome Observability — tracking whether actions achieved their goals.**

### Sources
- [The KPIs That Actually Matter for Production AI Agents — Google Cloud](https://cloud.google.com/transform/the-kpis-that-actually-matter-for-production-ai-agents)
- [10 Essential KPIs to Prove the Value of AI Agents — Pendo](https://www.pendo.io/essential-kpis-measuring-ai-agent-performance/)
- [The KPI Blueprint for Agentic AI Success — Fluid AI](https://www.fluid.ai/blog/the-kpi-blueprint-for-agentic-ai-success)
- [AI Agent Performance Measurement: Redefining Excellence — Microsoft](https://www.microsoft.com/en-us/dynamics-365/blog/it-professional/2026/02/04/ai-agent-performance-measurement/)
- [AI Agent Monitoring: Best Practices, Tools, and Metrics for 2026 — UptimeRobot](https://uptimerobot.com/knowledge-hub/monitoring/ai-agent-monitoring-best-practices-tools-and-metrics/)
- [15 AI Agent Observability Tools in 2026 — AIMultiple](https://research.aimultiple.com/agentic-monitoring/)
- [5 Best Tools for Monitoring LLM Applications in 2026 — Braintrust](https://www.braintrust.dev/articles/best-llm-monitoring-tools-2026)
- [How to Measure Agent Performance — DataRobot](https://www.datarobot.com/blog/how-to-measure-agent-performance/)
- [AI Agent Performance: Success Rates & ROI in 2026 — AIMultiple](https://aimultiple.com/ai-agent-performance)

---

## 6. Research Area 5: Closed-Loop AI Systems

### Key Finding: OODA Loop Is the Dominant Framework

The OODA loop (Observe, Orient, Decide, Act) — originally from military strategy — has become the dominant framework for closed-loop AI agent systems in 2025-2026.

**Mapping to OrgAgent's heartbeat cycle:**

| OODA Phase | Description | OrgAgent Current | Enhancement Needed |
|-----------|-------------|-----------------|-------------------|
| **Observe** | Gather environmental data | Heartbeat Phase 1: CEO reads threads, tasks, reports | Add: read outcome metrics, KR progress, external data |
| **Orient** | Transform observations into situational understanding | CEO reasoning + MEMORY.md | Add: compare actual outcomes vs expected, detect drift |
| **Decide** | Select optimal actions | CEO creates directives, updates initiatives | Add: adjust strategy based on outcome data |
| **Act** | Execute decisions | Phases 2-4: Managers + Workers execute | No change needed |

**Missing feedback arc:** After Act, OODA requires flowing back to Observe. In OrgAgent, after workers complete tasks (Act), there is no observation of whether those actions achieved their intended outcomes. The loop is broken.

### Key Finding: Reflexion Extends OODA Across Attempts

While OODA governs within-execution adaptation, Reflexion enables learning **across** multiple task attempts:

- **OODA** = real-time decision loop within a single heartbeat cycle
- **Reflexion** = cross-cycle learning where past outcomes inform future strategy

OrgAgent needs both:
1. **Within-cycle OODA:** CEO observes outcomes during heartbeat -> orients based on metrics -> decides strategy adjustments -> delegates new work
2. **Cross-cycle Reflexion:** After each heartbeat, agents reflect on completed work, store lessons, and the next cycle begins with enriched context

### Key Finding: The Overthinking Problem

A critical challenge in feedback-driven systems: "Higher overthinking scores correlate with decreased performance." Three manifestation patterns:
1. **Analysis Paralysis** — excessive planning without action
2. **Rogue Actions** — multiple simultaneous attempts after errors
3. **Premature Disengagement** — abandoning tasks prematurely

**Mitigation:** Explicit constraints including maximum retry counts, time-boxed reflection, and escalation triggers prevent reflection paralysis. OrgAgent's existing budget caps and heartbeat time limits provide natural guardrails.

### Key Finding: Not All Feedback Merits Storage

"Negative feedback often carries more signal than positive feedback, but random noise shouldn't trigger updates." This requires meta-reasoning about feedback reliability.

**OrgAgent application:** Outcome reviews should distinguish between:
- **Significant outcomes** (large positive/negative deltas) -> store in MEMORY.md and outcome log
- **Expected outcomes** (on-track progress) -> log but don't trigger learning
- **Noise** (measurement variance, temporary fluctuations) -> discard

### Key Finding: A/B Testing for Agents

Runner AI (January 2026) introduced an "always-on optimizer" that continuously runs A/B tests, learns from outcomes, and optimizes autonomously. Teams using agents across the full experimentation lifecycle run 78.7% more experiments.

**OrgAgent application:** When the org faces a strategic choice (e.g., "SEO-first vs social-media-first"), it could:
1. Create parallel tasks testing both approaches
2. Define measurable comparison criteria
3. Run both for a defined period
4. Compare outcomes
5. Double down on the winner

This requires the experiment/outcome tracking infrastructure proposed in this document.

### Key Finding: Belief Decay Prevents Knowledge Staleness

A production OODA implementation uses confidence decay (tau=0.95 per cycle) so old learnings gradually lose influence unless reinforced. This prevents agents from clinging to outdated strategies.

**OrgAgent application:** MEMORY.md entries could include a `last_validated` date. During retrospectives, learnings not reinforced by recent evidence get deprioritized or pruned.

### Key Finding: Customer Feedback Integration

AI-powered feedback analysis platforms (Zonka, Chattermill, Thematic) demonstrate that customer feedback can be:
- Collected automatically from multiple channels
- Analyzed with NLP for sentiment, themes, and intent
- Mapped to business entities (products, services, agents)
- Surfaced as actionable insights in real-time

**OrgAgent application:** The browser skill or external connectors can collect feedback from review platforms, support tickets, analytics dashboards, and social media — feeding structured feedback into the outcome tracking system.

### Sources
- [Harnessing the OODA Loop for Agentic AI — Sogeti](https://www.sogeti.com/featured-articles/harnessing-the-ooda-loop-for-agentic-ai/)
- [Agentic AI's OODA Loop Problem — Berkman Klein Center / Harvard](https://cyber.harvard.edu/story/2025-10/agentic-ais-ooda-loop-problem)
- [The Agentic OODA Loop: How AI and Humans Learn to Defend Together — Snyk](https://snyk.io/blog/agentic-ooda-loop/)
- [Optimizing Data Center Performance with AI Agents and the OODA Loop — NVIDIA](https://developer.nvidia.com/blog/optimizing-data-center-performance-with-ai-agents-and-the-ooda-loop-strategy/)
- [Agent Feedback Loops: From OODA to Self-Reflection](https://tao-hpu.medium.com/agent-feedback-loops-from-ooda-to-self-reflection-92eb9dd204f6)
- [The OODA Loop Pattern for Autonomous AI Agents — DEV Community](https://dev.to/yedanyagamiaicmd/the-ooda-loop-pattern-for-autonomous-ai-agents-how-i-built-a-self-improving-system-2ap3)
- [A/B Testing AI Tools: Smarter Experiments in 2026](https://nerdleveltech.com/ab-testing-ai-tools-smarter-experiments-in-2026)
- [Agentic AI for Experimentation: Hype vs. Reality — AB Tasty](https://www.abtasty.com/blog/agentic-ai-experimentation/)
- [Customer Feedback Analyzer with AI Agents 2026 — Archiz](https://archizsolutions.com/customer-feedback-analyzer/)
- [How AI Enhances Customer Feedback Cycles — Glean](https://www.glean.com/perspectives/ai-for-improving-customer-feedback-cycles)

---

## 7. Codebase Analysis: Current State & Integration Points

### 7.1 Task File Format — Where Outcomes Would Attach

**Current task file** (`org/agents/{name}/tasks/{status}/*.md`):

```yaml
---
id: task-20260331-001
title: Create Q2 SEO strategy document
priority: high
status: active
assigned_to: seo-agent
assigned_by: marketing-manager
initiative: q2-marketing-growth
created: 2026-03-31T10:00:00
started: 2026-03-31T10:30:00
completed:
deadline: 2026-04-15
estimated_cost_usd: 0.50
---
```

**What's missing from the task lifecycle:**
1. No `outcome_status` field (succeeded / partially_succeeded / failed / unknown)
2. No `outcome_measured` date
3. No `outcome_metrics` linking to initiative KRs
4. No `review_status` (pending_review / reviewed / no_review_needed)
5. No `lessons_learned` section
6. The `Results` section exists but has no structure — it's free-text filled by the agent

### 7.2 Initiative File Format — Where KR Tracking Would Live

**Current initiative** (`org/initiatives/*.md`):

The initiative format has Key Results stated as text but with NO measurement tracking:
- No baseline/target/current values
- No measurement dates
- No progress percentages
- No health indicators
- No measurement log

### 7.3 The Delegate Skill — Where Outcome Expectations Would Be Set

The `/delegate` skill creates a task with `Acceptance Criteria` — these are input-quality criteria (did the agent produce what was asked?), but not outcome criteria (did the output achieve its goal?). There is no field for "what success looks like in the real world."

### 7.4 The Report Skill — Where Outcome Reporting Would Flow

The `/report` skill generates daily status reports with:
- Completed tasks (what was done)
- In progress tasks (what's happening)
- Budget status (spending)
- Escalations

**Missing from reports:**
- Outcome metrics (how are KRs progressing?)
- Trend analysis (are we improving or declining?)
- Retrospective insights (what did we learn?)
- Forecast (at current velocity, will we hit targets?)

### 7.5 The Observability Architecture — Three Layers + Missing Fourth

**Current three layers:**
1. **Activity Stream** (Layer 1) — immutable log of every file operation (hook-forced)
2. **Current State** (Layer 2) — agent's cognitive state (agent-maintained, hook-enforced)
3. **Thread-Based Chat** (Layer 3) — all inter-agent communication

**Missing fourth layer:**
4. **Outcome Tracking** (Layer 4) — measurement of whether completed work achieved its goals

### 7.6 MEMORY.md — Where Learning Would Persist

MEMORY.md already has a `Learnings` section:
```markdown
## Learnings
- CEO prefers concise reports (under 50 lines)
- SEO Agent works best with specific, measurable task descriptions
- Social media content performs better when published Tuesday-Thursday
```

This is the natural home for outcome-driven learnings. Currently, these learnings are ad-hoc and anecdotal. With outcome tracking, they would be evidence-based: "SEO-first approach delivered 2x the traffic impact of social-media-first (measured in Q2 KR-1 review)."

### 7.7 The Heartbeat Cycle — Where Feedback Would Be Processed

Current heartbeat phases:
1. **Phase 1: CEO** — reviews, strategizes, delegates
2. **Phase 2: Managers** — process directives, delegate to workers
3. **Phase 3: Workers** — execute tasks, produce deliverables
4. **Phase 4: CAO** — manages workforce, processes requests

**Missing phase (Phase 0 or Phase 5):** Outcome Review & Retrospective
- Measure KR progress
- Review completed task outcomes
- Detect drift from strategic goals
- Generate retrospective insights
- Update MEMORY.md with evidence-based learnings

---

## 8. Synthesis: The OrgAgent Feedback Loop Architecture

Based on all research, the following architecture closes the feedback loop while respecting OrgAgent's filesystem-based, markdown-driven, hook-enforced design.

### 8.1 The Closed Loop

```
                    ┌─────────────────────────────────────┐
                    │         THE OUTCOME LOOP             │
                    │                                      │
   PLAN ──────────►│  EXECUTE ──────► MEASURE ──────►     │
     ▲              │                                      │
     │              │  LEARN ◄──────── REVIEW ◄──────     │
     │              │    │                                  │
     │              └────│──────────────────────────────────┘
     │                   │
     └───────────────────┘
         (next cycle)
```

**Five stages:**
1. **PLAN** — CEO sets initiatives with measurable KRs (enhanced initiative format)
2. **EXECUTE** — Managers + Workers produce deliverables (existing heartbeat)
3. **MEASURE** — Agents collect outcome data against KR baselines (new capability)
4. **REVIEW** — CEO/Managers evaluate outcomes, compare to expectations (new heartbeat phase)
5. **LEARN** — Insights recorded in MEMORY.md, strategy adjusted for next cycle (new capability)

### 8.2 New File Types

#### 8.2.1 Outcome Record (`org/outcomes/outcome-{YYYYMMDD}-{NNN}.md`)

Individual outcome measurement linked to a completed task and an initiative KR.

```markdown
---
id: outcome-20260415-001
task_id: task-20260401-003
task_title: Execute Q2 SEO content plan
initiative: q2-marketing-growth
key_result: KR-1
measured_by: seo-agent
measured_date: 2026-04-15
outcome_status: exceeded
---

## Measurement

### Key Result: KR-1 — Organic Traffic Growth
- **Baseline:** 10,000 monthly visitors
- **Target:** 13,000 monthly visitors
- **Actual:** 11,800 monthly visitors (at midpoint)
- **Progress:** 60% of target achieved at 50% of timeline
- **Trajectory:** On track to exceed target

### Evidence
- Google Analytics data collected via browser skill on 2026-04-15
- 14-day rolling average: 11,800 unique visitors
- Key drivers: 4 new blog posts ranking in top 10 for target keywords
- Source: `org/agents/seo-agent/deliverables/analytics-report-20260415.md`

### Comparison to Expectation
- Expected at midpoint: 11,500 (linear interpolation)
- Actual: 11,800 (+2.6% ahead of linear projection)
- Assessment: SEO-first strategy is outperforming expectations

## Attribution
| Contributing Task | Agent | Impact |
|-------------------|-------|--------|
| task-20260401-003 | seo-agent | Primary — content optimization |
| task-20260405-001 | seo-agent | Secondary — technical SEO fixes |
| task-20260408-002 | marketing-manager | Supporting — content calendar |
```

**Field definitions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | Yes | `outcome-YYYYMMDD-NNN` |
| `task_id` | string | Yes | The completed task being measured |
| `task_title` | string | Yes | Human-readable task title |
| `initiative` | string | Yes | Initiative slug |
| `key_result` | string | Yes | Which KR this outcome measures (KR-1, KR-2, etc.) |
| `measured_by` | string | Yes | Agent ID that collected the measurement |
| `measured_date` | date | Yes | When measurement was taken |
| `outcome_status` | enum | Yes | `exceeded`, `met`, `partially_met`, `missed`, `too_early`, `unmeasurable` |

#### 8.2.2 Retrospective Record (`org/retrospectives/retro-{YYYYMMDD}.md`)

Periodic analysis of outcomes, patterns, and learnings.

```markdown
---
id: retro-20260415
date: 2026-04-15
cycle: mid-q2-review
conducted_by: ceo
participants:
  - ceo
  - marketing-manager
  - cao
initiatives_reviewed:
  - q2-marketing-growth
---

# Retrospective — Mid-Q2 Review — 2026-04-15

## Initiative: Q2 Marketing Growth

### KR Progress Summary
| KR | Target | Current | Progress | Health | Trend |
|----|--------|---------|----------|--------|-------|
| KR-1: Organic Traffic | 13,000 | 11,800 | 60% | on-track | improving |
| KR-2: Social Followers | 1,000 | 250 | 25% | at-risk | stalling |
| KR-3: Content Published | 24 | 8 | 33% | on-track | steady |
| KR-4: SEO Rankings | 30 | 22 | 47% | on-track | improving |

### What Worked
1. **SEO-first strategy** — KR-1 is 2.6% ahead of linear projection. The decision to prioritize organic search over social media in the first 2 weeks was correct. Evidence: outcome-20260415-001.
2. **Specific task descriptions** — SEO Agent produced higher-quality deliverables when given numeric targets (per MEMORY.md learning).
3. **Content calendar approach** — regular publishing cadence (2/week) maintained consistently.

### What Didn't Work
1. **Social media delayed too long** — KR-2 is at 25% at midpoint. Starting social media in week 3 instead of week 1 created a compounding delay. The organic-first strategy was correct for SEO but the social media start should have been parallel, not sequential.
2. **No cross-promotion** — Blog content not being shared on social media, missing synergy.

### Patterns Detected
- Tasks with numeric acceptance criteria (e.g., "identify top 20 keywords") have higher outcome success rates than qualitative criteria (e.g., "create a good strategy document").
- Agent-to-agent handoffs that include explicit context references (file paths) reduce re-work by ~40% (based on activity stream analysis).

### Action Items for Next Cycle
1. **Immediately** parallelize social media effort — delegate to @social-media-agent with aggressive catch-up targets
2. **Mandate cross-promotion** — every blog post must have a corresponding social media post within 24h
3. **Revise KR-2 trajectory** — adjusted target: 800 instead of 1,000 (still ambitious but realistic given late start)
4. **Codify learning** — all future task delegations must include numeric acceptance criteria where possible

### Learnings to Persist (→ MEMORY.md)
- SEO-first strategy validated for traffic growth (high confidence)
- Social media should start in parallel, not sequentially (high confidence)
- Numeric acceptance criteria correlate with better outcomes (medium confidence, N=12 tasks)
- Cross-functional synergy (content x social) must be explicitly mandated — it does not emerge naturally (high confidence)
```

#### 8.2.3 Metrics Dashboard Data (`org/metrics/current.md`)

Aggregated metrics for the GUI dashboard and status reports.

```markdown
---
updated: 2026-04-15T12:00:00
period: 2026-Q2
---

# Organisation Metrics

## Initiative Health
| Initiative | Owner | Progress | Health | KRs On Track | KRs At Risk |
|-----------|-------|----------|--------|-------------|------------|
| q2-marketing-growth | ceo | 41% | on-track | 3/4 | 1/4 |

## Agent Performance
| Agent | Tasks Completed | Avg Duration | Outcome Success Rate | Budget Used |
|-------|----------------|-------------|---------------------|-------------|
| seo-agent | 8 | 1.2 cycles | 87% (7/8 met criteria) | $12 / $30 |
| social-media-agent | 3 | 2.0 cycles | 67% (2/3 met criteria) | $5 / $20 |
| marketing-manager | 5 | 0.5 cycles | 80% (4/5 met criteria) | $8 / $60 |

## Trend Data
| Week | Tasks Completed | Outcome Success Rate | KR Progress Delta |
|------|----------------|---------------------|-------------------|
| W1 (Mar 31) | 3 | 67% | +5% |
| W2 (Apr 7) | 5 | 80% | +12% |
| W3 (Apr 14) | 6 | 83% | +10% |

## Cost Efficiency
| Metric | Value |
|--------|-------|
| Cost per successful outcome | $1.85 |
| Cost per failed outcome | $2.40 |
| Overall outcome success rate | 81% |
| Budget utilization | 32% of quarterly |
```

### 8.3 Enhanced Task Lifecycle

```
backlog → active → done → reviewed → [closed | rework]
                                  ↓
                             outcome measured
                                  ↓
                          retrospective analyzed
                                  ↓
                           learnings persisted
```

**New task statuses:**
- `done` — work completed, results written (existing)
- `reviewed` — outcome measured and evaluated (new)
- `closed` — outcome accepted, task archived (new)
- `rework` — outcome unsatisfactory, task returns to active with new criteria (new)

**Enhanced task frontmatter:**

```yaml
---
id: task-20260401-003
title: Execute Q2 SEO content plan
priority: high
status: reviewed
assigned_to: seo-agent
assigned_by: marketing-manager
initiative: q2-marketing-growth
created: 2026-04-01T10:00:00
started: 2026-04-01T10:30:00
completed: 2026-04-14T15:00:00
deadline: 2026-04-15
estimated_cost_usd: 0.50
actual_cost_usd: 0.42
# --- NEW OUTCOME FIELDS ---
outcome_status: met
outcome_id: outcome-20260415-001
reviewed_by: marketing-manager
reviewed_date: 2026-04-15
outcome_notes: "KR-1 on track, content quality high"
---
```

### 8.4 Enhanced Heartbeat Cycle

```
Phase 0: OUTCOME REVIEW (NEW)
  ├── Alignment Agent checks for drift (existing from doc 22)
  ├── CEO reviews outcome records since last heartbeat
  ├── CEO updates initiative KR progress
  ├── CEO identifies at-risk KRs
  └── CEO adjusts strategy based on evidence

Phase 1: CEO (existing, enhanced)
  ├── Reads threads, tasks, reports (existing)
  ├── Reads outcome records and retrospectives (NEW)
  ├── Reviews KR dashboards (NEW)
  ├── Creates directives informed by outcome data (enhanced)
  └── Delegates with outcome-aware context (enhanced)

Phase 2: MANAGERS (existing, enhanced)
  ├── Process directives (existing)
  ├── Review subordinate outcome records (NEW)
  ├── Delegate tasks with measurable outcome criteria (enhanced)
  └── Flag at-risk KRs to CEO (NEW)

Phase 3: WORKERS (existing, enhanced)
  ├── Execute tasks (existing)
  ├── Collect outcome measurements when due (NEW)
  ├── Write outcome records (NEW)
  └── Produce deliverables (existing)

Phase 4: CAO (existing, enhanced)
  ├── Process requests (existing)
  ├── Review org-wide metrics (NEW)
  ├── Identify workforce gaps based on outcome data (NEW)
  └── Propose structural changes if outcomes consistently poor (NEW)
```

### 8.5 New Skill: `/measure`

A new skill for collecting outcome measurements.

```
/measure [initiative] [key-result]
```

**Workflow:**
1. Read the initiative file, find the specified KR
2. Determine measurement source (web analytics, content audit, etc.)
3. Collect current value using appropriate tool (WebSearch, browser, file audit)
4. Compare to baseline and target
5. Calculate progress percentage and trend
6. Write outcome record to `org/outcomes/`
7. Update initiative file with new measurement
8. Notify initiative owner via thread

### 8.6 New Skill: `/retrospective`

A new skill for conducting structured retrospectives.

```
/retrospective [initiative | all]
```

**Workflow:**
1. Read all outcome records since last retrospective
2. Calculate KR progress summaries
3. Identify patterns (what worked, what didn't)
4. Generate action items for next cycle
5. Extract learnings for MEMORY.md persistence
6. Write retrospective record to `org/retrospectives/`
7. Communicate key findings in executive thread
8. Update initiative health status

### 8.7 New Directory Structure

```
org/
├── outcomes/                          # NEW: Individual outcome measurements
│   ├── outcome-20260415-001.md
│   ├── outcome-20260415-002.md
│   └── ...
├── retrospectives/                    # NEW: Periodic retrospective records
│   ├── retro-20260415.md
│   └── ...
├── metrics/                           # NEW: Aggregated metrics dashboard data
│   ├── current.md                     # Latest metrics snapshot
│   └── history/                       # Historical metrics snapshots
│       ├── metrics-20260401.md
│       └── metrics-20260408.md
├── experiments/                       # NEW: A/B test tracking (optional)
│   └── experiment-seo-vs-social-20260401.md
├── initiatives/                       # ENHANCED: with KR tracking
│   └── q2-marketing-growth.md
└── agents/{name}/
    ├── tasks/
    │   ├── backlog/
    │   ├── active/
    │   ├── done/                      # ENHANCED: tasks can be reviewed
    │   └── reviewed/                  # NEW: tasks with outcome data
    └── MEMORY.md                      # ENHANCED: evidence-based learnings
```

---

## 9. Implementation Proposals

### Proposal A: Minimal — Outcome Fields on Tasks + Initiative KR Tracking

**Scope:** Add outcome tracking to existing files without new file types or skills.

**Changes:**
1. Add `outcome_status`, `outcome_notes`, `reviewed_by`, `reviewed_date` fields to task frontmatter
2. Add structured KR tracking to initiative files (baseline/target/current/progress)
3. Add a "Retrospective" section to the daily report format
4. CEO heartbeat checklist includes "Review completed task outcomes"

**Pros:**
- Minimal implementation effort
- No new file types to parse in GUI
- No new hooks needed
- Works within existing skill set

**Cons:**
- No dedicated outcome records (scattered across task files)
- No aggregated metrics view
- No dedicated retrospective process
- Learning remains anecdotal in MEMORY.md

**Effort:** Low (2-3 file format changes, 2 skill enhancements)

---

### Proposal B: Moderate — Outcome Records + Enhanced Initiative Tracking + Retrospective Skill

**Scope:** New outcome record file type, enhanced initiatives, and a retrospective skill.

**Changes:**
1. Everything in Proposal A
2. New `org/outcomes/` directory with structured outcome records
3. New `/retrospective` skill for periodic analysis
4. Enhanced `/report` skill that includes outcome metrics
5. Initiative files with full KR tracking (baseline/target/current/trend/measurement-log)
6. Measurement Log table appended to initiative files

**Pros:**
- Dedicated outcome tracking with full audit trail
- Structured retrospective process
- Pattern detection across multiple outcomes
- Evidence-based MEMORY.md updates
- Moderate implementation effort

**Cons:**
- New file type to maintain and parse
- Additional heartbeat phase required
- Increased agent session costs (more reading/writing)

**Effort:** Moderate (1 new file type, 1 new skill, 3 skill enhancements, 1 heartbeat change)

---

### Proposal C: Full — Complete Closed-Loop System with Metrics, Experiments, and Learning

**Scope:** Full feedback loop with metrics dashboard, A/B testing, and automated learning.

**Changes:**
1. Everything in Proposal B
2. New `org/metrics/` directory with aggregated dashboard data
3. New `org/experiments/` directory for A/B test tracking
4. New `org/retrospectives/` directory for structured retrospectives
5. New `/measure` skill for outcome data collection
6. New `/retrospective` skill (from Proposal B)
7. New `/experiment` skill for creating and tracking A/B tests
8. Enhanced heartbeat with Phase 0 (Outcome Review)
9. GUI dashboard enhanced with outcome charts and KR progress visualization
10. Belief decay in MEMORY.md (learnings include `last_validated` and `confidence`)
11. Agent performance metrics tracked in `org/metrics/current.md`
12. New hook: `outcome-reminder.sh` — reminds agents to measure outcomes for overdue tasks

**Pros:**
- Fully closed feedback loop
- A/B testing capability for strategic decisions
- Aggregated metrics for board oversight
- Evidence-based learning with confidence decay
- GUI dashboard visualization
- Pattern detection across the entire org

**Cons:**
- Significant implementation effort
- Multiple new file types and skills
- Increased system complexity
- Higher per-heartbeat cost (more phases, more reading/writing)
- Risk of over-engineering for small orgs

**Effort:** High (3 new file types, 3 new skills, 5 skill enhancements, 1 new hook, GUI changes)

---

### Recommended: Proposal B with Selective Elements from C

**Rationale:** Proposal B provides the essential closed-loop architecture (outcome records + retrospectives + initiative tracking) without the complexity overhead of full A/B testing and advanced metrics. Selected elements from C can be added incrementally:

**Phase 1 (Core — Implement with Proposal B):**
- Enhanced task frontmatter with outcome fields
- Enhanced initiative files with KR tracking
- Outcome record file type in `org/outcomes/`
- `/retrospective` skill
- Enhanced `/report` skill with outcome section
- CEO heartbeat enhanced with outcome review step

**Phase 2 (Metrics — Add when org is running):**
- `org/metrics/current.md` for aggregated dashboard data
- GUI dashboard outcome visualization
- Agent performance metrics

**Phase 3 (Advanced — Add when patterns emerge):**
- `/measure` skill for automated data collection
- `/experiment` skill for A/B testing
- Belief decay in MEMORY.md
- `outcome-reminder.sh` hook

---

## 10. Trade-offs & Decisions Required

### Decision 1: Task Status Extension

**Question:** Should `done` tasks have additional statuses (`reviewed`, `closed`, `rework`), or should outcome data be added as fields within `done`?

| Option | Pros | Cons |
|--------|------|------|
| **A: New statuses** (done -> reviewed -> closed/rework) | Clear lifecycle, GUI can show review pipeline, forces review | More directories, more file moves, more complex task skill |
| **B: Fields within done** (add outcome_status to done tasks) | Simpler, fewer directories, backward-compatible | Less visible in GUI, review not enforced |

**Recommendation:** Option B (fields within done). Adding new status directories is heavy for the filesystem. Outcome fields on done tasks are sufficient, and the review process can be enforced by the retrospective skill reading `done` tasks that lack `outcome_status`.

### Decision 2: Who Measures Outcomes?

**Question:** Which agent is responsible for collecting outcome measurements?

| Option | Description | Trade-off |
|--------|-------------|-----------|
| **A: Task assignee** | The worker who did the task measures the outcome | Workers may lack access to external data; risk of self-grading bias |
| **B: Task assigner** (supervisor) | The manager who delegated evaluates the outcome | More objective, but adds manager workload |
| **C: Dedicated Analytics Agent** | A new agent role focused on measurement | Most objective, but adds org complexity and cost |
| **D: Hybrid** | Workers collect raw data, managers evaluate significance | Balanced, but requires coordination |

**Recommendation:** Option D (hybrid). Workers are closest to the data and can collect measurements. Managers have context to evaluate significance. The CEO synthesizes at the strategic level during retrospectives.

### Decision 3: Measurement Frequency

**Question:** How often should outcomes be measured?

| Option | Frequency | Trade-off |
|--------|-----------|-----------|
| **A: Every heartbeat** | Each cycle includes outcome measurement | High cost, too frequent for most KRs |
| **B: Weekly** | Dedicated weekly measurement cycle | Balanced frequency, manageable cost |
| **C: At initiative milestones** | When initiative reaches 25%, 50%, 75%, 100% | Least frequent, lowest cost, but delayed feedback |
| **D: Configurable per KR** | Each KR specifies its own measurement frequency | Most flexible, but complex |

**Recommendation:** Option B (weekly) as the default, with Option D (per-KR override) for KRs that need daily or monthly measurement. Add `review_frequency` to the initiative frontmatter.

### Decision 4: Where Do Learnings Live?

**Question:** Should outcome-derived learnings go into MEMORY.md, a dedicated learnings file, or both?

| Option | Description | Trade-off |
|--------|-------------|-----------|
| **A: MEMORY.md only** | Learnings added to existing Learnings section | Simple, single source, but MEMORY.md may grow too large |
| **B: Dedicated learnings file** | New `org/agents/{name}/LEARNINGS.md` | Separate concerns, but adds another file to context loading |
| **C: Retrospective records** | Learnings stay in `org/retrospectives/` | Centralized, but agents must search retrospectives for relevant learnings |
| **D: MEMORY.md + retrospective cross-reference** | MEMORY.md holds distilled learnings with references to retrospective records | Best of both worlds: quick access + full audit trail |

**Recommendation:** Option D. MEMORY.md gets concise, evidence-based learnings with a reference to the retrospective record where the full analysis lives. Example:

```markdown
## Learnings
- SEO-first strategy validated for traffic growth — 60% of target at 50% of timeline (ref: retro-20260415, outcome-20260415-001) [confidence: high, validated: 2026-04-15]
- Social media should start in parallel, not sequentially — delayed start caused KR-2 to fall behind (ref: retro-20260415) [confidence: high, validated: 2026-04-15]
```

### Decision 5: Feedback From External Systems

**Question:** How should the org collect real-world data (analytics, customer feedback, sales figures)?

| Option | Description | Trade-off |
|--------|-------------|-----------|
| **A: Manual board input** | Human provides data when asked | Zero automation, high reliability, low frequency |
| **B: Browser skill automation** | Agents use Playwright to scrape dashboards | Automated, but fragile (UI changes break scraping) |
| **C: n8n connectors** | External data piped into org files via n8n workflows | Robust automation, but requires n8n setup |
| **D: WebSearch/WebFetch** | Agents search for public data | Works for public metrics, unreliable for private data |
| **E: Hybrid** | n8n for reliable integrations, browser for ad-hoc, manual for sensitive data | Most flexible, highest implementation cost |

**Recommendation:** Option E (hybrid). The config.md already has `n8n_available` and `browser_enabled` flags. Use n8n connectors for reliable data pipelines (analytics, CRM), browser skill for ad-hoc data collection, and manual board input for sensitive or unavailable data. Fall back gracefully: if n8n is not available, use browser; if browser is not enabled, ask the board.

### Decision 6: Experiment/A/B Testing Scope

**Question:** Should A/B testing be a core feature or an optional extension?

**Recommendation:** Optional extension (Phase 3). Most orgs will benefit from basic outcome tracking and retrospectives before they need formal experimentation. The experiment file type and skill can be added later without breaking the core feedback loop.

### Decision 7: Hook Enforcement of Outcome Tracking

**Question:** Should a hook enforce outcome measurement (similar to how `require-state-and-communication.sh` enforces state updates)?

| Option | Description | Trade-off |
|--------|-------------|-----------|
| **A: Hard enforcement** | Hook blocks session end if completed tasks lack outcome review | Forces compliance, but some tasks genuinely don't need outcome review |
| **B: Soft reminder** | Hook reminds but doesn't block if tasks in done/ lack outcome_status | Encourages compliance without blocking |
| **C: No enforcement** | Outcome tracking is voluntary | Zero friction, but risks adoption failure |

**Recommendation:** Option B (soft reminder). A PostToolUse hook that checks for done tasks older than `review_frequency` without outcome data and adds a reminder. This matches the existing `remind-state-update.sh` pattern.

---

## Summary of Key Findings

1. **The Agent Loop is the standard** — production AI systems use Observe-Orient-Decide-Act-Learn cycles. OrgAgent has the first four but lacks the last.

2. **Goal Fulfillment is the primary KPI** — measuring task completion is necessary but insufficient. Outcome measurement against initiative Key Results is the critical missing piece.

3. **Reflexion (cross-cycle learning) is essential** — agents must reflect on outcomes across multiple heartbeat cycles, not just within a single execution.

4. **Episodic memory stores structured experiences** — OrgAgent's outcome records serve as episodic memory, enabling agents to reason about past successes and failures.

5. **Multi-stage retrospective pipelines work best** — separating data collection, pattern analysis, and learning extraction (like Zalando's approach) produces better insights than monolithic analysis.

6. **Meta's REA proves production viability** — a centralized experiment-outcome database that feeds hypothesis generation is the gold standard for closed-loop agent systems.

7. **Belief decay prevents staleness** — learnings should include confidence scores and validation dates so old knowledge naturally deprioritizes.

8. **The existing OrgAgent architecture needs only extension, not replacement** — initiative files need KR tracking, tasks need outcome fields, the heartbeat needs a review phase, and MEMORY.md needs evidence-based learnings. The core filesystem-based design accommodates all of this.
