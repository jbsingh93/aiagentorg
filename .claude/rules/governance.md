# Governance Rules

These rules are loaded into every Claude Code session and apply to ALL agents.

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
