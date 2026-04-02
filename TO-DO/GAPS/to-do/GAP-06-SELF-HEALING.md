# GAP-06: No Self-Healing — Integrity Checking, Recovery, and Repair

**Date:** 2026-04-02
**Status:** Research complete, ready for implementation
**Priority:** CRITICAL — Without this, corrupted state propagates silently and compounds
**Dependencies:** heartbeat.sh (exists), hooks (14 exist), git (initialized)
**Estimated Effort:** Phase A: 4-8 hours, Phase B: 6-10 hours, Phase C: 8-16 hours, Phase D: future

---

## 1. The Problem

OrgAgent has NO mechanism for detecting or recovering from state corruption. Five critical failure modes go undetected:

1. **Silent file corruption:** An agent writes a task file with invalid YAML frontmatter, a broken orgchart entry, or an inconsistent budget. No hook detects it. The error propagates through future heartbeat cycles.

2. **Agent invocation failures:** In `heartbeat.sh`, the `run_agent()` function uses `|| true` — ALL failures are silently swallowed. If the Claude invocation crashes, times out, or produces garbage, the script continues as if nothing happened.

3. **Cross-file inconsistency:** The orgchart references an agent that doesn't exist. A task's `assigned_to` points to a terminated agent. Budget allocations don't sum to the total. No validation catches these.

4. **No rollback capability:** If a heartbeat cycle corrupts state, there is no way to restore the previous good state. The only recovery is manual human intervention.

5. **No cascading failure detection:** If 3+ agents fail in the same heartbeat cycle, the cycle continues blindly. Workers act on stale or missing manager directives.

### What Hooks Currently Validate (and Don't)

| Hook | What It Validates | What It Does NOT Validate |
|---|---|---|
| `require-state-and-communication.sh` | current-state.md exists, has today's date | Content structure, YAML validity, required fields |
| `data-access-check.sh` | Agent stays within access paths | Path correctness, YAML validity of IDENTITY.md itself |
| `budget-check.sh` | Agent budget not exhausted | Budget consistency (allocations sum correctly) |
| `activity-logger.sh` | (Logging only) | Nothing — logs everything but validates nothing |
| `alignment-protect.sh` | No agent writes to alignment.md | alignment.md existence or validity |
| `message-routing-check.sh` | Chain-of-command for inbox writes | Message format validity, thread file existence |

**Critical gap: NO hook validates file content structure, YAML frontmatter correctness, cross-file consistency, or directory tree completeness.**

### What Happens When Agents Fail (heartbeat.sh analysis)

```bash
result=$(claude --agent "$agent_name" ... 2>&1) || true  # ALL errors silently swallowed
```

**Current failure handling gaps:**
1. No distinction between success and failure in `run_agent()`
2. No retry mechanism
3. No failure logging to audit-log.md
4. No circuit breaker (repeatedly crashing agents keep running, wasting budget)
5. No cascading failure detection
6. No post-phase validation (did the agent produce meaningful output?)
7. Failed agent cost is recorded as $0.00 (but API may have charged)

---

## 2. Research Findings

### 2.1 The Self-Healing Agent Pattern

**Source:** [DEV Community — Self-Healing Agent Pattern](https://dev.to/the_bookmaster/the-self-healing-agent-pattern-how-to-build-ai-systems-that-recover-from-failure-automatically-3945)

Four-stage recovery architecture:

**Stage 1 — Output Validation:** Validate agent outputs against explicit success criteria before acting.
- **OrgAgent mapping:** After each heartbeat phase, validate that agents produced expected files (current-state.md updated, thread messages written, task files in correct directories)

**Stage 2 — Failure Classification:** Classify failures into five categories:
| Category | OrgAgent Failure Mode | Recovery Action |
|---|---|---|
| Input corruption | Broken YAML frontmatter | Auto-repair schema, restore from git |
| Context starvation | Missing IDENTITY.md, SOUL.md | Restore from template or git checkpoint |
| Tool failure | Hook script error, filesystem permission | Log, retry once, skip with warning |
| Reasoning collapse | Agent produces garbage output | Terminate session, mark as `paused`, escalate |
| Output corruption | Partially written file (crash mid-write) | Detect via checksum, restore from git |

**Stage 3 — Contextual Recovery:** Different failures trigger different recovery paths.

**Stage 4 — Learning Integration:** Recovery events feed back into agent MEMORY.md.

**Reported results:** 73% reduction in silent failures, recovery time from hours to seconds, 91% decrease in manual intervention.

### 2.2 FAILURE.md and FAILSAFE.md Specifications

**Source:** [failure.md](https://failure.md/) and [failsafe.md](https://failsafe.md/)

**FAILURE.md** defines four failure modes with OrgAgent mapping:

1. **Graceful Degradation** (`continue_degraded`): Non-critical component unavailable. OrgAgent: a worker's budget is exhausted but the rest of the org continues. Heartbeat already skips agents with missing definitions; extend to skip budget-exhausted agents.

2. **Partial Failure** (`isolate_and_route_around`, max 3 retries with exponential backoff 5s→15s→60s): A component fails; route around it. OrgAgent: a manager crashes during Phase 2. Retry once, then reassign pending work to CEO or peer manager.

3. **Cascading Failure** (`circuit_breaker`, triggers: 3+ failures within 60 seconds): Multiple components fail simultaneously. OrgAgent: if 3+ agents fail in same cycle, create `org/.stop-org` and notify human.

4. **Silent Failure**: System produces output without detecting errors. **This is OrgAgent's biggest vulnerability.** An agent could write invalid YAML, a broken orgchart entry, or an inconsistent budget, and nothing detects it.

**FAILSAFE.md** defines safe fallback states:
- **Auto-Snapshots:** Every 30 minutes, on significant actions, retain last 10 snapshots
- **Safe State:** Revert to last clean git commit, stash uncommitted changes
- **Triggers:** unexpected_error_count threshold, data_integrity_failure, cost_spike (3x rolling average)

### 2.3 Git-Based Checkpoint/Restore

**Source:** [Eunomia — Checkpoint/Restore Systems for AI Agents](https://eunomia.dev/blog/2025/05/11/checkpointrestore-systems-evolution-techniques-and-applications-in-ai-agents/)

OrgAgent is in the best possible position for checkpointing because ALL state is filesystem-based markdown. No database, no in-memory state. A `git commit` IS a complete checkpoint.

**Recommended checkpoint strategy:**

```
Layer 1: Automatic git commit before each heartbeat cycle (in run-org.sh)
Layer 2: Automatic git commit after each phase (in heartbeat.sh)
Layer 3: Manual snapshots via /checkpoint skill (board-triggered)
```

**Implementation in run-org.sh:**
```bash
# Auto-checkpoint: snapshot org state before heartbeat
git add org/ 2>/dev/null
if ! git diff --cached --quiet; then
  git commit -m "checkpoint: pre-cycle-$CYCLE $(date -u +%Y-%m-%dT%H:%M:%S)" --no-gpg-sign 2>/dev/null || true
fi
```

**Rollback mechanism:**
```bash
git log --oneline --grep="checkpoint:" -n 20  # List recent checkpoints
git checkout <commit-hash> -- org/              # Restore org/ from checkpoint
git commit -m "rollback: restored from <commit-hash>"
```

**Idempotency concern** (from [ACRFence research](https://arxiv.org/html/2603.20625v1)): When rolling back and re-running an agent, it might create different tasks or send different messages. Mitigation: after rollback, the re-run agent gets explicit context: "You are being re-run after a failure. The following actions from your previous run have been rolled back: [list]."

### 2.4 Resilience Patterns from Distributed Systems

**Source:** [DEV Community — 4 Fault Tolerance Patterns](https://dev.to/klement_gunndu/4-fault-tolerance-patterns-every-ai-agent-needs-in-production-jih)

**Pattern 1 — Retry with Exponential Backoff:** In heartbeat.sh, when `run_agent()` fails, retry once with 5-second delay before logging the failure.

**Pattern 2 — Model Fallback Chains:** If an agent's configured model is unavailable, fall back to a lower-tier model. Add `fallback_model` field to IDENTITY.md.

**Pattern 3 — Error Classification and Routing:** Classify failures into: transient (retry), LLM-recoverable (restart with fresh context), user-fixable (notify human), unexpected (log and escalate).

**Pattern 4 — Circuit Breaker:** Three states: CLOSED (normal), OPEN (failing — skip agent), HALF_OPEN (testing recovery). Track consecutive failures per agent.

**Reported impact:** Unrecoverable failures dropped from 23% to under 2%.

**Circuit breaker implementation:**
```bash
# Per-agent circuit breaker state: org/agents/{name}/.circuit-breaker
# Format: state:failure_count:last_failure_timestamp:last_success_timestamp

check_circuit_breaker() {
  if [[ ! -f "$BREAKER_FILE" ]]; then echo "CLOSED"; return; fi
  local state=$(cut -d: -f1 "$BREAKER_FILE")
  local failures=$(cut -d: -f2 "$BREAKER_FILE")
  local last_fail=$(cut -d: -f3 "$BREAKER_FILE")
  local now=$(date +%s)
  
  if [[ "$state" == "OPEN" ]]; then
    if (( now - last_fail > RECOVERY_TIMEOUT )); then
      echo "HALF_OPEN"  # Try once
    else
      echo "OPEN"  # Still failing — skip
    fi
  elif [[ "$state" == "CLOSED" && "$failures" -ge "$FAILURE_THRESHOLD" ]]; then
    echo "OPEN"
  else
    echo "CLOSED"
  fi
}
```

### 2.5 Multi-Agent Failure Recovery

**Source:** [Galileo — Multi-Agent AI System Failure Recovery](https://galileo.ai/blog/multi-agent-ai-system-failure-recovery)

- **Behavioral Anomaly Detection:** Monitor interaction success rates, response times, error frequency. OrgAgent implementation: if an agent's output size drops below 10% of average, or if it writes 0 thread messages when normally writes 3+, flag it.
- **Circuit Breakers Between Clusters:** Per-phase circuit breakers. If Phase 2 (Managers) produces 2+ failures, do NOT proceed to Phase 3.
- **Staged Recovery Sequencing:** Restore agents in heartbeat order: Alignment Board first, then CEO, then managers, then workers, then CAO.

### 2.6 Agents of Chaos (Red-Teaming Study)

**Source:** [arXiv:2602.20021 — Agents of Chaos](https://bigcodegen.medium.com/agents-of-chaos-when-helpful-ai-agents-turn-destructive-in-multi-agent-reality-d71e2771fcda)

Relevant failure modes for OrgAgent:
- **Cross-Agent Relay Loops:** Two agents bouncing tasks back and forth. Mitigation: track message frequency per thread per agent pair, break loops after 5 round-trips.
- **Resource Exhaustion:** Agent repeatedly creating large files. Mitigation: monitor `org/` directory size per-agent.
- **Vulnerability Propagation:** Malicious instructions in shared files. Mitigation: Alignment Board scans thread content for anomalous directives.

**Critical insight:** "Local alignment does not guarantee global stability." Individual agent safety checks are necessary but insufficient. Self-healing must detect *emergent* multi-agent failures.

### 2.7 Filesystem Consistency Validation (What Makes a "Valid" File)

From TO-DO/10-FILE-FORMAT-SPECIFICATIONS.md, 26 file formats with strict field requirements. Key cross-file consistency invariants:

1. **Every agent in orgchart.md with status `active` must have:** directory at `org/agents/{name}/`, all 5 identity files, all required subdirectories, an agent definition at `.claude/agents/{name}.md`
2. **Every agent's `reports_to` in IDENTITY.md must match the orgchart hierarchy**
3. **Budget `total_allocated_usd` must equal sum of all agent allocations**
4. **Spending-log running total must match `total_spent_usd` in budget overview**
5. **Task file `status` field must match its directory** (backlog/ for `backlog`, etc.)
6. **Task `assigned_to` must reference an active agent**
7. **Every thread referenced in a notification's `thread_path` must exist**
8. **No agent with `status: terminated` should have unread inbox notifications or active tasks**

---

## 3. Recommended Self-Healing Architecture

### Phase A: Foundation (4-8 hours, HIGH impact)

**A1. Integrity Checker Script (`scripts/integrity-check.sh`)**

A bash script that validates the entire `org/` tree. Runs as the first step of every heartbeat cycle (before Phase 0).

**Checks:**
- Required directories exist for every active agent
- Required files exist (SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY)
- YAML frontmatter parses correctly (using `yq` or grep-based extraction)
- Required fields present per file type
- Cross-file consistency (orgchart references match IDENTITY.md `reports_to`)
- Budget arithmetic (allocations sum correctly, remaining = total - spent)
- Task files in correct directories for their status
- No orphan agents (in orgchart but no workspace, or workspace but not in orgchart)

**Output:** JSON report with `{status: "healthy"|"degraded"|"critical", issues: [...], auto_repaired: [...]}`. Exit code 0 = healthy, 1 = degraded (some issues auto-repaired), 2 = critical (manual intervention needed).

**A2. Git Checkpoints in run-org.sh and heartbeat.sh**

Auto-commit `org/` before each heartbeat cycle and after each phase. Provides complete rollback capability.

```bash
# In run-org.sh, before each cycle:
checkpoint_org() {
  git add org/ 2>/dev/null
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -m "checkpoint: pre-cycle-$1 $(date -u +%Y-%m-%dT%H:%M:%S)" 2>/dev/null || true
  fi
}
```

**A3. Improved Error Handling in heartbeat.sh**

Replace `|| true` with proper error handling:

```bash
run_agent() {
  local agent_name="$1"
  local exit_code=0
  
  result=$(claude --agent "$agent_name" ... 2>&1) || exit_code=$?
  
  if [[ "$exit_code" -ne 0 ]]; then
    echo "[$(date)] ERROR: Agent $agent_name failed with exit code $exit_code" >&2
    # Log to audit trail
    echo "| $(date -u +%H:%M:%S) | $agent_name | heartbeat | FAILED | exit code $exit_code |" >> "$ORG_DIR/board/audit-log.md"
    # Update circuit breaker
    record_failure "$agent_name"
    return 1
  fi
  
  # Reset circuit breaker on success
  record_success "$agent_name"
  return 0
}
```

With retry:
```bash
run_agent_with_retry() {
  local agent_name="$1"
  local max_retries=1
  local retry_delay=5
  
  for attempt in $(seq 0 $max_retries); do
    if [[ "$attempt" -gt 0 ]]; then
      echo "[$(date)] Retrying $agent_name (attempt $((attempt + 1))/$((max_retries + 1)))..."
      sleep "$retry_delay"
    fi
    if run_agent "$agent_name"; then
      return 0
    fi
  done
  
  echo "[$(date)] Agent $agent_name failed after $((max_retries + 1)) attempts" >&2
  return 1
}
```

### Phase B: Detection & Response (6-10 hours, MEDIUM impact)

**B1. Per-Agent Circuit Breaker**

Track consecutive failures in `org/agents/{name}/.circuit-breaker`. Skip agents that have failed 3+ consecutive times. Reset on success. Recovery timeout: 5 minutes (try again after cooldown).

**B2. Cascading Failure Detection**

In heartbeat.sh, count failures per phase. If total failures exceed threshold (configurable, default: 2):
```bash
if [[ "$phase_failures" -ge "$CASCADE_THRESHOLD" ]]; then
  echo "[$(date)] CASCADING FAILURE: $phase_failures agents failed in Phase $phase" >&2
  touch "$ORG_DIR/.stop-org"
  echo "| $(date -u +%H:%M:%S) | system | heartbeat | CASCADING FAILURE | Phase $phase: $phase_failures failures |" >> "$ORG_DIR/board/audit-log.md"
  # Restore from pre-cycle checkpoint
  git checkout HEAD -- org/
fi
```

**B3. Post-Phase Validation**

After each phase, verify agents modified their expected files:
- current-state.md has today's date
- If tasks were in backlog, at least one was touched
- Thread messages were written (if tasks were worked on)

**B4. Recovery Log (`org/board/recovery-log.md`)**

Append-only log of all self-healing actions: what was detected, what was repaired, what was escalated.

### Phase C: Auto-Repair (8-16 hours, HIGH impact)

**C1. YAML Frontmatter Auto-Repair**

Common issues the integrity checker can fix automatically:
- Missing closing `---` delimiter → add it
- Tab characters in YAML → replace with spaces
- Trailing whitespace → strip
- Missing required fields → add with default values from schema
- If unfixable → restore from last git checkpoint

**C2. Orgchart Consistency Repair**

- Agent workspace exists but not in orgchart → add with `(unknown)` status, alert CAO
- Agent in orgchart but no workspace → mark as `(broken)`, alert CAO
- `reports_to` mismatch → update IDENTITY.md to match orgchart hierarchy

**C3. Budget Recalculation**

If budget totals don't match: recalculate from spending-log.md and update overview.md.

**C4. Automatic Rollback on Cascading Failure**

When cascading failure is detected, restore `org/` from the pre-cycle git checkpoint and notify the human.

### Phase D: Advanced (Future)

**D1. `/health-check` Skill** — Board-triggered comprehensive health assessment with human-readable report.

**D2. `/rollback` Skill** — Board-triggered rollback to a named checkpoint.

**D3. `/chaos-test` Skill** — Controlled fault injection for testing self-healing:
- Corrupt a YAML frontmatter field → verify integrity checker catches it
- Delete an agent's IDENTITY.md → verify graceful degradation
- Set agent budget to $0 → verify skip
- Create circular reporting chain → verify detection

**D4. Health Dashboard Tab** — GUI display of agent health, circuit breaker states, recovery log.

**D5. Predictive Failure Detection** — Track trends across cycles (increasing error rates, declining output quality) and alert before failures occur.

---

## 4. New Files

| File | Purpose |
|---|---|
| `scripts/integrity-check.sh` | Full org state validation script |
| `scripts/hooks/integrity-precheck.sh` | Pre-write YAML validation hook (optional) |
| `.claude/skills/health-check/SKILL.md` | Board-triggered health assessment |
| `.claude/skills/rollback/SKILL.md` | Board-triggered state rollback |
| `org/board/recovery-log.md` | Append-only recovery action log |

## 5. Modified Files

| File | Change |
|---|---|
| `scripts/heartbeat.sh` | Error handling, retry, circuit breaker, phase failure counting, post-phase validation, integrity check call |
| `scripts/run-org.sh` | Git checkpoints before each cycle, cascading failure detection |
| `.claude/settings.json` | Register integrity-precheck hook (optional) |

---

## 6. Architecture Decisions

### Decision 63: Git-Based Automatic Checkpoints
**Decision:** Auto-commit `org/` before each heartbeat cycle and after each phase. Git history provides complete rollback capability with zero additional tooling.
**Reasoning:** All OrgAgent state is filesystem-based markdown. A git commit IS a complete checkpoint. No database snapshots, no serialization — just `git add org/ && git commit`. The project is already a git repository.

### Decision 64: Three-Level Failure Response in heartbeat.sh
**Decision:** Classify agent invocation failures into three levels: transient (retry once with 5s delay), persistent (circuit breaker after 3 failures), cascading (halt org if 2+ agents fail in one phase).
**Reasoning:** Different failure severities require different responses. A transient API timeout should be retried. A persistently crashing agent should be skipped to save budget. Multiple simultaneous failures indicate a systemic issue requiring human intervention.

### Decision 65: Integrity Checker as Phase -1
**Decision:** Run `integrity-check.sh` as the first step of every heartbeat cycle, before the Alignment Board (Phase 0). Structural health checking precedes governance review.
**Reasoning:** The Alignment Board reviews proposals and detects behavioral drift, but it cannot detect structural corruption (broken YAML, missing files, inconsistent budget). A dedicated integrity check catches these before any agent runs with potentially corrupted state.

### Decision 66: Auto-Repair for Known Patterns, Escalate for Unknown
**Decision:** The integrity checker automatically repairs common corruption patterns (missing YAML delimiters, tab characters, missing required fields with defaults). Unknown or complex corruption is logged and escalated to the human.
**Reasoning:** Most corruption is minor and has deterministic fixes. Auto-repair prevents minor issues from cascading. But the system should never guess at complex repairs — human judgment is needed for non-trivial state restoration.

### Decision 67: Recovery Log as Audit Trail
**Decision:** All self-healing actions are logged to `org/board/recovery-log.md` — an append-only log with timestamps, what was detected, what was repaired, and what was escalated.
**Reasoning:** Self-healing should be transparent. The human board must be able to see every automated repair and assess whether the system is stable. Recovery patterns over time indicate systemic issues that need design-level fixes.

---

## 7. Sources

- [Self-Healing Agent Pattern (DEV Community)](https://dev.to/the_bookmaster/the-self-healing-agent-pattern-how-to-build-ai-systems-that-recover-from-failure-automatically-3945)
- [FAILURE.md Protocol](https://failure.md/)
- [FAILSAFE.md Standard](https://failsafe.md/)
- [4 Fault Tolerance Patterns (DEV Community)](https://dev.to/klement_gunndu/4-fault-tolerance-patterns-every-ai-agent-needs-in-production-jih)
- [Multi-Agent AI Failure Recovery (Galileo)](https://galileo.ai/blog/multi-agent-ai-system-failure-recovery)
- [Agents of Chaos (arXiv:2602.20021)](https://bigcodegen.medium.com/agents-of-chaos-when-helpful-ai-agents-turn-destructive-in-multi-agent-reality-d71e2771fcda)
- [Checkpoint/Restore Systems for AI Agents (Eunomia)](https://eunomia.dev/blog/2025/05/11/checkpointrestore-systems-evolution-techniques-and-applications-in-ai-agents/)
- [ACRFence: Semantic Rollback Attacks (arXiv)](https://arxiv.org/html/2603.20625v1)
- [Circuit Breaker Pattern (AWS)](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/circuit-breaker.html)
- [Chaos Engineering for AI Agents (DEV Community)](https://dev.to/franciscohumarang/why-chaos-engineering-is-the-missing-layer-for-reliable-ai-agents-in-cicd-3mnd)
- [Exception Handling in Agentic AI](https://atalupadhyay.wordpress.com/2026/03/16/exception-handling-and-recovery-in-agentic-ai/)
- [Kitaru: Open Source Agent Infrastructure (ZenML)](https://www.zenml.io/blog/kitaru-launch)
- [Configuration Drift Detection (Spacelift)](https://spacelift.io/blog/what-is-configuration-drift)
- [frontmatter-validator (GitHub)](https://github.com/vinicioslc/frontmatter-validator)
