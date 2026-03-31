---
name: help
description: "Show all available commands, features, and how to use OrgAgent. Reads the system reference and lists every skill with usage examples."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Glob
argument-hint: "[topic] (optional — e.g., /help heartbeat, /help browser, /help skills)"
---

# OrgAgent Help

Show the user everything they can do with OrgAgent.

## If no argument provided — show full overview

Read `.claude/system-reference.md` Section 20 (Board commands) and present this:

```
╔══════════════════════════════════════════════════════════════╗
║                    OrgAgent — Help                          ║
╚══════════════════════════════════════════════════════════════╝

GETTING STARTED
  /onboard              Create a new AI agent organisation (interactive)
  /status               Show org overview (agents, tasks, budget)
  /help [topic]         Show this help (or help on a specific topic)

RUNNING THE ORGANISATION
  /run-org [max-cycles] Start continuous autonomous operation (recommended)
  /heartbeat [agent]    Run one heartbeat cycle (all agents or single)
  /cancel-org           Stop a running continuous loop

BOARD ACTIONS
  /approve              List, approve, or reject pending proposals
  /delegate [to] [task] Assign a task to an agent
  /escalate [agent]     Escalate an issue up the chain
  /message [from] [to]  Send a message between agents

MONITORING
  /status               Org overview with agent count, tasks, budget
  /budget-check [agent] Check budget (org-wide or per agent)
  /dashboard            Start web GUI at localhost:3000

TASK MANAGEMENT
  /task list [agent]    List tasks (all or per agent)
  /task view [id]       View a specific task
  /task assign [to]     Assign a new task (same as /delegate)
  /task move [id] [status]  Move task between backlog/active/done

AGENT MANAGEMENT (CAO/Board only)
  /hire-agent [role]    Create a new agent
  /fire-agent [name]    Deactivate an agent
  /reconfigure-agent    Modify an agent's config

SKILLS & TOOLS
  /create-skill [name]  Create a custom reusable workflow
  /browser [url]        Browser automation (Playwright)
  /report [agent]       Generate a status report
  /review-work [agent]  Review a subordinate's completed work

NATURAL LANGUAGE
  You can also just type naturally:
  • "What's the org status?"
  • "Tell the CEO to focus on marketing"
  • "Approve the SEO agent hire"
  • "How much budget is left?"
  • "Start the organisation"

QUICK START
  1. /onboard           → Set up your org (first time only)
  2. /run-org            → Let it run autonomously
  3. /approve            → Approve proposals as they come
  4. /dashboard          → Watch it in the web GUI

Type /help [topic] for detailed help on any command.
```

## If argument provided — show detailed help for that topic

Read the relevant skill file and present detailed usage:

### Topic: "onboard"
Read `.claude/skills/onboard/SKILL.md` first 30 lines. Explain: Interactive alignment conversation, collects 13 areas of information, creates the entire org structure. One-time use. Run `/onboard` with no arguments.

### Topic: "run-org"
Read `.claude/skills/run-org/SKILL.md`. Explain: Continuous autonomous operation using the Ralph Wiggum pattern. Runs heartbeat cycles until all work is processed. Board approves proposals during the loop. `/run-org` or `/run-org 20` for max 20 cycles.

### Topic: "heartbeat"
Read `.claude/skills/heartbeat/SKILL.md`. Explain: Single heartbeat cycle with 4 phases (CEO → Managers → Workers → CAO). Use `/heartbeat` for full cycle, `/heartbeat ceo` for single agent (debugging only).

### Topic: "approve"
Read `.claude/skills/approve/SKILL.md`. Explain: `/approve` lists pending proposals. `/approve approve [id]` approves. `/approve reject [id] [reason]` rejects.

### Topic: "delegate"
Read `.claude/skills/delegate/SKILL.md`. Explain: Creates a task for a subordinate with chain-of-command validation. `/delegate marketing-manager "Create SEO strategy"`.

### Topic: "browser"
Read `.claude/skills/browser/SKILL.md`. Explain: Playwright MCP for website automation. Fallback when no API exists. `/browser https://example.com "sign up for account"`.

### Topic: "skills" or "skill-library"
Read `org/skills/registry.md` if it exists. Explain: Custom reusable workflows. `/create-skill` to create new ones. List all available custom skills from the registry.

### Topic: "budget"
Read `.claude/skills/budget-check/SKILL.md`. Explain: `/budget-check` for org overview, `/budget-check [agent]` for single agent. Shows allocation, spent, remaining.

### Topic: "dashboard"
Read `.claude/skills/dashboard/SKILL.md`. Explain: Starts web GUI at localhost:3000. 8 views: Overview, Org Chart, Agents, Tasks, Threads, Budget, Board, Activity.

### Topic: "agents"
Read `org/orgchart.md` if it exists. List all agents with status. Explain: CAO creates agents via `/hire-agent`. Agents have SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY.

### Topic: "autonomy"
Read `.claude/system-reference.md` Section 0. Explain the core philosophy: agents are fully autonomous, can build connectors, create systems, hire freelancers. Bounded by alignment and permissions only.

### Topic: any other
Search `.claude/skills/*/SKILL.md` for a matching skill name. If found, read and explain. If not found: "No help found for '{topic}'. Type /help to see all commands."
