# OrgAgent

> Fully autonomous, self-organizing AI agent organisations powered by Claude Code.

Create an AI-driven company where an Alignment Board governs, a CEO delegates strategy, a CAO dynamically hires agents, and workers execute real work — all running autonomously on Claude Code with markdown files as the database. The organisation builds its own integrations, creates its own internal systems, and operates continuously without human intervention.

**The human sets the alignment. The AI runs the company.**

## Quick Start

```bash
git clone https://github.com/jbsingh93/aiagentorg.git my-company
cd my-company
npm install
claude
```

Then type `/onboard` — the dashboard opens automatically in your browser. Continue the onboarding conversation in the **Chat tab**. Type `/help` at any time.

## GUI Dashboard

The dashboard at `localhost:3000` is your command center:

- **Chat** — talk to your org directly from the browser (onboarding, commands, natural language)
- **Overview** — key metrics at a glance
- **Org Chart** — interactive D3.js hierarchy visualization
- **Agents** — click any agent for full detail (SOUL, tasks, state)
- **Tasks** — kanban board (backlog / active / done)
- **Threads** — conversation feed with message search
- **Budget** — spending charts and per-agent breakdown
- **Board** — pending approvals with approve/reject buttons
- **Activity** — searchable audit log
- **Live Feed** — real-time terminal view of every agent action (WebSocket)

Start it anytime: `/dashboard` or `node gui/server.js`

## What Makes This Different

This is NOT a chatbot. This is NOT a workflow tool. This is an **autonomous organisation** where:

- **Agents build their own integrations** — need Shopify? The DevOps team researches the API, builds a connector, creates a skill. No pre-built integrations needed.
- **Agents create their own systems** — need financial tracking? The CFO designs the ledger. Need a CRM? The sales team builds it. Everything is dynamic.
- **An Alignment Board governs everything** — a constitutional governance layer that approves proposals, detects drift, and can halt agents that violate the mission. The human only intervenes for core value changes.
- **The org runs continuously** — `bash scripts/run-org.sh infinite` and the org cycles through heartbeats until all work is done, waits, then checks again. Like a real company.
- **Every action is observable** — real-time Live Feed via WebSocket, activity streams per agent, thread-based chat, full audit trail.

## How It Works

```
┌─────────────────────────────────────────────────────┐
│              ALIGNMENT BOARD (AI Governance)          │
│  Constitutional hooks (always-on enforcement)         │
│  Alignment Review Agent (Phase 0 of heartbeat)        │
│  Protected alignment document (human-only edits)      │
├─────────────────────────────────────────────────────┤
│              AGENT HIERARCHY                          │
│  CEO (opus) → Managers (sonnet) → Workers (haiku)     │
│  CAO (opus) — hires/fires/reconfigures agents         │
├─────────────────────────────────────────────────────┤
│              OBSERVABILITY                            │
│  Activity streams │ Current state │ Thread-based chat │
│  Live Feed (WebSocket) │ GUI Dashboard (localhost:3000)│
├─────────────────────────────────────────────────────┤
│              SHARED STATE (Markdown files in org/)     │
│  alignment │ config │ orgchart │ threads │ budgets     │
│  connectors │ skills │ orders │ finance │ customers    │
└─────────────────────────────────────────────────────┘
```

### The Heartbeat Cycle (5 Phases)

```
Phase 0: Alignment Board — governance review, approve/reject proposals, detect drift
Phase 1: CEO — strategic direction, delegation
Phase 2: Managers — coordinate teams, delegate to workers (parallel)
Phase 3: Workers — execute tasks, produce deliverables (parallel)
Phase 4: CAO — review org health, propose hires/changes
```

## Features

### Core
- **Self-organizing** — CAO dynamically creates agents as business needs evolve
- **OpenClaw-inspired workspaces** — Each agent has SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY
- **Filesystem = Database** — All state in readable markdown files, git-compatible
- **Chain-of-command** — Communication and data access enforced by hooks

### Governance
- **Alignment Board** — Three-layer AI governance: constitutional hooks + review agent + protected alignment doc
- **Protected constitution** — `org/alignment.md` can ONLY be edited by the human. Hooks block all agent writes.
- **Tiered violation response** — Soft (warn), Hard (halt agent), Nuclear (halt ALL agents)
- **14 governance hooks** — Enforce access control, message routing, alignment checking, spending limits, audit logging
- **Configurable oversight** — Maximum autonomy, strategic oversight, or conservative

### Autonomy
- **Agents build their own integrations** — Research APIs, install MCP servers, write connectors, handle auth via browser
- **Agents create internal systems** — Finance, CRM, orders, inventory — built on demand when the business needs them
- **Browser automation** — Playwright MCP for websites with no API (create accounts, fill forms, extract data)
- **Skill library** — CAO/managers create reusable workflow skills, shared across the org
- **External hiring** — Agents can outsource impossible tasks to freelancers/companies
- **Temporal awareness** — All agents use current date in research, never recommend outdated tools

### Operations
- **Continuous operation** — `bash scripts/run-org.sh infinite` runs the org autonomously
- **Real-time Live Feed** — WebSocket-powered dashboard shows every agent action as it happens
- **Dark-theme GUI** — Org chart, task board, thread view, budget charts, approval management
- **Thread-based chat** — Greppable message IDs, chain-of-command routing, department channels
- **Three-layer observability** — Activity streams (hook-forced), current-state tracking (agent-maintained), conversation threads

### Business
- **Multilingual** — Set the org language during onboarding
- **Multi-currency** — Configure currency (ISO 4217) during onboarding
- **Spending governance** — Configurable limits for real-money spending (ads, subscriptions, freelancers)
- **Works with subscriptions or API keys** — Claude Max/Pro users pay nothing extra

## Skills (21)

| Skill | Purpose |
|-------|---------|
| `/onboard` | Create a new organisation (deep alignment conversation) |
| `/run-org` | Start continuous autonomous operation |
| `/heartbeat` | Run a single heartbeat cycle |
| `/cancel-org` | Stop continuous operation |
| `/status` | Show org overview |
| `/approve` | Approve/reject pending proposals |
| `/delegate` | Assign tasks to subordinates |
| `/escalate` | Escalate issues up the chain |
| `/message` | Send inter-agent messages |
| `/report` | Write status reports |
| `/task` | Manage tasks (assign/list/view/move) |
| `/budget-check` | Check budget status |
| `/hire-agent` | CAO: create new agent |
| `/fire-agent` | CAO: deactivate agent |
| `/reconfigure-agent` | CAO: modify agent config |
| `/review-work` | Review subordinate output |
| `/dashboard` | Start web GUI (localhost:3000) |
| `/browser` | Browser automation via Playwright |
| `/create-skill` | Create custom reusable workflows |
| `/help` | Full command reference |

## Saving Your Org to GitHub

Your AI organisation is version-controlled. Push to a **private** GitHub repo to save your org's state.

```bash
git init
git add -A
git commit -m "Initial org: my-company"
git remote add origin https://github.com/yourusername/my-company.git
git push -u origin main
```

Clone on another machine — the org picks up where it left off.

## Requirements

- **Node.js 20+**
- **Claude Code** — `npm install -g @anthropic-ai/claude-code` or Claude Desktop
- **Claude subscription** (Claude Max/Pro) OR Anthropic API key
- **jq** — `winget install jqlang.jq` on Windows, `brew install jq` on Mac

## License

MIT
