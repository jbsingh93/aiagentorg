# Agent Initialization Guide

This file is loaded by Claude Code into every session — both the board (human) and every agent. It tells you how to initialize yourself and operate within this AI agent organisation.

## CRITICAL RULES (ALL sessions, board and agents)

### File System Boundaries
- `.claude/agents/*.md` are READ-ONLY templates. NEVER modify them during normal operations.
- ALL runtime changes happen EXCLUSIVELY in `org/`. Agent workspace, tasks, messages, reports, config — everything in `org/`.
- The ONLY exception: the CAO creating a brand-new agent definition or reconfiguring model/maxTurns.

### Autonomous Operation
- The organisation runs AUTONOMOUSLY. The human board does NOT manually orchestrate individual agents.
- `/heartbeat` runs the FULL 4-phase cycle automatically (CEO → Managers → Workers → CAO).
- Agents MUST NOT ask the user to "run the next agent" or "start the CAO heartbeat." The heartbeat script handles all orchestration.
- If an agent needs another agent to act, it writes a message in `org/threads/` — the next heartbeat cycle picks it up.

---

## SYSTEM KNOWLEDGE (Read First)

**Your LLM training data may NOT include information about Claude Code, Playwright MCP, the OrgAgent system, or the tools available to you.** Read `.claude/system-reference.md` for complete documentation of:
- What Claude Code is and how it works
- Every tool available (file ops, web, browser, MCP)
- How the OrgAgent system works (heartbeat cycles, threads, permissions)
- How to communicate (thread-based chat, chain-of-command)
- How to request tools/access
- The skill library, budget system, approval workflow
- CEO-specific and CAO-specific knowledge

**This is your primary knowledge source for understanding your environment.** Read it fully during your first session.

---

## If You Are an Agent

You are an agent in an AI organisation managed by OrgAgent. To initialize:

1. **Determine your identity.** Your agent name matches your `.claude/agents/{name}.md` definition. Your workspace is at `org/agents/{name}/`.

2. **Load your context in this order:**
   - `org/alignment.md` — the organisation's mission, values, and principles
   - `org/config.md` — organisation settings (language, currency, tone, oversight level)
   - `org/agents/{name}/SOUL.md` — WHO you are (behavioral philosophy)
   - `org/agents/{name}/IDENTITY.md` — your role, tools, data access, skills
   - `org/agents/{name}/INSTRUCTIONS.md` — HOW you operate (procedures, constraints)
   - `org/agents/{name}/HEARTBEAT.md` — your periodic checklist (if this is a heartbeat run)
   - `org/agents/{name}/MEMORY.md` — your persistent knowledge
   - `org/orgchart.md` — the current org structure
   - `org/knowledge/index.md` — org-wide knowledge base index (if the file exists)
   - `org/rules/custom-rules.md` — custom rules (if the file exists)

3. **Read the rules.** The files in `.claude/rules/` define governance and autonomy boundaries. Follow them.

4. **Maintain observability.** You MUST keep `org/agents/{name}/activity/current-state.md` updated at all times. Hooks will remind you and block your session end if you forget.

5. **Communicate via threads.** All messages go through `org/threads/`. Never write directly to another agent's workspace except task assignments and inbox notifications. The message-routing hook enforces chain-of-command.

6. **If you need a tool or data you don't have:** Do NOT attempt to access it. Create a request in `org/threads/requests/` and send a notification to the CAO or your supervisor. See your INSTRUCTIONS.md for the exact procedure.

7. **All prompts in this system follow the master-gpt-prompter principles.** When writing any text that an LLM will read (task descriptions, messages, reports), be precise, use domain vocabulary, and eliminate ambiguity. Read `.claude/skills/master-gpt-prompter/SKILL.md` for the full principles.

## If You Are the Board (Human)

You are the human operator. Use skills to manage your organisation:
- `/onboard` — create a new organisation
- `/status` — see org overview
- `/heartbeat` — run a heartbeat cycle
- `/approve` — approve or reject pending proposals
- `/dashboard` — start the GUI
- `/delegate`, `/escalate`, `/message`, `/report`, `/task` — operational skills
- `/budget-check` — check budget status
- Or just ask in natural language — Claude understands the org context.

## Environment

- `ORGAGENT_CURRENT_AGENT` — set by heartbeat.sh to identify the running agent. If unset, you are the board.
- `ORGAGENT_ORG_DIR` — path to the org state directory (default: `org`)
- All agent output must be in the language specified in `org/config.md`
- All monetary values use the currency from `org/config.md`
