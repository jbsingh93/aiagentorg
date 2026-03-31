# OrgAgent — AI Agent Organisation System
## Project Overview & File Index

**Date:** 2026-03-31 (Updated)
**Project:** Dynamic AI Agent Organisation built natively on Claude Code
**Status:** Research & Specification Complete — Ready for Implementation
**Distribution:** `npx create-orgagent` (npm package) or GitHub template

---

## What This Is

A **dynamic, self-organizing AI agent organisation system** where:
- Claude Code is the LLM backbone for ALL agent intelligence
- The user's Claude Code session IS the board interface (no separate CLI)
- Skills replace CLI commands: `/onboard`, `/heartbeat`, `/approve`, etc.
- Markdown files and folders ARE the database (filesystem = state)
- Hooks enforce governance, audit trails, and budget controls
- Each agent runs as `claude --agent <name>` via the heartbeat script
- A modern dark-theme GUI dashboard is the visual command central
- An onboarding skill does deep alignment before any org starts
- Only Board (human) + CEO + CAO are created at kickoff
- The CAO dynamically hires/fires/reconfigures agents as needed
- Each agent has OpenClaw-style workspace (SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY)
- Distributed via `npx create-orgagent` for one-command setup
- Scheduling uses Claude Code built-in `/loop` or `/schedule`

---

## File Index

| # | File | Contents |
|---|------|----------|
| 00 | `00-OVERVIEW.md` | This file — master overview and index |
| 01 | `01-MASTER-PLAN.md` | Complete implementation plan with all specs (v2.0 — skills-based, no CLI wrapper) |
| 02 | `02-USER-REQUIREMENTS.md` | All user inputs, decisions, Q&A, and constraints |
| 03 | `03-PAPERCLIP-RESEARCH.md` | Full research on paperclipai/paperclip (explored, not used) |
| 04 | `04-CLAUDE-CODE-SKILLS-RESEARCH.md` | Exhaustive Claude Code Skills system specification |
| 05 | `05-CLAUDE-CODE-HOOKS-SUBAGENTS-TEAMS-RESEARCH.md` | Full Hooks, Subagents, Agent Teams specification |
| 06 | `06-CLAUDE-CODE-PERSISTENCE-CLI-RESEARCH.md` | CLAUDE.md, Memory, Settings, Tasks, CLI specification |
| 07 | `07-OPENCLAW-RESEARCH.md` | Full OpenClaw autonomous agent architecture research |
| 08 | `08-SCREENSHOT-ANALYSIS.md` | Analysis of user's original org chart screenshot |
| 09 | `09-ARCHITECTURE-DECISIONS.md` | **NEW** — All 37 design decisions with reasoning |
| 10 | `10-FILE-FORMAT-SPECIFICATIONS.md` | **NEW** — Exact format for every file type (26 formats) |
| 11 | `11-DISTRIBUTION-PLAN.md` | **NEW** — npx create-orgagent packaging & distribution |
| 12 | `12-DYNAMIC-PERMISSIONS-AND-ACCESS-CONTROL.md` | **NEW** — Tool permissions, data access control, request workflows, chain-of-command enforcement |
| 13 | `13-MASTER-PROMPTER-SKILL-SPEC.md` | **NEW** — master-gpt-prompter meta-skill: 15 prompt engineering principles for reasoning models |
| 14 | `14-ONBOARDING-SKILL-FULL-SPEC.md` | **NEW** — Complete onboarding skill body: conversation flow, file templates, CEO/CAO workspace content, verification |
| 15 | `15-CHAT-LAYER-CHAIN-OF-COMMAND.md` | **NEW** — Chat layer: communication rules, message routing, threading, cross-dept protocol, enforcement hooks, GUI chat view |
| 16 | `16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` | **NEW** — Three-layer observability: activity streams, current-state tracking, thread-based chat. Hook enforcement for state updates. Complete settings.json |
| 17 | `17-REMAINING-SKILL-SPECS-AND-MISSING-FILES.md` | **NEW** — 9 missing skill bodies, rules files content, .claude/CLAUDE.md, edge cases, complete settings.json + package.json |
| 18 | `18-CONTINUOUS-OPERATION-RALPH-WIGGUM.md` | **NEW** — Ralph Wiggum Stop-hook pattern for continuous autonomous operation |
| 19 | `19-BROWSER-AUTOMATION.md` | **NEW** — Three-tier browser strategy: Playwright MCP (primary), CLI (secondary), Chrome (interactive). Permission integration, /browser skill |
| 20 | `20-SKILL-LIBRARY-SYSTEM.md` | **NEW** — Custom skill creation, sharing, registry. org/skills/ library, /create-skill meta-skill, versioning, permission integration |

---

## Key Design Decisions (from user Q&A + architecture analysis)

1. **Real work** — agents execute actual tasks (content, reports, code, etc.)
2. **Claude Code IS the engine** — every agent runs as `claude --agent <name>`
3. **No separate CLI** — skills replace all CLI commands, user stays in Claude Code
4. **Dynamic onboarding** — deep alignment conversation via `/onboard` skill
5. **Language configurable** — set during onboarding per organisation
6. **Self-creating agents** — CAO writes brand new agent definition files from scratch
7. **Structured autonomy** — agents do real work but follow delegation chain
8. **Configurable oversight** — three levels: approve-everything / approve-strategy-only / hands-off
9. **Modern dark-theme dashboard** — D3.js org chart, kanban board, Chart.js budget charts
10. **OpenClaw-inspired workspaces** — SOUL.md, IDENTITY.md, HEARTBEAT.md, MEMORY.md per agent
11. **Distribution via npx** — `npx create-orgagent my-company` for one-command setup
12. **Claude Code scheduling** — `/loop` or `/schedule` replaces custom scheduler
13. **Environment variable agent identification** — `ORGAGENT_CURRENT_AGENT` for hook scripts
14. **Workspace memory only** — disable Claude Code auto-memory for agents, use org/agents/{name}/MEMORY.md
15. **Model tiering** — opus for CEO/CAO, sonnet for managers, haiku for workers
16. **Dynamic tool permissions** — CAO + manager determine tools; agents can request new tools
17. **Chain-of-command data access** — agents only see data relevant to their role; enforced by hooks
18. **Currency configurable** — ISO 4217 code set during onboarding, never hardcoded
19. **master-gpt-prompter** — meta-skill ensuring all prompts are maximally potent
20. **Agent Teams** — available for exceptional no-brainer cases only
21. **User custom rules** — collected during onboarding, respected by all agents
22. **Chat layer / chain-of-command** — structured communication enforced by hooks; who can message whom, message types, threading, cross-department protocol
23. **Three-layer observability** — activity stream (hook-forced), current-state.md (agent-maintained, hook-enforced), thread-based chat (replaces inbox/outbox)
24. **Thread-based chat** — conversations in single files (org/threads/), greppable message IDs, lightweight inbox notifications, outbox eliminated
25. **Hook enforcement of communication** — remind-state-update (periodic), require-state-and-communication (blocks session end)
26. **Continuous operation (Ralph Wiggum)** — `/run-org` triggers self-sustaining heartbeat loop via Stop hook. Org cycles until quiescent. Board intervenes only for approvals. `/cancel-org` to stop.
27. **Two operation modes** — Mode A: Continuous (`/run-org`), Mode B: Scheduled wake-up (`/loop 30m /run-org`)
28. **20 system skills total** — +browser, +create-skill
29. **Browser automation** — Playwright MCP (autonomous headless), Playwright CLI (token-efficient), Claude in Chrome (interactive). Privileged tool — CAO determines access.
30. **Skill library** — org/skills/ with registry, versioning, sharing, permission-controlled access. CAO/supervisors create skills via /create-skill.

---

## Architecture Summary

```
Human (Board) → Claude Code session (skills + natural language)
       ↓
       → GUI Dashboard (localhost:3000, optional)
       ↓
Governance Layer (Hooks: audit, budget, approval gates)
       ↓
Agent Runtime (claude --agent <name> invocations)
  ├── CEO Agent (opus — strategic leadership)
  ├── CAO Agent (opus — creates/manages agent workforce)
  └── Dynamic Agents (sonnet/haiku — hired by CAO as needed)
       ↓
Shared Org State (Markdown files in org/ folder)
  ├── alignment.md, config.md, orgchart.md
  ├── board/ (decisions, approvals, audit log)
  ├── initiatives/ (strategic goals)
  ├── budgets/ (spending tracking)
  ├── messages/ (broadcast, urgent)
  └── agents/ (individual workspaces with SOUL, IDENTITY, etc.)
```

---

## Implementation Phases

1. **Foundation** — Project structure, CLAUDE.md, settings.json, rules, package.json
2. **Skills** — All 20 system skill definitions
3. **Core Agents** — CEO + CAO agent definitions
4. **Scripts** — Heartbeat orchestration + 11 hook scripts (observability, governance, communication)
5. **GUI Dashboard** — Express.js server + dark-theme SPA with 8 views
6. **Distribution** — create-orgagent npm package + README
7. **Testing & Polish** — End-to-end verification of all 14 test scenarios

---

## Total Files to Create: ~50 files across 7 phases
