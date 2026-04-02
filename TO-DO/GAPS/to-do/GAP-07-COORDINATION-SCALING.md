# GAP-07: Coordination Overhead Scales Poorly — Selective Invocation & Departmental Sub-Heartbeats

**Date:** 2026-04-02
**Status:** Research complete, ready for implementation
**Priority:** HIGH — Without this, cost scales linearly with org size regardless of work volume
**Dependencies:** heartbeat.sh (exists), orgchart.md format (exists), IDENTITY.md format (exists)
**Estimated Effort:** Proposal A: 2-4 hours, Proposal B: 4-8 hours, Full: 8-16 hours

---

## 1. The Problem

Currently, EVERY agent is invoked EVERY heartbeat cycle, regardless of whether they have work. This creates three scaling failures:

### 1.1 Cost Explosion

Each agent invocation costs money (LLM API calls). With the current architecture at scale:
- 30 agents × $0.20 average per invocation = **$6.00 per heartbeat cycle**
- Ralph Wiggum running 5 cycles = **$30.00 per session**
- `/loop 30m` running 48 times/day = **$288/day**
- Most of that spend is on agents discovering they have nothing to do

An idle agent still loads SOUL.md + IDENTITY.md + INSTRUCTIONS.md + HEARTBEAT.md + MEMORY.md + alignment.md + config.md + orgchart.md. Even a no-op session costs $0.05-0.50 depending on context size and model.

### 1.2 Latency Growth

Phase 2 runs ALL managers in parallel. Phase 3 runs ALL workers in parallel. But:
- Each phase must COMPLETE before the next starts
- A fast-finishing marketing department waits for a slow engineering department
- Cross-department workers that have no work still delay the phase

### 1.3 No Priority Differentiation

A worker with a `critical` task and a worker with a `low` priority task are invoked identically. No mechanism to process urgent work first.

### Current heartbeat.sh Architecture

```bash
# Phase 2: ALL managers parallel
for agent in $MANAGER_AGENTS; do
  run_agent "$agent" &
  pids+=($!)
done
wait "${pids[@]}"  # ALL must complete before Phase 3

# Phase 3: ALL workers parallel
for agent in $WORKER_AGENTS; do
  run_agent "$agent" &
  pids+=($!)
done
wait "${pids[@]}"
```

No work-check. No skip logic. No department grouping. No priority ordering.

---

## 2. Research Findings

### 2.1 Google's Quantitative Scaling Principles (2026)

**Source:** [Google Research + MIT — Towards a Science of Scaling Agent Systems](https://arxiv.org/abs/2512.08296)

Evaluated 180 agent configurations. Key findings:

- **Coordination gains plateau beyond 4 agents** in a structured system. Above that, coordination overhead consumes benefits
- **Centralized orchestration reduces error amplification from 17.2x to 4.4x** — OrgAgent's CEO-as-coordinator model is well-aligned
- **The best coordination strategy is task-dependent:** Financial reasoning benefits from centralized (+81%), dynamic tasks from decentralized (+9.2%)
- **On sequential tasks, multi-agent coordination DEGRADES performance by 39-70%** — invoking idle agents adds overhead without value
- **Predictive framework achieves 87% accuracy** in predicting optimal coordination strategy

**Implication for OrgAgent:** The phase model is correct for orchestration. The problem is invoking ALL agents regardless of work.

### 2.2 Event-Driven vs Polling Architecture

Multiple sources (Confluent, Medium, Fast.io) converge:

- **Polling model** (current heartbeat): Cost proportional to number of agents × frequency, regardless of work volume
- **Event-driven model**: Cost proportional to actual work volume. Agents dormant (zero cost) until triggered
- **EDA reduces latency by 70-90%** and eliminates idle-invocation cost entirely

**Key insight for OrgAgent:** Since the system uses filesystem (no Kafka, no message broker), the "event" system must be file-based. The heartbeat script should perform a **lightweight filesystem pre-check** (bash `find`/`grep`, zero cost) BEFORE invoking Claude for each agent.

### 2.3 Cost Optimization Strategies (SOTA 2025-2026)

**Strategy A — Model Cascading (BudgetMLAgent):** Use cheap models first, expensive only when needed. Achieved **94.2% cost reduction** ($0.931 → $0.054 per run) with BETTER success rate.
- OrgAgent already tiers models (opus/sonnet/haiku). Additional: an agent checking "do I have work?" could use haiku even if normally on opus.

**Strategy B — Context Compression:** Cuts 70-85% of input tokens. Net savings: 42-51% of total costs.
- OrgAgent agents currently load ALL context files every heartbeat. An agent with no work still loads ~5000 tokens of context.

**Strategy C — Prompt Caching (Claude-specific):** Cached input tokens cost 10% of normal. Cache TTL: 5 minutes.
- Agent context files (SOUL, IDENTITY, INSTRUCTIONS) are stable between heartbeats. With `/loop 30m`, prompt caching could reduce context loading cost by ~90%.

**Strategy D — Loop Detection:** Agent loops (retrying failing actions) are the most common and expensive failure mode. `--max-turns` per agent limits this.

**Sources:**
- [AI Agent Cost Optimization Guide 2026 (Moltbook-AI)](https://moltbook-ai.com/posts/ai-agent-cost-optimization-2026)
- [LLM Cost Optimization: 8 Strategies (Prem.ai)](https://blog.premai.io/llm-cost-optimization-8-strategies-that-cut-api-spend-by-80-2026-guide/)
- [BudgetMLAgent (arXiv 2411.07464)](https://arxiv.org/abs/2411.07464)
- [Claude Prompt Caching (Anthropic)](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)

### 2.4 Critical Discovery: Reusable Work-Detection Logic

**The Stop hook in TO-DO/18-CONTINUOUS-OPERATION-RALPH-WIGGUM.md (lines 242-297) already contains work detection logic** for deciding whether to continue the Ralph Wiggum loop:

```bash
# Check 1: Unread notifications
UNREAD=$(find "$inbox_dir" -name "*.md" -exec grep -l "read: false" {} \; 2>/dev/null | wc -l)

# Check 2: Pending approvals
PENDING_APPROVALS=$(find "$ORG_DIR/board/approvals" -name "*.md" -exec grep -l "status: pending" {} \; 2>/dev/null | wc -l)

# Check 3: Recent backlog tasks
RECENT=$(find "$backlog_dir" -name "*.md" -mmin -10 2>/dev/null | wc -l)
```

The EXACT same logic should be extracted and reused as the per-agent pre-check. This is not new code — it's refactoring existing logic into a reusable function.

---

## 3. Implementation Proposals

### Proposal A: Lightweight Work Detection Pre-Check (HIGHEST IMPACT, LOWEST EFFORT)

Add a `has_pending_work()` function to `heartbeat.sh`:

```bash
has_pending_work() {
  local agent="$1"
  local agent_dir="$ORG_DIR/agents/$agent"
  
  # Check 1: Unread inbox notifications
  if find "$agent_dir/inbox/" -name "*.md" -exec grep -l "read: false" {} \; 2>/dev/null | head -1 | grep -q .; then
    return 0  # Has work
  fi
  
  # Check 2: Tasks in backlog
  if find "$agent_dir/tasks/backlog/" -name "*.md" 2>/dev/null | head -1 | grep -q .; then
    return 0  # Has work
  fi
  
  # Check 3: Active tasks (need continuation)
  if find "$agent_dir/tasks/active/" -name "*.md" 2>/dev/null | head -1 | grep -q .; then
    return 0  # Has work
  fi
  
  # Check 4: Pending approvals (for CEO/CAO/Alignment Board only)
  if [[ "$agent" == "ceo" || "$agent" == "cao" || "$agent" == "alignment-board" ]]; then
    if find "$ORG_DIR/board/approvals/" -name "*.md" -exec grep -l "status: pending" {} \; 2>/dev/null | head -1 | grep -q .; then
      return 0
    fi
  fi
  
  return 1  # No work
}
```

Then in the phase execution:
```bash
for agent in $WORKER_AGENTS; do
  if has_pending_work "$agent"; then
    run_agent "$agent" &
    pids+=($!)
  else
    echo "[$(date)] Skipping $agent — no pending work"
  fi
done
```

**Trade-offs:**
- **Pro:** Zero LLM cost for idle agents. Pure bash, no API calls
- **Pro:** ~20 lines of bash. Completely backwards compatible
- **Pro:** `head -1` short-circuits after first match — fast even with many files
- **Con:** May miss "ambient" work (checking subordinate reports, reviewing budget)
- **Mitigation:** CEO, CAO, and Alignment Board always run (org-wide responsibilities). Managers run if ANY subordinate has work

**Estimated savings:** 60-80% of heartbeat cost for typical orgs where most agents are idle most of the time.

### Proposal B: Department-Level Sub-Heartbeats (MEDIUM IMPACT, MEDIUM EFFORT)

Restructure heartbeat phases from flat to hierarchical:

**Current:**
```
Phase 0: Alignment Board
Phase 1: CEO
Phase 2: ALL managers (parallel)
Phase 3: ALL workers (parallel)
Phase 4: CAO
```

**Proposed:**
```
Phase 0: Alignment Board
Phase 1: CEO
Phase 2: Department sub-heartbeats (parallel across departments)
  Department A: Manager → Workers (sequential within department)
  Department B: Manager → Workers (sequential within department)
Phase 3: CAO
```

Implementation requires parsing `orgchart.md` to extract department groupings:

```bash
# Build department map: manager -> list of workers
declare -A DEPARTMENT_WORKERS
for worker in $WORKER_AGENTS; do
  manager=$(grep "reports_to:" "$ORG_DIR/agents/$worker/IDENTITY.md" | awk '{print $2}')
  DEPARTMENT_WORKERS[$manager]+="$worker "
done

# Run departments in parallel
dept_pids=()
for manager in $MANAGER_AGENTS; do
  (
    # Run manager first (if has work)
    if has_pending_work "$manager"; then
      run_agent "$manager"
    fi
    # Then run this manager's workers in parallel
    local worker_pids=()
    for worker in ${DEPARTMENT_WORKERS[$manager]}; do
      if has_pending_work "$worker"; then
        run_agent "$worker" &
        worker_pids+=($!)
      fi
    done
    for pid in "${worker_pids[@]}"; do
      wait "$pid" || true
    done
  ) &
  dept_pids+=($!)
done
wait "${dept_pids[@]}"
```

**Trade-offs:**
- **Pro:** Departments with work complete faster (no waiting for unrelated departments)
- **Pro:** Natural isolation — marketing failures don't block engineering
- **Pro:** Manager directives immediately available to their workers (same sub-cycle)
- **Con:** More complex bash script. Requires bash 4+ for associative arrays
- **Con:** Cross-department coordination requires an additional cycle
- **Con:** Workers wait for their manager (but this is correct behavior)

### Proposal C: Priority-Based Agent Ordering (LOW IMPACT, LOW EFFORT)

Sort agents by highest-priority pending task before invocation:

```bash
get_max_priority() {
  local agent="$1"
  local max_pri="4"  # default: no priority
  for task in "$ORG_DIR/agents/$agent/tasks/backlog/"*.md "$ORG_DIR/agents/$agent/tasks/active/"*.md; do
    [[ -f "$task" ]] || continue
    local pri=$(grep "^priority:" "$task" | head -1 | awk '{print $2}')
    case "$pri" in
      critical) echo "0"; return ;;
      high) [[ "$max_pri" -gt "1" ]] && max_pri="1" ;;
      medium) [[ "$max_pri" -gt "2" ]] && max_pri="2" ;;
      low) [[ "$max_pri" -gt "3" ]] && max_pri="3" ;;
    esac
  done
  echo "$max_pri"
}
```

Combine with a max-invocations-per-cycle cap: only invoke the top N workers by priority.

### Proposal D: Two-Phase Agent Invocation (Optional, MEDIUM EFFORT)

Split each agent's heartbeat into two phases:
1. **Triage phase** (cheap): Haiku model, maxTurns=5, only reads inbox/backlog. Outputs JSON verdict.
2. **Execution phase** (full): Normal model, full context, only if triage found work.

**Trade-off:** More intelligent than filesystem checks but still costs money ($0.02-0.05 per triage). Better to combine with Proposal A: use filesystem pre-check (free) first, triage only for ambiguous cases.

### Proposal E: Configurable Heartbeat Scope (LOW EFFORT, HIGH FLEXIBILITY)

Add config fields to `org/config.md`:

```yaml
heartbeat_mode: selective           # "all" | "selective" | "department"
heartbeat_max_workers_per_cycle: 10 # Cap on worker invocations per cycle
heartbeat_always_run:               # Agents that ALWAYS run regardless of work
  - ceo
  - cao
  - alignment-board
heartbeat_skip_check: filesystem    # "filesystem" | "triage" | "none"
```

This makes scaling behavior configurable per-org rather than hardcoded.

### Proposal F: Prompt Caching Optimization (MEDIUM IMPACT, LOW EFFORT)

Since Claude's API supports prompt caching with 90% cost reduction on cache hits:
1. Order agent context loading: stable content first (alignment.md, SOUL.md, INSTRUCTIONS.md), dynamic content last (inbox, tasks, threads)
2. With `/loop 30m`, agents invoked within the same cycle share cached context (alignment.md, config.md, orgchart.md are identical for all agents)
3. Cache TTL is 5 minutes — all agents in the same heartbeat cycle benefit

---

## 4. Recommended Implementation Priority

| Priority | Proposal | Effort | Cost Savings | Risk |
|----------|----------|--------|--------------|------|
| **1 (DO FIRST)** | A: Filesystem pre-check | ~20 lines bash | 60-80% | Very low |
| **2** | E: Configurable heartbeat scope | ~30 lines config + bash | Enables tuning | Very low |
| **3** | B: Department sub-heartbeats | ~50 lines bash | 20-40% latency | Low |
| **4** | C: Priority ordering | ~30 lines bash | 10-20% latency | Very low |
| **5 (OPTIONAL)** | D: Two-phase triage | New agent pattern | Variable | Medium |
| **6 (VERIFY)** | F: Prompt caching | Config change | Up to 90% on context | Low |

**Proposal A alone handles the core problem.** An org with 30 agents where typically 5-8 have work would go from 30 invocations to 5-8 per cycle. At $0.20 average, that saves $4.40-5.00 per cycle. Over a day with `/loop 30m` (48 cycles), that is **$211-240 saved per day**.

---

## 5. Implementation Plan

### Phase 1: Selective Invocation (2-4 hours)
1. Extract `has_pending_work()` from Ralph Wiggum stop hook logic into a shared function
2. Add to `heartbeat.sh` before each agent invocation
3. Add `heartbeat_always_run` config field to `org/config.md`
4. Log skipped agents: `[timestamp] Skipping agent-name — no pending work`
5. Test: create an org with 5 agents, give work to 2, verify only 2 are invoked

### Phase 2: Configuration (1-2 hours)
6. Add `heartbeat_mode`, `heartbeat_max_workers_per_cycle`, `heartbeat_skip_check` to config.md spec
7. Update heartbeat.sh to read config and apply settings
8. Update system-reference.md with heartbeat mode documentation

### Phase 3: Department Sub-Heartbeats (4-8 hours)
9. Add `parse_departments()` function to heartbeat.sh using orgchart.md + IDENTITY.md `reports_to`
10. Restructure Phase 2/3 into department sub-cycles running in parallel
11. Add department-level work detection: skip entire department if no member has work
12. Test: create multi-department org, verify department isolation

### Phase 4: Priority & Cost Optimization (2-4 hours)
13. Add `get_max_priority()` function
14. Sort agents by priority before invocation
15. Add `heartbeat_max_workers_per_cycle` enforcement
16. Document prompt caching strategy in agent definition templates

---

## 6. Architecture Decisions

### Decision 68: Filesystem Pre-Check Before Agent Invocation
**Decision:** Before invoking any agent via `claude --agent`, check the agent's inbox and task directories for pending work using pure bash filesystem operations. Skip invocation if no work is found.
**Reasoning:** A bash `find` + `grep` costs zero API dollars. A no-op Claude invocation costs $0.05-0.50. At scale (30+ agents, 48 heartbeats/day), this saves hundreds of dollars daily. The pre-check logic already exists in the Ralph Wiggum stop hook — it just needs to be reused per-agent.

### Decision 69: CEO, CAO, and Alignment Board Always Run
**Decision:** The CEO, CAO, and Alignment Board are exempt from the idle-skip optimization. They always run every heartbeat cycle regardless of inbox state.
**Reasoning:** These three agents have org-wide responsibilities that go beyond inbox processing. The CEO reviews strategic direction. The CAO monitors workforce health. The Alignment Board checks for drift. Their value comes from periodic review, not just reactive processing.

### Decision 70: Department-Level Sub-Heartbeats
**Decision:** Restructure Phase 2 (managers) and Phase 3 (workers) into department sub-cycles. Each department runs as a unit (manager → workers) in parallel with other departments.
**Reasoning:** The current flat model forces all workers to wait for all managers. Department sub-cycles allow a fast-finishing department to complete independently. Manager directives are immediately available to their workers within the same sub-cycle. Cross-department coordination flows through the next heartbeat via threads.

### Decision 71: Configurable Heartbeat Mode
**Decision:** Add heartbeat configuration to `org/config.md` allowing the board to choose between `all` (every agent runs), `selective` (only agents with work), and `department` (department sub-heartbeats with selective invocation).
**Reasoning:** Different orgs have different needs. A small 5-agent org can afford to invoke everyone. A 30-agent org needs selective invocation. A 100-agent org needs departmental isolation. Making this configurable allows the system to scale with the org.

---

## 7. Sources

- [Google: Towards a Science of Scaling Agent Systems (arXiv 2512.08296)](https://arxiv.org/abs/2512.08296)
- [Google Scaling Principles (InfoQ, March 2026)](https://www.infoq.com/news/2026/03/google-multi-agent/)
- [Four Design Patterns for Event-Driven Multi-Agent Systems (Confluent)](https://www.confluent.io/blog/event-driven-multi-agent-systems/)
- [Event-Driven AI Agent Architecture Guide 2026 (Fast.io)](https://fast.io/resources/ai-agent-event-driven-architecture/)
- [AI Agent Cost Optimization Guide 2026 (Moltbook-AI)](https://moltbook-ai.com/posts/ai-agent-cost-optimization-2026)
- [LLM Cost Optimization: 8 Strategies (Prem.ai)](https://blog.premai.io/llm-cost-optimization-8-strategies-that-cut-api-spend-by-80-2026-guide/)
- [BudgetMLAgent (arXiv 2411.07464)](https://arxiv.org/abs/2411.07464)
- [ARES: Adaptive Reasoning Effort Selection (arXiv 2603.07915)](https://arxiv.org/abs/2603.07915)
- [Scheduler Agent Supervisor Pattern (Microsoft Azure)](https://learn.microsoft.com/en-us/azure/architecture/patterns/scheduler-agent-supervisor)
- [Claude Prompt Caching (Anthropic)](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)
- [Manage Costs Effectively (Claude Code Docs)](https://code.claude.com/docs/en/costs)
- [Budget-Aware Tool-Use Enables Effective Agent Scaling (arXiv 2511.17006)](https://arxiv.org/html/2511.17006v1)
- [How Task Scheduling Optimizes LLM Workflows (Latitude)](https://latitude.so/blog/how-task-scheduling-optimizes-llm-workflows)
