# OrgAgent

> Dynamic, self-organizing AI agent organisations powered by Claude Code.

Create an AI company where a CEO delegates to managers, managers delegate to workers, and a Chief Agents Officer dynamically hires and fires agents as business needs evolve — all running on Claude Code with markdown files as the database.

## Quick Start

```bash
npx create-orgagent my-company
cd my-company
claude
```

Then type `/onboard` to start the alignment conversation.

## Features

- **Self-organizing** — CAO dynamically creates agents based on business needs
- **OpenClaw-inspired** — Each agent has SOUL, IDENTITY, INSTRUCTIONS, MEMORY, HEARTBEAT
- **Filesystem = Database** — All state in readable markdown files
- **Chain-of-command** — Communication and data access follow org hierarchy
- **Three-layer observability** — Activity streams, current-state tracking, thread-based chat
- **Governance hooks** — 11 hooks enforce audit trails, budgets, approvals, and access control
- **Dark-theme dashboard** — Web GUI with org chart, task board, budget charts, thread view
- **Autonomous operation** — Schedule heartbeats for fully autonomous orgs
- **Multilingual** — Set the org language during onboarding
- **Configurable oversight** — Choose: approve-everything, approve-strategy-only, or hands-off

## How It Works

1. **Onboard** — Interactive alignment conversation collects mission, values, goals, budget, language
2. **Bootstrap** — Creates org structure with CEO + CAO agents
3. **Heartbeat** — 4-phase cycle: CEO (strategy) → Managers (coordination) → Workers (execution) → CAO (workforce review)
4. **Grow** — CAO proposes new agents as needs emerge; board approves
5. **Communicate** — Thread-based chat with chain-of-command enforcement
6. **Monitor** — Every action logged, every agent's state observable in real-time

## Architecture

```
Human (Board) → Claude Code session
       |
Governance Layer (11 hooks)
       |
Agent Runtime (claude --agent <name>)
  ├── CEO (opus) — strategy & delegation
  ├── CAO (opus) — workforce management
  └── Dynamic Agents (sonnet/haiku)
       |
Org State (markdown files)
  ├── org/alignment.md, config.md, orgchart.md
  ├── org/threads/ — conversation threads
  ├── org/agents/ — per-agent workspaces
  └── org/budgets/, board/, initiatives/
```

## Skills (16)

| Skill | Purpose |
|-------|---------|
| `/onboard` | Create a new organisation |
| `/heartbeat` | Run agent heartbeat cycle |
| `/status` | Show org overview |
| `/approve` | Approve/reject proposals |
| `/delegate` | Assign tasks to subordinates |
| `/escalate` | Escalate issues up the chain |
| `/message` | Send inter-agent messages |
| `/report` | Write status reports |
| `/task` | Manage tasks (assign/list/view/move) |
| `/budget-check` | Check budget status |
| `/hire-agent` | CAO: create new agent |
| `/fire-agent` | CAO: deactivate agent |
| `/reconfigure-agent` | CAO: modify agent |
| `/review-work` | Review subordinate output |
| `/dashboard` | Start web GUI |

## Saving Your Org to GitHub

Your AI organisation is version-controlled. Every agent, thread, task, and decision is a file — push it to a **private** GitHub repo to save your org's state.

```bash
# After /onboard creates your org:
git init
git add -A
git commit -m "Initial org: my-company"

# Create a PRIVATE repo on GitHub, then:
git remote add origin https://github.com/yourusername/my-company.git
git push -u origin main
```

**What gets saved:**
- `org/` — your entire org (agents, threads, tasks, budgets, alignment)
- `.claude/agents/` — all agent definitions (including CAO-created ones)
- `.claude/skills/` — all skills (system + custom org skills)
- Everything the org creates and evolves

**What stays local (sensitive):**
- `org/agents/*/credentials/` — API keys and secrets
- `org/.browser-profiles/` — browser login state
- `.claude/settings.local.json` — your personal preferences

Push regularly and your org survives anything. Clone it on another machine and it picks up right where it left off.

## Requirements

- **Node.js 20+**
- **Claude Code** (`npm install -g @anthropic-ai/claude-code` or Claude Desktop)
- **Anthropic API key** (or Claude Max subscription)
- **jq** (for hook scripts) — `winget install jqlang.jq` on Windows

## License

MIT
