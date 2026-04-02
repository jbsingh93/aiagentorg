# GAP-05: Memory Doesn't Scale — Memory Management Layer

**Date:** 2026-04-02
**Status:** Research complete, ready for implementation
**Priority:** HIGH — Without this, agents lose institutional knowledge as the org grows
**Dependencies:** CAO heartbeat (exists), MEMORY.md format (exists), activity stream (exists)
**Estimated Effort:** Phase 1: 4-6 hours, Phase 2: 6-10 hours, Phase 3: 8-16 hours, Phase 4: future

---

## 1. The Problem

Each agent has `MEMORY.md` (permanent knowledge) and `activity/YYYY-MM-DD.md` (daily activity logs). As the org operates for weeks/months:

1. **MEMORY.md grows unbounded** — the spec says "under 200 lines" but there is NO enforcement, NO pruning mechanism, and NO consolidation process
2. **Activity streams accumulate forever** — daily log files pile up with no archival. An agent active for 90 days has 90 activity files loaded into context scans
3. **Daily memory logs in `memory/YYYY-MM-DD.md` pile up** — the spec mentions them but defines no lifecycle management
4. **No distinction between critical and noise** — a founding decision and a routine task update have equal weight in MEMORY.md
5. **No semantic search** — finding a specific memory from 3 months ago requires grepping through dozens of files
6. **No cross-agent knowledge transfer** — when one agent learns something valuable, other agents don't benefit
7. **Context windows fill up** — agents load SOUL + IDENTITY + INSTRUCTIONS + HEARTBEAT + MEMORY + recent activity. As MEMORY.md grows, the effective context budget for actual work shrinks

### Current Architecture (from codebase analysis)

- `org/agents/{name}/MEMORY.md` — Curated persistent knowledge index. Currently 20-30 lines for each of the 3 agents. Spec says <200 lines, agent prunes during heartbeat step 9
- `org/agents/{name}/memory/YYYY-MM-DD.md` — Daily episodic memory. Contains sections for each heartbeat cycle with Inbox, Tasks, Decisions, and Budget subsections
- `org/agents/{name}/activity/YYYY-MM-DD.md` — Hook-generated, immutable, one table row per file operation. Objective logs
- `org/agents/{name}/activity/current-state.md` — Real-time cognitive state. Overwritten each session
- Architecture Decision #5: Workspace memory as ONLY memory system. Claude Code auto-memory disabled for agents (`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`)

---

## 2. Research Findings

### 2.1 Memory Taxonomy — The Field Has Converged

The academic community (CoALA framework, Princeton 2023, universally adopted by 2026) has converged on a taxonomy from cognitive science:

| Memory Type | Human Analogy | OrgAgent Equivalent | Purpose |
|---|---|---|---|
| **Working Memory** | RAM / current focus | `activity/current-state.md` + context window | What the agent is thinking right now |
| **Episodic Memory** | Personal diary | `memory/YYYY-MM-DD.md` + `activity/YYYY-MM-DD.md` | Timestamped experiences and events |
| **Semantic Memory** | Encyclopedia | `MEMORY.md` | Abstracted facts, preferences, rules |
| **Procedural Memory** | Muscle memory | `INSTRUCTIONS.md` + `HEARTBEAT.md` | How to do things |

**Key insight:** OrgAgent already has natural analogs for ALL four types. The gap is in the lifecycle management — how episodic memory consolidates into semantic memory, and how old episodic records are managed.

**Critical finding from survey paper** (arxiv.org/abs/2603.07670): "Long context is not memory. Despite context windows stretching to 200k tokens, long-context models consistently underperform purpose-built memory systems on tasks requiring selective retrieval and active management."

**Sources:**
- [CoALA: Cognitive Architectures for Language Agents](https://arxiv.org/abs/2309.02427)
- [Memory for Autonomous LLM Agents: Mechanisms, Evaluation, and Emerging Frontiers](https://arxiv.org/html/2603.07670)
- [Memory in the Age of AI Agents (Survey, Dec 2025)](https://arxiv.org/abs/2512.13564)
- [A Survey on the Memory Mechanism of LLM-based Agents](https://dl.acm.org/doi/10.1145/3748302)

### 2.2 Key Frameworks (SOTA 2025-2026)

**Mem0** (Production-ready, 2025): Three-stage pipeline — Extraction, Consolidation (ADD/UPDATE/DELETE/NOOP), Retrieval. Uses vector embeddings for semantic similarity. Achieves 26% accuracy improvement over OpenAI, 91% lower latency, 90%+ token cost savings. Graph variant (Mem0g) uses Neo4j for relational structures.

**A-MEM** (Agentic Memory, 2025): Based on Zettelkasten note-taking. Each memory note has structured attributes (keywords, tags, contextual descriptions). Dynamic linking based on embedding similarity and LLM reasoning. Memory notes evolve — new memories trigger contextual updates to existing entries.

**MemGPT/Letta** (OS-inspired, 2023-2026): Three-tier virtual memory — Core Memory (always in context), Recall Memory (searchable database of past messages), Archival Memory (vector-indexed long-term storage). The agent explicitly manages its own memory via function calls.

**Generative Agents** (Stanford, 2023): Memory stream with reflection. Periodically clusters related observations and synthesizes higher-order reflections. Retrieval uses triple scoring: recency * importance * relevance.

**ExpeL** (Experiential Learning, 2023-2025): Contrasts successful and failed trajectories, extracting discriminative "rules of thumb" stored as reusable heuristics. No parameter updates — works with API-based models.

**Sources:**
- [Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory](https://arxiv.org/abs/2504.19413)
- [A-MEM: Agentic Memory for LLM Agents](https://arxiv.org/abs/2502.12110)
- [MemGPT: Towards LLMs as Operating Systems](https://arxiv.org/abs/2310.08560)
- [Generative Agents: Interactive Simulacra of Human Behavior](https://arxiv.org/abs/2304.03442)
- [ExpeL: LLM Agents Are Experiential Learners](https://arxiv.org/abs/2308.10144)
- [The 6 Best AI Agent Memory Frameworks You Should Try in 2026](https://machinelearningmastery.com/the-6-best-ai-agent-memory-frameworks-you-should-try-in-2026/)

### 2.3 Memory Consolidation Patterns

The field formalizes memory as a **write-manage-read loop**:

1. **Formation (Extraction)**: Filtering low-signal records, canonicalization (normalizing dates/quantities), deduplication, priority scoring, metadata tagging
2. **Evolution (Consolidation & Forgetting)**: Merging related information, resolving conflicts, decay-based pruning, hierarchical compression
3. **Retrieval (Access)**: Multi-stage retrieval (fast BM25/metadata filter, then slower cross-encoder reranker), retrieval-or-not gating

**Consolidation Mechanisms:**

- **Rolling Summaries**: Periodically condense older history into shorter summaries. Risk: "summarization drift" — each compression pass silently discards low-frequency details
- **Hierarchical Summaries**: Day → Week → Month → Quarter. Each level preserves different detail levels
- **Reflective Consolidation** (Generative Agents): Cluster related observations and synthesize higher-order reflections. Not just summarization — produces new insights
- **Dual-Buffer Consolidation**: New memories in "hot" buffer during probation. Promoted to long-term after quality checks
- **ExpeL Rules Extraction**: Contrast successful vs failed trajectories, extract reusable heuristics

**Decay and Forgetting:**

**Ebbinghaus Forgetting Curve**: `R = importance * e^(-decay_rate * t)` where `decay_rate = 0.16 * (1 - importance * 0.8)`. High-importance memories decay slowly (months), low-importance decay fast (days).

**FadeMem Dual-Layer Architecture**:
- Long-Term Memory Layer (importance >= 0.7): slow decay, persists months
- Short-Term Memory Layer (importance < 0.7): fast decay, fades within days
- Result: retains more of what matters using 45% less storage

**Tiered TTL Strategy:**

| Memory Type | TTL | Importance Range |
|---|---|---|
| Critical facts | 365 days | 0.85-1.0 |
| Project context | 30 days | 0.7-0.85 |
| Session interactions | 7 days | 0.3-0.7 |
| Casual content | 3 days | < 0.3 |

**What to never auto-prune:** Hard preferences ("always", "never"), critical business rules, core strategic decisions, agent hiring/firing context, alignment-relevant decisions.

**What to forget automatically:** One-off technical queries, typos and corrections, outdated project context, session-level operational details.

**Sources:**
- [Mastering Memory Consistency in AI Agents: 2025 Insights](https://sparkco.ai/blog/mastering-memory-consistency-in-ai-agents-2025-insights)
- [AI Agent Memory Part 2: The Case for Intelligent Forgetting](https://dev.to/sudarshangouda/ai-agent-memory-part-2-the-case-for-intelligent-forgetting-4i48)
- [Mem0 Blog: LLM Chat History Summarization Guide](https://mem0.ai/blog/llm-chat-history-summarization-guide-2025)

### 2.4 Claude Code's Own Memory System — Auto Dream

Claude Code has an Auto Dream consolidation mechanism (v2.1.83+). Triggers when BOTH conditions met:
- 24 hours elapsed since last consolidation
- 5+ sessions completed since last consolidation

Four-phase process:
1. **Orientation**: Scan memory directory, map existing knowledge structure
2. **Gather Signal**: Search for user corrections, explicit saves, recurring themes, important decisions
3. **Consolidation**: Convert relative dates to absolute, remove contradicted facts, delete stale notes, merge overlapping entries
4. **Prune and Index**: Update MEMORY.md under the strict 200-line limit

**Key learning for OrgAgent:** The 200-line MEMORY.md limit is already in OrgAgent's spec. The topic-file pattern (moving detail to separate files, keeping MEMORY.md as an index) maps perfectly. OrgAgent must implement its own "dream" phase since auto-dream is disabled for agents (Decision 5).

**Sources:**
- [How Claude Remembers Your Project — Official Docs](https://code.claude.com/docs/en/memory)
- [Anthropic Tests 'Auto Dream' to Clean Up Claude's Memory](https://tessl.io/blog/anthropic-tests-auto-dream-to-clean-up-claudes-memory/)
- [Claude Code Dreams: Auto Dream Feature](https://claudefa.st/blog/guide/mechanics/auto-dream)

### 2.5 Semantic Search Over Markdown Files

**Striking finding:** Manus, OpenClaw, and Claude Code all use plain Markdown files as their primary memory system, not managed vector databases. The vector index is a derived capability — the files are always the source of truth.

**Options for OrgAgent:**

| Option | Approach | Dependencies | Best For |
|---|---|---|---|
| **A: Grep-only** | Keyword search via Grep/Glob tools | None | Small orgs (<100 memory files) |
| **B: Grep + LLM** | Grep candidates, LLM judges relevance | None | Medium orgs (100-500 files) |
| **C: sqlite-vec** | Local vector index over markdown files | sqlite-vec npm | Large orgs (500+ files) |
| **D: Full vector DB** | Milvus/Chroma external database | External server | Violates "no external database" constraint |

**Recommendation:** Start with **Option A** (Grep) — design memory files to be grep-friendly (consistent headers, keyword tags, frontmatter). Add **Option C** (sqlite-vec) as an optional enhancement when orgs scale beyond hundreds of memory files.

**Sources:**
- [The Markdown File That Beat a $50M Vector Database](https://medium.com/@Micheal-Lanham/the-markdown-file-that-beat-a-50m-vector-database-38e1f5113cbe)
- [OpenClaw Memory Masterclass](https://velvetshark.com/openclaw-memory-masterclass)
- [Memsearch (Zilliz/Milvus open-source)](https://github.com/zilliztech/memsearch)

### 2.6 Multi-Agent Memory Sharing

Two extremes: "all memory is shared" (leaks private info) vs "each agent maintains its own store" (prevents knowledge transfer). OrgAgent already has a nuanced middle ground via `access_read`/`access_write` permissions. But it lacks:
- Organizational knowledge base (shared semantic memory)
- Cross-agent learning transfer
- Memory consistency protocols

**Proposed Shared Memory Architecture:**

| Layer | Location | Read Access | Write Access |
|---|---|---|---|
| Private Agent Memory | `org/agents/{name}/MEMORY.md` | Self + supervisor + CEO/CAO | Self only |
| Department Knowledge Base | `org/knowledge/{department}/` | All department members | Department manager |
| Organizational Knowledge Base | `org/knowledge/org-wide/` | Managers + CEO + CAO + Board | CEO + Board |

**Sources:**
- [Multi-Agent Memory from a Computer Architecture Perspective](https://arxiv.org/html/2603.10062v1)
- [Collaborative Memory: Multi-User Memory Sharing with Dynamic Access Control](https://openreview.net/forum?id=pJUQ5YA98Z)

---

## 3. New Directory Structure

```
org/agents/{name}/
  MEMORY.md                          # Semantic memory (index, <200 lines)
  memory/
    YYYY-MM-DD.md                    # Daily episodic memory (existing)
    weekly/
      YYYY-WNN.md                    # Weekly consolidation summaries (NEW)
    monthly/
      YYYY-MM.md                     # Monthly consolidation summaries (NEW)
    archive/
      YYYY-MM-DD.md                  # Archived daily files post-consolidation (NEW)
  activity/
    current-state.md                 # Working memory (existing)
    YYYY-MM-DD.md                    # Activity stream (existing)
    archive/
      YYYY-MM-DD.md                  # Archived activity files >30 days (NEW)

org/knowledge/                       # NEW: Shared knowledge base
  org-wide/
    decisions.md                     # Major org decisions and reasoning
    patterns.md                      # Cross-department patterns
    lessons-learned.md               # What worked, what didn't
  {department}/
    best-practices.md                # Department-specific knowledge
    process-notes.md                 # How things are done here
```

---

## 4. Enhanced MEMORY.md Format

```markdown
---
agent: marketing-manager
last_consolidated: 2026-04-15
consolidation_count: 3
total_daily_logs: 21
archived_before: 2026-03-25
---

# Memory — Marketing Manager

## Key Facts
<!-- importance: critical, never auto-prune -->
- Org language: Danish (da) — all external content must be in Danish
- Q2 focus: organic traffic growth (30% target)
- Budget: 500 DKK/month allocated, conservative spending required

## Strategic Decisions
<!-- importance: high, prune after 3 months -->
- 2026-04-01: SEO-first approach for Q2 (organic > social for first 2 weeks)
- 2026-04-08: Instagram chosen as primary social channel (highest Danish engagement)

## Learnings
<!-- importance: medium, prune after 2 months -->
- CEO prefers concise reports (under 50 lines)
- SEO Agent works best with specific, measurable task descriptions
- Social media content performs better Tuesday-Thursday

## Active Context
<!-- importance: variable, refresh each consolidation -->
- Content calendar deadline: 2026-04-15
- Waiting on SEO Agent keyword research v2

## Process Heuristics
<!-- importance: high, extracted from experience via ExpeL pattern -->
- RULE: Always include competitor data when presenting SEO recommendations (learned 2026-04-05: CEO rejected proposal without competitor context)
- RULE: Budget requests need ROI projections to get board approval (learned 2026-04-10)

## Detailed Notes Index
<!-- Pointers to topic files, loaded on demand -->
- [Weekly W14](memory/weekly/2026-W14.md) — First operational week
- [Weekly W15](memory/weekly/2026-W15.md) — SEO strategy finalized
- [Monthly April](memory/monthly/2026-04.md) — Q2 launch month
```

**Key design principles:**
- Section-based implicit importance (Key Facts > Strategic Decisions > Learnings > Active Context)
- Dates on every entry (enables age-based pruning)
- Heuristics extracted from experience (ExpeL pattern) with source date and context
- Index pointers to topic files (loaded on demand, not at startup)
- Frontmatter tracks consolidation metadata

---

## 5. Memory Consolidation Skill — `/consolidate-memory`

A new skill that runs as part of the CAO heartbeat maintenance phase.

**Trigger:** Every N heartbeat cycles (configurable in `org/config.md` as `memory_consolidation_interval`, default: 7).

### Phase 1 — Daily-to-Weekly Consolidation

For each agent with 7+ unconsolidated daily memory logs:
1. Read all unconsolidated daily memory logs
2. Extract: key decisions, learnings, task outcomes, mistakes/failures, behavioral patterns
3. Write `memory/weekly/YYYY-WNN.md` with structured sections
4. Add `consolidated: true` frontmatter to daily files
5. Move consolidated daily files to `memory/archive/`

### Phase 2 — Weekly-to-Monthly Consolidation

For agents with 4+ unconsolidated weekly summaries:
1. Read all unconsolidated weekly summaries
2. Extract: enduring facts, strategic patterns, process improvements, recurring issues
3. Write `memory/monthly/YYYY-MM.md`
4. Mark weekly summaries as consolidated

### Phase 3 — MEMORY.md Refresh

After monthly consolidation:
1. Read current MEMORY.md
2. Read latest monthly summary
3. Identify: new facts to add, stale facts to remove, facts to update
4. Apply Mem0-style operations (ADD/UPDATE/DELETE/NOOP) for each entry
5. Ensure MEMORY.md stays under 200 lines
6. Section-based importance determines pruning priority:
   - **Key Facts**: importance >= 0.85 (never auto-prune)
   - **Strategic Decisions**: importance 0.7-0.85 (prune after 3 months without reference)
   - **Learnings**: importance 0.5-0.7 (prune after 2 months)
   - **Active Context**: importance < 0.5 (prune after 1 month, refresh each consolidation)

### Phase 4 — Activity Stream Archival

Move activity stream files older than 30 days to `activity/archive/`.

### Phase 5 — Knowledge Base Update (Optional)

Extract cross-agent patterns and add to `org/knowledge/`.

---

## 6. Context Loading Strategy

**Phase 1 (Current, months 1-3):** Load full MEMORY.md (< 200 lines, ~1500 tokens). Adequate.

**Phase 2 (Growth, months 3-6):** MEMORY.md becomes an index with pointers to topic files. Only the index loads at startup. Agent reads topic files on demand based on current task context.

**Phase 3 (Scale, months 6+):** Add a `/memory-search` skill that agents can invoke to search across archived memory files. Uses Grep initially, optionally sqlite-vec for semantic search.

---

## 7. Configuration

Add to `org/config.md`:

```yaml
memory_consolidation_interval: 7    # heartbeat cycles between consolidations
memory_daily_retention_days: 30     # days before archiving daily logs
memory_weekly_retention_weeks: 12   # weeks before archiving weekly summaries
activity_archive_after_days: 30     # days before archiving activity streams
memory_max_lines: 200               # max lines for MEMORY.md
consolidation_agent: cao            # who runs consolidation (default: CAO)
```

---

## 8. Hook Integration

**memory-size-check.sh** (PostToolUse on Write to MEMORY.md): Warns if MEMORY.md exceeds 200 lines after a write. Non-blocking (exit 1 with warning, not exit 2).

**activity-archive-reminder.sh** (during CAO heartbeat): Checks if any agent's activity directory has files older than the retention period. Injects a reminder to run consolidation.

---

## 9. Risks and Mitigations

### Summarization Drift
**Risk:** Each compression pass silently discards low-frequency details. After enough passes, the agent "remembers a sanitized, generic version of history."

**Mitigation:**
- Never delete original daily logs — move them to archive, not trash
- Weekly/monthly summaries are ADDITIONS, not replacements
- MEMORY.md heuristics reference the original date/context
- The archive is always searchable via Grep

### Token Cost of Consolidation
**Estimate:** For an org with 10 agents consolidated weekly:
- ~7 daily files per agent * 10 agents = 70 files to read
- Each file ~50 lines = 3,500 lines total input
- Plus MEMORY.md comparison: ~2,000 lines
- Total: ~50,000-120,000 tokens per weekly consolidation for 10 agents
- This is modest compared to the savings from not loading raw history

### Knowledge Loss from Archiving
**Mitigation:**
- MEMORY.md always contains pointers to weekly/monthly summaries
- Archive is searchable
- Monthly summaries capture the most important content from weeklies
- Critical facts promoted to MEMORY.md are never auto-pruned

---

## 10. Implementation Plan

### Phase 1 — Minimal Viable Memory Management (4-6 hours)
1. Add `consolidated` frontmatter field to daily memory log spec
2. Add `memory/archive/` and `activity/archive/` directories to agent workspace template
3. Add memory configuration fields to `org/config.md`
4. Create the `/consolidate-memory` skill with basic daily-to-weekly consolidation and MEMORY.md refresh
5. Add consolidation as a step in the CAO heartbeat (HEARTBEAT.md)
6. Create `memory-size-check.sh` hook

### Phase 2 — Hierarchical Consolidation (6-10 hours)
7. Implement weekly-to-monthly consolidation
8. Implement activity stream archival (move files >30 days to archive/)
9. Enhance MEMORY.md format with section-based importance and topic file pointers
10. Update system-reference.md with memory management documentation
11. Update agent INSTRUCTIONS templates with memory consolidation responsibilities

### Phase 3 — Retrieval Enhancement (8-16 hours)
12. Create `/memory-search` skill for agents to search across archived memory
13. Add grep-based search across memory archives with date range filtering
14. Create org/knowledge/ shared knowledge base structure
15. Add cross-agent knowledge extraction to consolidation skill

### Phase 4 — Advanced (Future)
16. Evaluate and optionally add sqlite-vec for semantic search
17. Implement process heuristics extraction (ExpeL pattern) — agents learn from successes and failures
18. Add memory consistency protocols for multi-agent environments
19. Implement access-based reinforcement (frequently accessed memories gain strength)

---

## 11. Architecture Decisions

### Decision 58: Tiered Memory Consolidation (Daily → Weekly → Monthly)
**Decision:** Implement hierarchical time-based consolidation: daily logs consolidate into weekly summaries, weeklies into monthlies, monthlies promote durable facts to MEMORY.md.
**Reasoning:** Direct analog to human memory (hippocampal replay). Prevents unbounded growth while preserving institutional knowledge. Each tier has different retention and detail levels.

### Decision 59: MEMORY.md as Index with Topic Files
**Decision:** As the org grows, MEMORY.md evolves from a flat knowledge file into an index with pointers to topic-specific files. Only the index loads at startup.
**Reasoning:** Inspired by Claude Code's own auto-dream pattern. Keeps startup context small (<200 lines, ~1500 tokens) while allowing deep knowledge to be accessed on demand.

### Decision 60: Archive, Never Delete
**Decision:** Original daily memory logs and activity streams are moved to archive directories, never deleted. Archives are always searchable.
**Reasoning:** Prevents summarization drift from causing permanent knowledge loss. The archive serves as ground truth if consolidation introduces errors.

### Decision 61: Shared Organizational Knowledge Base
**Decision:** Add `org/knowledge/` with org-wide and department-specific knowledge files. Populated by the consolidation process extracting cross-agent patterns.
**Reasoning:** Prevents valuable knowledge from being siloed in individual agent memories. Department knowledge bases capture collective intelligence. Access follows existing chain-of-command model.

### Decision 62: CAO as Consolidation Agent
**Decision:** The CAO runs memory consolidation as part of its Phase 4 heartbeat maintenance duties.
**Reasoning:** The CAO already has read access to all agent workspaces. Memory management is a workforce health function. No new agent needed.
