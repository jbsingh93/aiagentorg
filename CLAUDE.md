# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OrgAgent** — A dynamic, self-organizing AI agent organisation system built natively on Claude Code. The user's Claude Code session IS the board interface. Skills replace all CLI commands. Agents execute real work and communicate through thread-based chat enforced by chain-of-command. Three-layer observability ensures every agent's cognitive state is fully traceable.

**Distribution:** `npx create-orgagent my-company`
**Status:** Research & specification complete (see `TO-DO/`). Ready for implementation.

## Architecture

```
Human (Board) --> Claude Code session (skills + natural language)
       |              |
       |         GUI Dashboard (localhost:3000)
       |
Governance Layer (11 hooks: access control, audit, budget, routing, state enforcement)
       |
Agent Runtime (claude --agent <name> invocations)
  |- CEO (opus) -- strategic leadership, delegation
  |- CAO (opus) -- creates/manages workforce, tool/access permissions
  |- Dynamic Agents (sonnet/haiku) -- hired by CAO on demand
       |
Three-Layer Observability
  |- Layer 1: Activity Stream (hook-forced, every file op logged)
  |- Layer 2: Current State (agent-maintained, hook-enforced)
  |- Layer 3: Thread-Based Chat (replaces inbox/outbox)
       |
Shared Org State (Markdown files in org/)
```

## Critical Cross-Cutting Concerns

1. **All prompts follow master-gpt-prompter principles** — Every LLM-facing text MUST follow `.claude/skills/master-gpt-prompter/SKILL.md`. The existing skill with its reference files is the authority.
2. **Dynamic tool permissions** — CAO + manager determine tools per agent. Agents REQUEST new tools. All logged.
3. **Chain-of-command data access** — `access_read`/`access_write` in IDENTITY.md, enforced by `data-access-check.sh`.
4. **Chain-of-command messaging** — Thread-based chat enforced by `message-routing-check.sh`. Workers cannot message CEO directly.
5. **Currency configurable** — ISO 4217 code in `org/config.md`. Never hardcoded.
6. **Three-layer observability** — Activity stream (hook-forced), current-state.md (agent-maintained, hook-enforced), threads (single source of truth for conversations).
7. **Agent Teams** — Available ONLY for exceptional no-brainer cases.
8. **Outbox eliminated** — Thread files are the record. Inbox holds only lightweight notifications.
9. **Continuous operation (Ralph Wiggum)** — `/run-org` triggers self-sustaining heartbeat loop via Stop hook. Org cycles until quiescent. Board intervenes only for approvals. `/cancel-org` to stop. `/loop 30m /run-org` for fully autonomous background operation.
10. **`.claude/agents/` is READ-ONLY** — Agent definitions are templates created once. All runtime changes in `org/` only. Exception: CAO hiring/reconfiguring.
11. **No manual orchestration** — Agents NEVER ask the user to run other agents. Heartbeat script + Ralph loop handle everything. Communication between agents goes through `org/threads/`.

## .claude/CLAUDE.md — Agent Initialization Guide

The `.claude/CLAUDE.md` is a universal initialization guide (NOT board alignment):
1. You are an agent in an AI organisation. Read your workspace to initialize.
2. Your workspace: `org/agents/{your-name}/`
3. Context loading order: SOUL → IDENTITY → INSTRUCTIONS → HEARTBEAT → MEMORY
4. Shared files: alignment.md, config.md, orgchart.md, custom-rules.md
5. All prompts follow master-gpt-prompter principles
6. If you need a tool/data you don't have: create a request
7. You MUST maintain `activity/current-state.md` — hooks enforce this
8. You MUST communicate in threads (`org/threads/`) — hooks enforce this

## Skills (20 system skills)

| Skill | Purpose |
|-------|---------|
| onboard | Deep alignment + org bootstrap |
| heartbeat | Run org heartbeat cycle |
| delegate | Create task + notify via thread |
| escalate | Escalate through chain-of-command |
| report | Write status report |
| message | Send message via thread (validates chain-of-command) |
| approve | Board approval/rejection |
| budget-check | Verify budget |
| hire-agent | CAO: create agent (hook-restricted) |
| fire-agent | CAO: deactivate agent (hook-restricted) |
| reconfigure-agent | CAO: modify agent (hook-restricted) |
| review-work | Manager: review subordinate output |
| status | Show org overview |
| dashboard | Start GUI server |
| task | Task management |
| master-gpt-prompter | Meta-skill: prompt engineering for all LLM-facing text |
| run-org | Start continuous autonomous loop (Ralph Wiggum pattern) |
| cancel-org | Stop the continuous loop cleanly |
| browser | Browser automation via Playwright MCP/CLI (privileged tool) |
| create-skill | Create custom skills for the org skill library |

## Hooks (11 total)

| Hook | Event | Purpose |
|------|-------|---------|
| activity-logger.sh | PostToolUse (all) | Log every action to activity stream + audit log |
| remind-state-update.sh | PostToolUse (Write\|Edit) | Periodic reminder to update current-state.md and threads |
| require-state-and-communication.sh | Stop | BLOCKS session end if state stale or no thread communication |
| data-access-check.sh | PreToolUse (file ops) | Chain-of-command file access |
| message-routing-check.sh | PreToolUse (inbox writes) | Chain-of-command message routing |
| require-board-approval.sh | PreToolUse (decisions) | Board-only decision writes |
| require-cao-or-board.sh | PreToolUse (agent defs) | Agent definition protection |
| skill-access-check.sh | PreToolUse (Skill) | Agent management skill restriction |
| budget-check.sh | PostToolUse (tasks) | Budget enforcement |
| log-agent-activation.sh | SubagentStart | Log agent session start |
| log-agent-deactivation.sh | SubagentStop | Log agent session end |

## Reference Documents (TO-DO/)

| # | Doc | Contents |
|---|-----|----------|
| 00 | OVERVIEW.md | Master overview, file index, 25 key design decisions |
| 01 | MASTER-PLAN.md | Complete implementation plan (v2.0) |
| 02 | USER-REQUIREMENTS.md | All user decisions (4 Q&A rounds) |
| 03 | PAPERCLIP-RESEARCH.md | Paperclip research (explored, not used) |
| 04 | CLAUDE-CODE-SKILLS-RESEARCH.md | Skills system specification |
| 05 | CLAUDE-CODE-HOOKS-SUBAGENTS-TEAMS-RESEARCH.md | Hooks, subagents, teams |
| 06 | CLAUDE-CODE-PERSISTENCE-CLI-RESEARCH.md | CLAUDE.md, memory, settings, CLI |
| 07 | OPENCLAW-RESEARCH.md | OpenClaw agent architecture (workspace inspiration) |
| 08 | SCREENSHOT-ANALYSIS.md | Original org chart diagram |
| 09 | ARCHITECTURE-DECISIONS.md | All 44 design decisions with reasoning |
| 10 | FILE-FORMAT-SPECIFICATIONS.md | 26 file format specs with examples |
| 11 | DISTRIBUTION-PLAN.md | npx create-orgagent packaging |
| 12 | DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md | Tool permissions, data access, request workflows |
| 13 | MASTER-PROMPTER-SKILL-SPEC.md | Prompt engineering principles for reasoning models |
| 14 | ONBOARDING-SKILL-FULL-SPEC.md | Complete onboarding skill body (~600 lines) |
| 15 | CHAT-LAYER-CHAIN-OF-COMMAND.md | Communication rules, routing, threading, cross-dept |
| 16 | OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md | Three-layer observability, activity streams, current-state, thread chat, 11 hooks |
| 17 | REMAINING-SKILL-SPECS-AND-MISSING-FILES.md | 9 skill bodies, rules, .claude/CLAUDE.md, edge cases, settings.json |
| 18 | CONTINUOUS-OPERATION-RALPH-WIGGUM.md | Ralph Wiggum Stop-hook pattern, /run-org, /cancel-org, stale detection |
| 19 | BROWSER-AUTOMATION.md | Playwright MCP/CLI/Chrome, permission integration, /browser skill |
| 20 | SKILL-LIBRARY-SYSTEM.md | org/skills/ library, /create-skill, registry, versioning, sharing |

## Key Constraints

- Language per-organisation (ISO 639-1, set during onboarding)
- Currency per-organisation (ISO 4217, set during onboarding)
- No external database — filesystem only
- GUI: vanilla JS, D3.js, Chart.js — no React
- Agents produce real deliverables, not simulations
- Three oversight levels (configurable)
- CEO replaceable by CAO
- Windows supported via Git Bash
- `jq` required for hooks
- No context budget — agents load ALL necessary context
- User custom rules from kickoff in `org/rules/`
- Outbox eliminated — threads are single source of truth
