# Gap Analysis — Implementation Specifications

**Date:** 2026-04-02
**Purpose:** Comprehensive implementation plans for closing the 6 identified gaps between OrgAgent's current state (~35% autonomous) and its target state (~75% autonomous).
**Total Architecture Decisions:** 28 new decisions (Decisions 53-80)
**Total Lines of Specification:** 2,918 lines across 6 documents

---

## Gap Documents

| # | Document | Lines | Priority | Key Deliverable |
|---|----------|-------|----------|-----------------|
| 04 | [Long-Running Processes](GAP-04-LONG-RUNNING-PROCESSES.md) | 588 | HIGH | GUI webhook endpoint + n8n integration + Claude Code Channels |
| 05 | [Memory Scaling](GAP-05-MEMORY-SCALING.md) | 425 | HIGH | `/consolidate-memory` skill + tiered archival + shared knowledge base |
| 06 | [Self-Healing](GAP-06-SELF-HEALING.md) | 420 | CRITICAL | `integrity-check.sh` + git checkpoints + circuit breakers + auto-repair |
| 07 | [Coordination Scaling](GAP-07-COORDINATION-SCALING.md) | 380 | HIGH | `has_pending_work()` pre-check + department sub-heartbeats |
| 08 | [External Feedback Loops](GAP-08-EXTERNAL-FEEDBACK-LOOPS.md) | 458 | HIGH | `org/outcomes/` + `/retrospective` skill + measurable KRs |
| 13 | [Testing Infrastructure](GAP-13-TESTING-INFRASTRUCTURE.md) | 647 | HIGH | bats-core + vitest + zod schemas + ~240 test cases |

---

## Implementation Order (Recommended)

### Wave 1: Foundation (Week 1-2)
1. **GAP-13 Phase 1:** Governance hook tests — validates the trust model before any changes
2. **GAP-06 Phase A:** Integrity checker + git checkpoints — safety net for all subsequent work
3. **GAP-07 Proposal A:** Filesystem pre-check — immediate 60-80% cost savings

### Wave 2: Core Capabilities (Week 2-4)
4. **GAP-04 Layer 1:** GUI webhook endpoint — enables event reception
5. **GAP-05 Phase 1:** Memory consolidation skill — prevents knowledge loss
6. **GAP-08 Phase 1:** Outcome tracking — closes the feedback loop
7. **GAP-13 Phase 2:** GUI API + schema tests — validates dashboard correctness

### Wave 3: Advanced (Week 4-8)
8. **GAP-07 Proposal B:** Department sub-heartbeats — structural scaling
9. **GAP-06 Phase B:** Circuit breakers + cascading failure detection
10. **GAP-04 Layer 2:** n8n integration pattern — robust external connectivity
11. **GAP-05 Phase 2:** Hierarchical consolidation — long-term memory health

### Wave 4: Future (Month 2+)
12. **GAP-04 Layer 3:** Claude Code Channels (when GA)
13. **GAP-05 Phase 3-4:** Semantic search, shared knowledge base
14. **GAP-06 Phase C-D:** Auto-repair, chaos testing, health dashboard
15. **GAP-08 Phase 3:** A/B testing, automated metrics, belief decay

---

## New Architecture Decisions Summary

| Decision | Gap | Title |
|----------|-----|-------|
| 53 | GAP-04 | Sidecar event reception via GUI server extension |
| 54 | GAP-04 | n8n as primary integration engine |
| 55 | GAP-04 | Claude Code Channels for real-time board notification |
| 56 | GAP-04 | Idempotency keys on all event files |
| 57 | GAP-04 | Three-tier urgency for event processing |
| 58 | GAP-05 | Tiered memory consolidation (daily → weekly → monthly) |
| 59 | GAP-05 | MEMORY.md as index with topic files |
| 60 | GAP-05 | Archive, never delete |
| 61 | GAP-05 | Shared organizational knowledge base |
| 62 | GAP-05 | CAO as consolidation agent |
| 63 | GAP-06 | Git-based automatic checkpoints |
| 64 | GAP-06 | Three-level failure response |
| 65 | GAP-06 | Integrity checker as Phase -1 |
| 66 | GAP-06 | Auto-repair for known patterns, escalate for unknown |
| 67 | GAP-06 | Recovery log as audit trail |
| 68 | GAP-07 | Filesystem pre-check before agent invocation |
| 69 | GAP-07 | CEO, CAO, Alignment Board always run |
| 70 | GAP-07 | Department-level sub-heartbeats |
| 71 | GAP-07 | Configurable heartbeat mode |
| 72 | GAP-08 | Task assigner measures outcomes |
| 73 | GAP-08 | Extended task status (done → measured → closed) |
| 74 | GAP-08 | Outcome records as separate files |
| 75 | GAP-08 | Retrospectives as CEO heartbeat responsibility |
| 76 | GAP-08 | Confidence scoring on all outcomes |
| 77 | GAP-13 | bats-core for bash, Vitest for JavaScript |
| 78 | GAP-13 | Test fixtures as minimal valid org |
| 79 | GAP-13 | Governance hooks are highest test priority |
| 80 | GAP-13 | Schema validation serves double duty |

---

## New Files Summary

| File | Gap | Purpose |
|------|-----|---------|
| `gui/api/webhooks.js` | GAP-04 | Webhook receiver API module |
| `sidecar/webhook-channel.ts` | GAP-04 | Claude Code Channel server (future) |
| `ecosystem.config.js` | GAP-04 | PM2 process fleet config (optional) |
| `.claude/skills/consolidate-memory/SKILL.md` | GAP-05 | Memory consolidation skill |
| `scripts/hooks/memory-size-check.sh` | GAP-05 | MEMORY.md size enforcement hook |
| `scripts/integrity-check.sh` | GAP-06 | Full org state validation |
| `.claude/skills/health-check/SKILL.md` | GAP-06 | Board-triggered health assessment |
| `.claude/skills/rollback/SKILL.md` | GAP-06 | Board-triggered state rollback |
| `org/board/recovery-log.md` | GAP-06 | Recovery action audit trail |
| `.claude/skills/retrospective/SKILL.md` | GAP-08 | Periodic outcome review |
| `.claude/skills/measure-outcome/SKILL.md` | GAP-08 | Outcome recording workflow |
| `tests/` (entire directory) | GAP-13 | ~240 test cases |
| `tests/schemas/` | GAP-13 | Reusable Zod schemas for 26 file formats |
| `.github/workflows/test.yml` | GAP-13 | CI pipeline |

## New Directories Summary

| Directory | Gap | Purpose |
|-----------|-----|---------|
| `org/knowledge/` | GAP-05 | Shared organizational knowledge base |
| `org/agents/*/memory/weekly/` | GAP-05 | Weekly memory consolidation |
| `org/agents/*/memory/monthly/` | GAP-05 | Monthly memory consolidation |
| `org/agents/*/memory/archive/` | GAP-05 | Archived daily memory logs |
| `org/agents/*/activity/archive/` | GAP-05 | Archived activity streams |
| `org/outcomes/` | GAP-08 | Outcome measurement records |
| `org/retrospectives/` | GAP-08 | Periodic review documents |
| `org/health/` | GAP-06 | Per-agent health status (future) |

---

## Estimated Autonomy Impact

| Gap | Current | After Fix | Dimension |
|-----|---------|-----------|-----------|
| GAP-04 | 4/10 | 7/10 | External Integration & Real-Time Response |
| GAP-05 | 3/10 | 7/10 | Memory & Learning |
| GAP-06 | 2/10 | 7/10 | Self-Healing & Resilience |
| GAP-07 | 5/10 | 8/10 | Task Execution & Scaling |
| GAP-08 | 3/10 | 7/10 | Real-World Impact & Learning |
| GAP-13 | 0/10 | 7/10 | Confidence & Reliability |

**Projected overall autonomy after all gaps closed: ~55-60%** (up from ~35%)

The remaining 15-25% to reach the 75% theoretical ceiling requires:
- Running the org end-to-end and iterating on real-world issues
- Building actual external connectors (proving the autonomy thesis)
- Multiple heartbeat cycles of operational experience
- Community feedback and edge case discovery
