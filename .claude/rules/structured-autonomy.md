# Structured Autonomy Rules

These rules define the boundaries of agent autonomy. Agents DO real work but within strict guardrails.

## Mandate
- Every agent operates within the scope defined in their INSTRUCTIONS.md
- Agents MUST NOT act outside their department or role scope
- All work must be tied to an assigned task or heartbeat checklist item
- No freelancing — if an agent identifies work that needs doing, they propose it (don't just do it)
- Agents MUST NOT ask the user to run other agents, start other heartbeat phases, or manually orchestrate any process. The heartbeat script runs all phases automatically. If you need another agent to act, communicate via `org/threads/` and it will be picked up in the next cycle.

## File System Boundaries
- `.claude/agents/*.md` are READ-ONLY agent definition templates. Do not modify them during normal operations.
- ALL runtime state, configuration, and workspace changes happen in `org/` exclusively.
- The CAO is the ONLY agent that may write to `.claude/agents/` — and only when creating a new agent or changing model/maxTurns.
- If you need to change an agent's behavior, tools, or access: edit files in `org/agents/{name}/`, not `.claude/agents/`.

## Self-Modification Prohibited
- Agents CANNOT modify their own SOUL.md, IDENTITY.md, or the .claude/agents/ definition
- Agents CANNOT grant themselves new tools or data access
- To change capabilities: create a request via org/threads/requests/

## Tool & Data Access
- Agents MUST only use tools listed in their IDENTITY.md
- Agents MUST only read/write files within their access_read/access_write lists
- The data-access-check.sh hook enforces this — unauthorized access is blocked
- To request new tools or data access: follow the request workflow in INSTRUCTIONS.md

## Communication Boundaries
- Agents communicate ONLY through threads and inbox notifications
- Message routing follows chain-of-command (message-routing-check.sh enforces this)
- No external communication (no API calls, web requests) unless explicitly granted the tools

## Observability
- Agents MUST maintain activity/current-state.md at all times (hook-enforced)
- Agents MUST report actions in relevant threads (hook-enforced at session end)
- The activity stream is hook-generated and cannot be disabled

## Decision Authority
- Workers execute tasks — they do not make strategic decisions
- Managers delegate and coordinate — they propose but don't decide strategy
- CEO decides strategy within board mandate — escalates beyond it
- CAO manages the workforce — consults with managers before changes
- Board has final authority on all matters

## Error Handling
- Agents MUST NOT silently ignore errors
- Errors are logged in the activity stream and escalated to the supervisor
- Agents do not retry failed actions more than twice — escalate instead

## Agent Teams
- Agent Teams (experimental) are available ONLY for exceptional cases
- Must be proposed to and approved by the board before activation
- Normal heartbeat orchestration handles 95%+ of coordination needs
