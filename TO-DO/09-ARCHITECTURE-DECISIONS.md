# Architecture Decisions — Ambiguity Resolutions & Design Choices

**Date:** 2026-03-31 (Updated continuously)
**Status:** Final decisions for implementation
**Total Decisions:** 37

---

## Overview

This document resolves all identified ambiguities and records every design decision needed for 100% implementation clarity. Each decision includes the reasoning and alternatives considered.

---

## Decision 1: Claude Code IS the Interface (No Separate CLI)

**Decision:** Remove the standalone `orgagent` CLI wrapper. The user's Claude Code session IS the board interface. Skills replace all CLI commands.

**Reasoning:**
- The `orgagent` CLI was a thin wrapper around `claude` CLI calls — unnecessary indirection
- Skills provide the same structured workflows with better Claude Code integration
- The user never leaves Claude Code — simpler UX
- Natural language can handle anything skills don't cover
- Reduces ~15 files (scripts/cli/*.sh + orgagent wrapper)

**What replaces what:**

| Old CLI Command | New Approach |
|----------------|-------------|
| `orgagent init` | `/onboard` skill |
| `orgagent status` | `/status` skill or "show org status" |
| `orgagent run <agent> [instruction]` | "Run the CEO with: ..." (Claude uses Bash to call `claude --agent`) |
| `orgagent heartbeat` | `/heartbeat` skill |
| `orgagent heartbeat <agent>` | "Run CEO heartbeat" |
| `orgagent task assign/list/view` | `/task` skill |
| `orgagent board approve/reject/list` | `/approve` skill or "approve the marketing hire" |
| `orgagent message <from> <to> <msg>` | `/message` skill |
| `orgagent inbox <agent>` | "Show CEO inbox" or `/inbox` |
| `orgagent dashboard` | `/dashboard` skill |
| `orgagent log` | "Show audit log" |
| `orgagent budget` | "Show budget status" |
| `orgagent orgchart` | "Show org chart" |
| `orgagent schedule start/stop` | `/schedule` or `/loop` (Claude Code built-in) |

---

## Decision 2: Distribution via `npx create-orgagent`

**Decision:** Package as an npm scaffolding tool. Users run `npx create-orgagent my-company` to create a new org project.

**Reasoning:**
- Familiar pattern (create-react-app, create-next-app)
- Zero pre-installation (npx downloads on demand)
- Cross-platform (Node.js required for GUI anyway)
- One-command setup
- Alternative: GitHub template repo for zero-infrastructure distribution

**See:** `11-DISTRIBUTION-PLAN.md` for complete specification.

---

## Decision 3: Scheduling Uses Claude Code Built-in Features

**Decision:** Use Claude Code's native scheduling instead of custom scheduler scripts.

**Three tiers available:**

| Tier | Command | Use Case | Persistence |
|------|---------|----------|-------------|
| **Session polling** | `/loop 2h /heartbeat` | While actively working | Session only, 3-day expiry |
| **Desktop task** | Via Claude Code Desktop App | Background on your machine | Survives restarts |
| **Cloud trigger** | `/schedule` | Fully autonomous (requires git repo) | Permanent until deleted |

**For initial implementation:** Desktop Tasks are the primary recommendation — persistent, local file access, works without git push.

**For advanced users:** Cloud triggers via `/schedule` enable fully autonomous orgs (requires pushing org state to git repo).

**Eliminated:** `scripts/schedule.sh`, `scripts/cli/schedule.sh` — no longer needed.

---

## Decision 4: Agent Identification via Environment Variable

**Decision:** The heartbeat script sets `ORGAGENT_CURRENT_AGENT=<name>` before each `claude --agent` invocation. Hook scripts read this variable to identify the running agent.

**Flow:**
```bash
# In scripts/heartbeat.sh
export ORGAGENT_CURRENT_AGENT=ceo
claude --agent ceo -p "Run your heartbeat cycle" ...

export ORGAGENT_CURRENT_AGENT=cao
claude --agent cao -p "Run your heartbeat cycle" ...
```

**In hook scripts:**
```bash
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
# If unset/empty, assume "board" (human user running Claude Code directly)
```

**Why this works:** Claude Code inherits the parent process's environment. Hook scripts run as child processes of Claude Code, so they inherit the env var.

**Alternative considered:** Reading session metadata, checking a marker file. Rejected as more complex with no benefit.

---

## Decision 5: Single Canonical Memory System (Workspace Memory)

**Decision:** Use `org/agents/{name}/MEMORY.md` + `org/agents/{name}/memory/YYYY-MM-DD.md` as the ONLY memory system for agents. Disable Claude Code auto-memory and subagent persistent memory for agent sessions.

**The three layers that exist:**

| Layer | Location | Used? | Why |
|-------|----------|-------|-----|
| Claude Code auto-memory | `~/.claude/projects/<hash>/memory/` | **NO for agents, YES for board** | Board user keeps their personal memory |
| Subagent persistent memory | `.claude/agent-memory/<name>/` | **NO** | Conflicts with workspace memory |
| Workspace memory | `org/agents/{name}/MEMORY.md` + `memory/` | **YES** | Single source of truth, visible, portable |

**Implementation:**
- Agent definitions do NOT include `memory: project` in frontmatter
- Heartbeat script sets `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` before agent invocations
- Each agent's instructions tell it to read/write `org/agents/{name}/MEMORY.md`
- Board session (user's Claude Code) keeps auto-memory enabled normally

**Reasoning:**
- One source of truth per agent — no confusion
- Memory files visible in filesystem — other agents and GUI can read them
- Portable — memory travels with the org directory
- Auditable — memory changes tracked if using git

---

## Decision 6: Orgchart Format (Machine-Readable Indented List)

**Decision:** Use an indented markdown list with structured metadata per line.

**Format:**
```markdown
# Organisation Chart

- **Board** (human) — Governance & oversight
  - **CEO** (active, @ceo) — Chief Executive Officer
    - **CAO** (active, @cao) — Chief Agents Officer
    - **Marketing Manager** (active, @marketing-manager) — Marketing Department Lead
      - **SEO Agent** (active, @seo-agent) — SEO Specialist
```

**Parse rules:**
- Indentation (2 spaces) = hierarchy depth
- `@name` = agent ID (matches `.claude/agents/{name}.md` and `org/agents/{name}/`)
- `(status, @id)` = metadata in parentheses
- Text after `—` = role title/description
- `(human)` = non-agent node (board)

**Why this format:**
- Human-readable (looks natural in any markdown viewer)
- Machine-parseable (indentation + regex for @id and status)
- Easy for CAO to update (just add/remove/modify lines)
- GUI can parse into tree structure for D3.js visualization

**See:** `10-FILE-FORMAT-SPECIFICATIONS.md` for complete format spec.

---

## Decision 7: Model Selection Per Agent Tier

**Decision:** Use different Claude models based on agent tier to optimize cost.

| Tier | Model | Reasoning |
|------|-------|-----------|
| **CEO** | `opus` | Strategic decisions require highest reasoning |
| **CAO** | `opus` | Agent design is complex, needs deep understanding |
| **Managers** | `sonnet` | Delegation and coordination — good balance |
| **Workers** | `sonnet` or `haiku` | Task execution — configurable per agent |

**Implementation:** Set in each agent's `.claude/agents/{name}.md` frontmatter:
```yaml
model: opus    # or sonnet, haiku
```

**Configurable:** The onboarding skill asks about budget constraints and sets default models in `org/config.md`. The CAO uses this when creating new agents.

**Cost estimates (rough):**
- Opus heartbeat (50 turns max): ~$1-3 per run
- Sonnet heartbeat: ~$0.10-0.50 per run
- Haiku heartbeat: ~$0.02-0.10 per run

A 10-agent org with 2 opus + 3 sonnet + 5 haiku at 2-hour heartbeat = ~$20-50/day.

---

## Decision 8: Task Lifecycle (File Movement)

**Decision:** Tasks are markdown files that physically move between directories as their status changes.

**Flow:**
```
tasks/backlog/task-20260331-001.md   → Created
tasks/active/task-20260331-001.md    → Agent starts working
tasks/done/task-20260331-001.md      → Completed with results
```

**Why file movement (not status field):**
- Trivially scannable — `ls tasks/active/` shows all active tasks
- No parsing needed to determine status
- Works naturally with Glob/Grep tools
- The file's frontmatter ALSO has a `status` field (for redundancy/querying)
- When an agent moves a file, it also updates the `status` frontmatter field

**Task ID format:** `task-YYYYMMDD-NNN` where NNN is a zero-padded sequential number per day.

**See:** `10-FILE-FORMAT-SPECIFICATIONS.md` for complete task format.

---

## Decision 9: Message Lifecycle (Read Flag, Not Movement)

**Decision:** Messages stay in the recipient's `inbox/` folder. A `read: true/false` frontmatter field tracks read status.

**Why NOT move to a "read" folder:**
- Messages may need to be re-read
- Simpler — one folder to check
- The `read` field is updated when the agent processes the message
- Old messages can be archived periodically (during heartbeat maintenance)

**Message ID format:** `msg-YYYYMMDD-HHMMSS-{from}.md` — timestamp + sender ensures uniqueness.

**See:** `10-FILE-FORMAT-SPECIFICATIONS.md` for complete message format.

---

## Decision 10: Approval Workflow State Machine

**Decision:** Approval files have a `status` frontmatter field that transitions: `pending` → `approved` | `rejected`.

**Flow:**
1. CAO writes `org/board/approvals/hire-{name}-YYYYMMDD.md` with `status: pending`
2. Board (human) reviews via GUI or Claude Code session
3. Human approves → status changes to `approved`, `decided_by: board`, `decided_date: ...`
4. OR human rejects → status changes to `rejected` with `decision_reason: ...`
5. Next CAO heartbeat reads the approval, sees status, acts accordingly
6. Completed approvals move to `org/board/decisions/` for archive

**GUI integration:** `POST /api/approvals/{id}/approve` or `POST /api/approvals/{id}/reject` updates the frontmatter fields.

**See:** `10-FILE-FORMAT-SPECIFICATIONS.md` for complete approval format.

---

## Decision 11: Budget Tracking Mechanics

**Decision:** Budget is tracked in USD (API cost). The heartbeat script captures cost from `claude` CLI output and appends to the spending log.

**How costs are captured:**
```bash
# In scripts/heartbeat.sh
result=$(claude --agent ceo -p "heartbeat" --output-format json --max-budget-usd 5.00)
cost=$(echo "$result" | jq -r '.cost_usd // 0')
echo "| $(date -Iseconds) | ceo | heartbeat | $cost |" >> org/budgets/spending-log.md
```

**Budget enforcement:**
- `--max-budget-usd` flag on each `claude` invocation caps per-run spending
- `budget-check.sh` PreToolUse hook reads `org/budgets/overview.md` to check remaining budget before allowing task creation
- If an agent's allocated budget is exhausted, the hook blocks new task creation (exit 2)
- Budget overview is updated by the heartbeat script after each agent run

**Budget allocation:**
- Total org budget set during onboarding (stored in `org/config.md`)
- Per-agent budgets allocated in `org/budgets/overview.md`
- CAO can reallocate budgets (with board approval if oversight level requires it)

**See:** `10-FILE-FORMAT-SPECIFICATIONS.md` for budget file formats.

---

## Decision 12: Audit Log Format (Append-Only Markdown Table)

**Decision:** The audit log is an append-only markdown file with timestamped entries as a running table.

**Format:**
```markdown
| Timestamp | Agent | Action | Target | Details |
|-----------|-------|--------|--------|---------|
| 2026-03-31T10:00:00 | ceo | task-create | tasks/backlog/task-001.md | Assigned SEO strategy |
| 2026-03-31T10:05:00 | cao | hire-propose | approvals/hire-seo-agent.md | Proposed SEO Agent |
```

**Why markdown table (not structured entries):**
- Compact — one line per entry
- Readable in any markdown viewer
- Still parseable (pipe-delimited)
- Append is a simple file operation
- GUI can parse and display as searchable table

**Concurrency handling:** The hook script uses file locking (`flock` on Linux/Mac, or atomic append). On Windows with Git Bash, append operations (`>>`) are generally safe for single-writer scenarios. Since hooks run sequentially within a single `claude` session, concurrent writes only occur during parallel heartbeat phases — each phase runs different agents, so audit log appends from different processes.

**Mitigation for parallel writes:** Each hook appends a single complete line. Worst case, lines interleave (fixable by sorting on timestamp). For production, a more robust approach would use per-agent audit files merged at cycle end.

---

## Decision 13: Agent-Specific Skills Loading

**Decision:** Agent-specific skills go in `.claude/skills/{agent-name}-{skill-name}/SKILL.md`, NOT in the agent's workspace.

**Why:**
- Claude Code only discovers skills from `.claude/skills/`, `~/.claude/skills/`, or `--add-dir` paths
- Skills in `org/agents/{name}/skills/` would NOT be auto-discovered
- Prefixing with agent name provides namespace separation
- Example: `.claude/skills/cao-workforce-analysis/SKILL.md`

**Alternative considered:** Using `--add-dir org/agents/{name}/skills/` in agent invocation. Rejected because it adds complexity to the heartbeat script and the skills directory may not exist yet.

**For MVP:** All skills are shared (in `.claude/skills/`). Agent-specific skills can be added later.

---

## Decision 14: Agent Teams — NOT Used for MVP

**Decision:** Do not use Claude Code Agent Teams. Use top-level `claude --agent` invocations orchestrated by the heartbeat bash script.

**Reasoning:**
- Agent Teams are experimental (require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)
- The heartbeat script's bash parallelism (`&` + `wait`) is simpler and more controllable
- Agent Teams have flat structure (no sub-leaders) — doesn't match the org hierarchy
- Agent Teams have higher token cost (N × full context)
- The filesystem-based communication model (threads + inbox notifications) works without teams

**Future consideration:** When Agent Teams stabilize, they could replace the heartbeat script's manual orchestration. The architecture is compatible — each agent already has independent context and communicates via filesystem.

---

## Decision 15: Subagent Nesting — Handled by Top-Level Invocations

**Decision:** During heartbeats, agents run as top-level `claude --agent` invocations (NOT subagents). This sidesteps the subagent nesting limitation entirely.

**Implication:**
- CEO CAN use the `Agent` tool when run interactively (`"Run the CEO with: delegate X to Y"`)
- CEO should NOT use the `Agent` tool during heartbeats (add constraint in INSTRUCTIONS.md)
- The heartbeat skill/script orchestrates all agent runs sequentially/parallel from the outside

**Agent tool in frontmatter:**
- CEO: `tools: Read, Write, Edit, Bash, Grep, Glob, Agent` — has Agent tool for interactive use
- CAO: `tools: Read, Write, Edit, Bash, Grep, Glob` — no Agent tool (creates agents via file writing, not spawning)
- Managers: `tools: Read, Write, Edit, Bash, Grep, Glob` — no Agent tool
- Workers: `tools: Read, Write, Edit, Bash, Grep, Glob` — no Agent tool (may add specific tools like WebFetch, WebSearch)

---

## Decision 16: Heartbeat Script Determines Hierarchy from Orgchart

**Decision:** `scripts/heartbeat.sh` parses `org/orgchart.md` to determine which agents run in which phase.

**Parsing logic:**
```bash
# Depth 0: Board (skip — human, not an agent)
# Depth 1: CEO (Phase 1 — sequential, runs first)
# Depth 2: Managers EXCLUDING CAO (Phase 2 — parallel)
# Depth 3+: Workers (Phase 3 — parallel)
# CAO: Phase 4 ONLY — sequential, runs LAST (NOT in Phase 2)
```

**Clarification:** The CAO runs ONLY in Phase 4, never in Phase 2. Even though the CAO sits at depth 2 in the orgchart, the heartbeat script explicitly excludes it from the manager phase and runs it last. This is because the CAO reviews the RESULTS of all other agents' work and makes workforce decisions based on the full picture.

**Implementation:** The script counts leading spaces (2 per level) and extracts `@agent-id` from each line. It filters by `(active, ...)` status — only active agents get heartbeats.

**Special cases:**
- CAO always runs in Phase 4 regardless of depth
- Agents with `status: paused` or `status: terminated` are skipped
- New agents with `status: pending-approval` are skipped

---

## Decision 17: Concurrent File Access Strategy

**Decision:** Accept eventual consistency for the MVP. Use per-agent write isolation where possible.

**Rules:**
- Each agent primarily writes to its OWN workspace (`org/agents/{name}/`)
- Cross-agent writes (inbox, tasks) happen through skills that write to the TARGET agent's directory
- The audit log is the only true shared append-only file — accept rare interleaving
- During parallel heartbeat phases, agents at the same level should NOT share write targets
- If they do (e.g., two managers both write to CEO's inbox), the worst case is message ordering issues, not data loss

**For production:** Implement a message queue or use per-sender files (e.g., `inbox/20260331-from-sales-manager.md`). The current format already includes sender in filename.

---

## Decision 18: Windows Compatibility Strategy

**Decision:** Support Windows via Git Bash (which comes with Git for Windows). Document WSL as an alternative.

**Specific accommodations:**
- All bash scripts use `#!/usr/bin/env bash` (portable shebang)
- No `cron` usage — use Claude Code scheduling or Node.js-based scheduler
- `jq` required — document installation (`winget install jqlang.jq` or `choco install jq`)
- File paths use forward slashes in scripts (Git Bash handles translation)
- No `chmod +x` needed — scripts invoked as `bash scripts/heartbeat.sh`
- The `flock` command isn't available on Windows Git Bash — use alternative locking or accept append races
- Express.js server works natively on Windows

**npm scaffolding tool handles cross-platform:**
- Written in Node.js (cross-platform by nature)
- File copying uses `fs` module (handles path separators)
- No shell scripts in the scaffolding itself

---

## Decision 19: Onboarding is Interactive

**Decision:** The `/onboard` skill runs in the user's Claude Code session as an interactive conversation. It is NOT a non-interactive/print-mode operation.

**Flow:**
1. User types `/onboard` in Claude Code
2. Skill instructions tell Claude to have a deep alignment conversation
3. Claude asks questions one by one, collecting answers
4. After alignment is complete, Claude writes all org files using Write/Edit tools
5. Claude creates CEO and CAO agent definitions and workspaces
6. Claude confirms org is ready

**Why interactive:**
- Onboarding needs a back-and-forth conversation (not a form)
- The user might change answers, ask for clarification, iterate
- Claude Code's interactive mode is perfect for this
- No special CLI handling needed

**Implication:** `init.sh` is eliminated. Onboarding is purely a skill.

---

## Decision 20: GUI Details

**Decision:**

| Setting | Value | Reasoning |
|---------|-------|-----------|
| **Port** | 3000 (configurable via `PORT` env var) | Standard Express default |
| **Markdown parser** | `marked` npm package | Lightweight, well-maintained |
| **Real-time updates** | Polling every 5 seconds | Simple, no WebSocket complexity |
| **Org directory** | Resolved relative to `gui/server.js` (`../org/`) | Convention-based, no config needed |
| **Authentication** | None (local only) | MVP simplicity; add later if needed |
| **D3.js / Chart.js** | Loaded from CDN | No npm install needed for frontend libs |

**package.json dependencies:**
```json
{
  "dependencies": {
    "express": "^5.0.0",
    "marked": "^15.0.0",
    "gray-matter": "^4.0.3",
    "chokidar": "^4.0.0"
  }
}
```

- `express` — HTTP server
- `marked` — Markdown to HTML rendering
- `gray-matter` — Parse YAML frontmatter from markdown files
- `chokidar` — File watching for optional SSE push (future enhancement)

---

## Decision 21: Rules File Content

**Decision:** `.claude/rules/` files contain behavioral constraints loaded into every Claude Code session.

**`governance.md` content covers:**
- All actions must be logged to the audit trail
- Budget must be checked before resource-intensive operations
- Board decisions require human approval
- Agent creation/termination requires CAO or board authority
- Every task must trace back to an initiative
- Delegation must follow the reporting chain (no skip-level delegation without escalation)

**`structured-autonomy.md` content covers:**
- Agents do real work but within their mandate
- No freelancing — all work tied to assigned tasks
- Agents cannot modify their own SOUL.md or IDENTITY.md
- Agents cannot communicate outside the org (no external API calls without explicit permission)
- Agents must report completion of tasks
- Agents must escalate when they encounter situations outside their expertise

---

## Decision 22: Language/i18n Implementation

**Decision:** The org language is stored in `org/config.md` as `language: <code>`. Every agent reads this during context loading and all agent-generated content (reports, messages, task descriptions) is written in that language.

**Implementation:**
- The onboarding skill sets the language in `org/config.md`
- Each agent's instructions include: "Read `org/config.md` and write all content in the configured language"
- The CLAUDE.md includes: "All agent output must respect the language setting in org/config.md"
- The GUI is always in English (code-level UI)
- The CLI/skill names are always in English (they're code identifiers)

---

## Decision 23: Error Handling Strategy

**Decision:** Fail gracefully, log errors, continue the heartbeat cycle.

**Specific behaviors:**

| Error | Handling |
|-------|---------|
| Agent heartbeat fails (API error) | Log error to audit-log.md, skip agent, continue cycle |
| Agent exceeds maxTurns | Claude Code auto-stops; log incomplete heartbeat |
| Agent exceeds budget | `--max-budget-usd` enforces per-run cap; log overage warning |
| CAO creates invalid agent definition | Next `claude --agent <name>` invocation will fail; log error |
| GUI server crashes | User restarts manually; no impact on org state |
| Concurrent file write conflict | Accept last-write-wins; audit log may have interleaved lines |
| Approval for non-existent agent | CAO checks orgchart before acting; skip stale approvals |

**Heartbeat script error handling:**
```bash
# Run agent, capture exit code
ORGAGENT_CURRENT_AGENT=ceo claude --agent ceo -p "heartbeat" --output-format json > /tmp/ceo-result.json 2>&1
if [ $? -ne 0 ]; then
  echo "| $(date -Iseconds) | SYSTEM | error | ceo | Heartbeat failed: $(cat /tmp/ceo-result.json | head -1) |" >> org/board/audit-log.md
fi
```

---

## Decision 24: Testing Strategy

**Decision:** Manual end-to-end testing via documented test scenarios. No automated test framework for MVP.

**Reasoning:**
- The system is inherently non-deterministic (LLM-based agents)
- Automated assertions on LLM output are fragile
- The real test is: "does the org function end-to-end?"
- GUI can be tested manually by visual inspection
- Hook scripts can be unit-tested with mock stdin

**Test scenarios** (12 scenarios defined in master plan verification section).

**Future:** Add integration tests that verify file creation (did onboarding create the right files?), hook behavior (does budget-check block correctly?), and API responses (does the GUI API return valid JSON?).

---

## Decision 25: Approval/Decision Archive Flow

**Decision:** Approved/rejected proposals move from `org/board/approvals/` to `org/board/decisions/` after being acted upon.

**Flow:**
1. Proposal created in `approvals/` with `status: pending`
2. Board approves/rejects → status updated in place
3. CAO reads approval during heartbeat, acts on it
4. CAO moves the file to `decisions/` and updates `status: executed` (for approvals) or leaves as `rejected`

**Why move:**
- `approvals/` stays clean — only pending items
- `decisions/` serves as the historical archive
- Easy to list pending: `ls org/board/approvals/`

---

## Decision 26: Cross-Org Messages Directory

**Decision:** `org/messages/` is for broadcast/org-wide messages and urgent escalations. Thread files (`org/threads/`) are the primary communication record. Per-agent `inbox/` holds lightweight notifications pointing to threads.

> **UPDATE (post-Decision 37):** Outbox has been eliminated. Thread files are the single source of truth. See Decision 37 and `16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md`.

**Usage:**
- `org/messages/urgent/` — urgent messages visible to all agents during heartbeat
- `org/messages/broadcast-YYYYMMDD.md` — org-wide announcements
- Per-agent `inbox/` — direct messages between agents

**Heartbeat check order:**
1. Check `org/messages/urgent/` first
2. Check own `inbox/` second
3. Process tasks third

---

## Decision 27: Dynamic Tool Permissions (CAO + Manager Determine)

**Decision:** Tool permissions are NOT static. The CAO, in consultation with the agent's manager/executive, determines which tools each agent gets. Agents can REQUEST additional tools at runtime.

**Implementation:**
- Tools listed in `org/agents/{name}/IDENTITY.md` `tools:` field
- Same tools mirrored in `.claude/agents/{name}.md` agent definition
- Heartbeat script reads IDENTITY.md and passes `--allowedTools` per agent
- Tool request workflow: Agent → CAO inbox → CAO consults manager → update IDENTITY.md
- All requests logged in audit trail

**Why:** Different agents need different tools. An SEO agent needs WebSearch; a content writer doesn't. This mirrors real company access controls.

**See:** `12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` for complete specification.

---

## Decision 28: Chain-of-Command Data Access Control

**Decision:** Agents can only read/write files within their authorized scope. Access is determined by the chain-of-command and enforced by a PreToolUse hook.

**Access tiers:**
- **Board:** Full access to everything
- **CEO/CAO:** Full read access to org/, appropriate write access
- **Managers:** Read own department + shared org files; no access to other departments or board internals
- **Workers:** Read own workspace + limited shared files; no access to budgets, board, or other departments

**Enforcement:** `data-access-check.sh` hook reads `access_read`/`access_write` arrays from the agent's IDENTITY.md and blocks unauthorized file access.

**Request workflow:** Agents can request additional access from their supervisor. Supervisor approves and notifies CAO to update IDENTITY.md.

**See:** `12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` for full specification.

---

## Decision 29: Currency Is Configurable (Not Hardcoded)

**Decision:** The currency is set during onboarding and stored in `org/config.md` as an ISO 4217 code (`USD`, `DKK`, `EUR`, `GBP`, etc.). ALL budget references, spending logs, and cost displays use this configured currency.

**Implementation:**
- `org/config.md` frontmatter: `currency: DKK`
- Budget overview uses the symbol: `total_budget: 5000.00` (interpreted in configured currency)
- Spending log displays costs in the configured currency
- The GUI reads the currency from config.md and displays the correct symbol
- No hardcoded `$` signs anywhere — always read from config

**Why:** The user may operate in any market/country. A Danish org uses DKK, a US org uses USD.

---

## Decision 30: master-gpt-prompter Skill for All Prompts

**Decision:** A meta-skill (`master-gpt-prompter`) defines prompt engineering principles. ALL LLM-facing text in the system (SOUL.md, INSTRUCTIONS.md, HEARTBEAT.md, SKILL.md, agent definitions, rules) MUST be crafted following its 15 principles.

**Implementation:**
- Skill at `.claude/skills/master-gpt-prompter/SKILL.md`
- Auto-loaded by Claude when writing prompts (`disable-model-invocation: false`)
- User-invocable for manual optimization (`/master-gpt-prompter "optimize this"`)
- CLAUDE.md references this skill as mandatory for all prompt writing
- CAO must consult this skill when creating new agents

**See:** `13-MASTER-PROMPTER-SKILL-SPEC.md` for complete specification.

---

## Decision 31: Agent Teams for No-Brainer Cases Only

**Decision:** Claude Code Agent Teams are available but ONLY for clear-cut, obvious cases where parallel coordination is essential and cannot be achieved through normal heartbeat phases.

**When to use Agent Teams:**
- 3+ agents need to collaborate on a SINGLE deliverable in real-time
- The task CANNOT be decomposed into independent subtasks
- Normal heartbeat phases (sequential CEO → parallel managers → parallel workers) are insufficient
- Example: A cross-department crisis response requiring immediate coordination

**When NOT to use:**
- Normal task delegation (use heartbeat phases)
- Sequential workflows (use task dependencies)
- Simple parallel work (heartbeat already handles this)

**Context:** Board, executives, and CAO INSTRUCTIONS.md files must state: "Agent Teams are available via `--experimental-agent-teams` but should only be used in exceptional circumstances where standard heartbeat orchestration cannot achieve the required coordination."

**Reasoning:** Agent Teams are experimental, have high token cost (N × full context), and flat structure. The heartbeat model handles 95%+ of coordination needs.

---

## Decision 32: User Custom Rules at Kickoff

**Decision:** The onboarding conversation asks users for custom rules/constraints. These are stored in `org/rules/custom-rules.md` and loaded by all agents during context initialization.

**Implementation:**
- Onboarding asks: "Are there any custom rules, constraints, or policies your agents must follow?"
- User can specify: industry regulations, compliance requirements, brand guidelines, communication policies, etc.
- Written to `org/rules/custom-rules.md`
- Every agent's INSTRUCTIONS.md includes: "Read and follow org/rules/custom-rules.md"

**Why:** Every organisation has unique constraints that can't be anticipated in the template.

---

## Decision 33: CAO Receives Orders from Executives (Not Just CEO)

**Decision:** The CAO takes agent management orders from ANY executive-level agent (CEO, VP-level, directors), not just the CEO. The orgchart depth determines who qualifies as an "executive."

**Implementation:**
- CAO's INSTRUCTIONS.md states: "You accept workforce management requests from any agent at depth 1-2 in the orgchart (executives and senior managers)"
- The CAO verifies the requester's authority by checking orgchart.md
- For worker-level agents requesting new hires, the CAO requires their manager's endorsement

**Why:** As the org grows, the CEO shouldn't be the bottleneck for all hiring. Department heads should be able to request new agents for their teams.

---

## Decision 34: .claude/CLAUDE.md Is an Agent Initialization Guide (Not Board Alignment)

**Decision:** The `.claude/CLAUDE.md` file is a universal "how to initialize yourself" guide for all agents. It does NOT contain board-specific instructions. It tells any agent session where to find their context files and how to boot up.

**Content structure:**
1. "You are an agent in an AI organisation. Read your workspace to initialize."
2. How to find your workspace: `org/agents/{your-name}/`
3. Context loading order (SOUL → IDENTITY → INSTRUCTIONS → HEARTBEAT → MEMORY)
4. Reference to org-level shared files (alignment, config, orgchart)
5. Reference to master-gpt-prompter for prompt quality standards
6. How to request tools or data access if needed
7. Error recovery: what to do if you can't access a file

**Why the user's insight is correct:** The CLAUDE.md loads into EVERY session — both the board (user) and every agent. If it contains board-specific instructions, agents would be confused. Making it a neutral initialization guide works for all contexts.

---

## Decision 35: Skill Access Control via Hooks

**Decision:** Agent management skills (`hire-agent`, `fire-agent`, `reconfigure-agent`) are restricted to CAO and board via a PreToolUse hook on the Skill tool.

**Implementation:**
```json
{
  "matcher": "Skill",
  "if": "Skill(hire-agent)|Skill(fire-agent)|Skill(reconfigure-agent)",
  "hooks": [{"type": "command", "command": "bash scripts/hooks/skill-access-check.sh"}]
}
```

The `skill-access-check.sh` reads `ORGAGENT_CURRENT_AGENT` and only allows `cao` or `board`.

**Why:** Any user can type `/hire-agent` but only CAO and board should have this power. Hooks enforce this at runtime.

---

## Decision 36: No Context Budget — Use What's Necessary

**Decision:** There is NO artificial limit on context loaded per agent. Agents load ALL their workspace files plus shared org files. If that's 500+ lines, so be it.

**Reasoning:**
- Accuracy > token savings
- An agent with insufficient context makes worse decisions
- The master-gpt-prompter principles (especially Progressive Disclosure) help organize context effectively
- Cost optimization comes from model tiering (opus for executives, haiku for workers), not from starving agents of context

---

## Decision 37: Chat Layer / Chain-of-Command Is a First-Class Component

**Decision:** The inter-agent messaging system is NOT just "inbox/outbox folders." It is a **structured communication backbone** with:
- Chain-of-command routing rules (who can message whom)
- Message type classification (directive, report, request, escalation, cross-dept, broadcast)
- Conversation threading (thread_id, reply_to)
- Hook-based enforcement (`message-routing-check.sh`)
- Visibility rules (board sees all, managers see department, workers see own)
- Cross-department communication protocol (routed through managers)
- Dedicated GUI chat view with threading, filtering, and board send capability

**Source:** The high-level architecture screenshot (`AI-Agent-Organisation-high-level.png`) shows "Agent chat / messaging" as a dedicated panel — a first-class system component alongside the org hierarchy.

**Enforcement:** A new `message-routing-check.sh` PreToolUse hook validates that every write to an agent's `inbox/` directory follows chain-of-command rules. Workers cannot message the CEO. Cross-department messages must go through managers. Only CEO/board can send urgent messages.

**See:** `15-CHAT-LAYER-CHAIN-OF-COMMAND.md` for complete specification including the communication matrix, message types, threading format, cross-department protocol, enforcement hook implementation, GUI chat view spec, and agent instruction templates.
