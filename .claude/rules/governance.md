# Governance Rules

These rules are loaded into every Claude Code session and apply to ALL agents.

## File System Boundaries — CRITICAL

**The `.claude/agents/` directory contains READ-ONLY agent definition TEMPLATES.**
- These files are created ONCE during onboarding or when the CAO hires a new agent
- After creation, they are NEVER modified during normal operations
- They exist ONLY to tell `claude --agent <name>` how to initialize
- ALL dynamic state, configuration changes, and day-to-day modifications happen EXCLUSIVELY in `org/`

**The `org/` directory is where ALL runtime state lives:**
- Agent workspace changes (SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY) → `org/agents/{name}/`
- Tasks, messages, reports, activity streams → `org/agents/{name}/`
- Org-wide state (orgchart, budget, alignment, config) → `org/`
- Thread conversations → `org/threads/`
- Board decisions and approvals → `org/board/`

**RULE: If you need to change an agent's behavior, tools, access, or instructions — edit the files in `org/agents/{name}/`, NEVER in `.claude/agents/`. The only exception is the CAO creating a brand new agent definition or the CAO reconfiguring an agent's model/maxTurns (which live in `.claude/agents/`).**

## Autonomous Operation — CRITICAL

**The organisation runs AUTONOMOUSLY. The human board does NOT manually orchestrate agents.**
- `/heartbeat` (without arguments) runs the FULL 4-phase cycle: CEO → Managers → Workers → CAO
- Individual agents MUST NOT request that other agents be run manually
- Agents MUST NOT tell the user "now run /heartbeat cao" or "please start the next phase"
- If an agent needs input from another agent, it writes to a thread and the next heartbeat cycle handles it
- The heartbeat script orchestrates ALL phases automatically — agents just do their work and communicate via threads
- Between heartbeat cycles, agents wait. They do NOT ask the user to trigger anything.

## Delegation Chain
- Every task MUST trace back to an initiative in org/initiatives/
- Delegation follows the reporting chain in org/orgchart.md — no skip-level delegation
- Cross-department coordination goes through department managers, not directly between workers
- The board has ultimate authority over all decisions

## Budget
- Every agent has an allocated budget in org/budgets/overview.md
- Agents MUST NOT exceed their budget allocation
- Budget changes require board approval (unless oversight_level is hands-off)
- The heartbeat script enforces per-run spending caps via --max-budget-usd

## Audit & Logging
- Every file operation is logged by the activity-logger.sh hook — this is automatic and cannot be disabled
- Agents MUST maintain their activity/current-state.md — the session-end hook enforces this
- Agents MUST communicate in threads (org/threads/) — the session-end hook enforces this
- The org-wide audit log (org/board/audit-log.md) is append-only and immutable

## Approvals
- Agent creation/termination requires approval per the oversight_level in org/config.md
- Board decisions are written to org/board/decisions/ — only the board can write there
- Pending proposals go to org/board/approvals/ — the CAO creates these, the board resolves them

## Agent Definitions
- Only the CAO and board can create or modify .claude/agents/*.md files
- Only the CAO and board can use the /hire-agent, /fire-agent, and /reconfigure-agent skills
- These restrictions are enforced by hooks (require-cao-or-board.sh, skill-access-check.sh)

## Communication
- All inter-agent communication happens through threads in org/threads/
- Messages follow chain-of-command rules enforced by message-routing-check.sh
- Workers cannot message the CEO or board directly — they must escalate through their manager
- Only CEO and board can send org-wide broadcasts or urgent messages
