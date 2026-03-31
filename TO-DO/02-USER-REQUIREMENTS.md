# User Requirements — Complete Record of All Inputs & Decisions

**Date:** 2026-03-31
**User:** Julia

---

## Original Request

> "I have an idea of creating an AI agent system that can run an organisation like the screenshot I gave you. Now please do extensive research into this open source project: https://github.com/paperclipai/paperclip — and tell me if I can use that as base for that system?"

The user provided a screenshot (`Skaermbillede 2026-03-30 225813.png`) showing a high-level diagram of an AI agent organisation structure.

---

## Screenshot Analysis

The screenshot (in Danish) shows:
- **"5. AI agent organisation"** — numbered section header
- **Masterboard** at the top — human governance layer
- **Dynamic governance** ("Dynamisk governance") — oversight of all activities
- **"Oversigt over alle aktiviteter for at folge sig selv"** — Overview of all activities to follow itself
- **CEO Agent** in the center, delegating downward
- **Department Managers:** Post/Sales Manager, Creative Manager, Production Manager, Finance Manager, CRM/Customer Manager, IT/Tech Manager, Marketing Manager
- **Worker Agents** under each manager (Sales agent, Webshop agent, Content production agent, Video production agent, etc.)
- **Agent chat / messaging** panel on the right side — inter-agent communication system

---

## Pivot: From Paperclip to Native Claude Code

After initial Paperclip research, the user pivoted:

> "NOW DO EXTENSIVE RESEARCH AND ULTRATHINK ABOUT HOW I CAN MAKE THIS AI AGENT ORGANISATION STRUCTURE USING AGENT SKILLS? WHERE CLAUDE CODE WILL BE THE LLM, SKILLS, MARKDOWN FILES AND FOLDERS WILL BE SPAWN AUTOMATICALLY AND BE THE HOST OF ALL THE INFORMATION, WHERE HOOKS, SUBAGENTS, AGENT TEAMS (CLAUDE CODE FEATURES) WILL BE UTILIZED, AND A SIMPLE GUI WILL BE THE COMMAND CENTRAL. HOW CAN I DO THIS THIS WAY? VIA A CLI AND PLEASE MAKE ALL THE SPEC TO CREATE IT."

---

## Q&A Round 1: Core Decisions

### Q: What will the agents actually DO?
**A: Real work (Recommended)**
> Agents actually execute tasks — write content, generate reports, manage files, call APIs, etc. Each agent produces real deliverables.

### Q: How should the organisation run?
**A: Both (CLI + scheduled)**
> On-demand CLI for direct commands, plus optional cron-based heartbeats for autonomous operation.

### Q: Language — Danish or English?
**A: Dynamic — set during onboarding**
> "WE NEED AN ONBOARDING EVERY TIME A NEW AI AGENT ORGANISATION WILL BE SPUN UP. IN HERE WE WILL HAVE A DEEP CONVERSATION WITH THE USER. ABOUT THE ALIGNMENT (ALSO ABOUT LANGUAGE)"

### Q: How big should the initial build be?
**A: Dynamic and organic**
> "SO IT SHOULD BE DYNAMIC. WHAT THE KICKOFF WILL BRING ARE MERELY THE ALIGNMENT BOARD AND THE KICKOFF OF A CEO AGENT AND CAO (CHIEF AGENTS OFFICER)-AGENT. FROM THERE IT'S UP TO THE INITIAL BUSINESS GOAL, THE ALIGNMENT AND WITH THE CAO-AGENT TO ADD AGENTS AFTER NEED. EVEN THE CEO-AGENT CAN BE REPLACED, LIKE IN REAL LIFE. EACH AGENT SHOULD HAVE THE SAME CAPABILITIES LIKE AN AI AGENT LIKE OPENCLAW (PLEASE MAKE EXTENSIVE RESEARCH TO UNDERSTAND HOW https://github.com/openclaw/openclaw WORKS)"

**Key revelations from this answer:**
1. The org starts with ONLY Board + CEO + CAO
2. The CAO dynamically creates new agents based on business needs
3. Even the CEO can be replaced (like in real life)
4. Each agent should have OpenClaw-like autonomous capabilities
5. The system is self-organizing, not pre-defined

---

## Q&A Round 2: Deep Clarifications

### Q: How should the CAO create agents technically?
**A: Self-creating (Recommended)**
> The CAO writes brand new agent definition files from scratch. Fully dynamic — any role can be invented on the fly based on business needs.

### Q: What does 'OpenClaw-like capabilities' mean?
**A: Structured autonomy**
> Each agent can do real work (files, code, web) but must follow the org's delegation chain. No freelancing — all work tied to assigned tasks.

### Q: What should the onboarding cover?
**A: Deep alignment**
> Everything: company name, mission, language, initial goals, budget limits, industry, target market, key constraints, PLUS values/principles, decision-making style, risk tolerance, communication preferences, human oversight level, ethical boundaries.

### Q: Should I research OpenClaw?
**A: Yes, research it**
> Do the deep research into OpenClaw so you understand the full autonomous agent model and can replicate it.

---

## Q&A Round 3: Final Details

### Q: Board approval for CAO's first hires?
**A: Configurable in onboarding**
> The onboarding conversation asks the user what oversight level they want. Some users want full control, others want hands-off. This is configurable.

### Q: How polished should the GUI be?
**A: Modern dashboard (Recommended)**
> Styled with a dark theme, org chart tree visualization, kanban board, budget charts. Professional-looking but still simple tech (no React).

---

## Derived Requirements (from user inputs)

1. **Onboarding is mandatory** — no org can start without alignment
2. **CAO is a first-class concept** — not just another manager, but the agent-workforce-manager
3. **Agent replacement is a feature** — any agent, including CEO, can be fired/replaced
4. **OpenClaw workspace model** — each agent needs SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY
5. **Filesystem is the database** — all state in markdown files
6. **Self-modifying system** — the CAO literally writes new `.claude/agents/*.md` files
7. **Three oversight levels** — approve-everything / approve-strategy-only / hands-off
8. **Real deliverables** — agents produce actual content, reports, code
9. **Heartbeat + on-demand** — both scheduled and manual operation
10. **Modern dark-theme GUI** — D3.js org chart, CSS grid kanban, Chart.js budget charts
11. **Language is per-org** — set during onboarding, not hardcoded

---

## Q&A Round 3: Architecture & Distribution (2026-03-31, later session)

### Q: Should the project be a separate CLI (`orgagent`) or native Claude Code?
**A: Native Claude Code**
> "I WAS THINKING THAT THIS PROJECT SHOULD WORK WITH CLAUDE CODE. MEANING THAT ITS A PLUGIN FOR CLAUDE CODE AND ARE PROMPTED/CREATED IN SUCH WAY THAT WHEN INITIALIZED IT WILL DYNAMICALLY USE CLAUDE CODE AS ITS ENGINE, SO ITS BASICALLY A SKILL WITH THE TOTAL PROJECT INSTRUCTION IN IT."

**Key revelation:** The project should NOT have a separate `orgagent` CLI. Instead:
- The user's Claude Code session IS the board interface
- Skills replace all CLI commands (`/onboard`, `/heartbeat`, `/approve`, etc.)
- Claude Code IS the engine via `claude --agent <name>` CLI invocations
- No separate framework or wrapper needed

### Q: How do we handle scheduling?
**A: Claude Code has built-in scheduling**
> "FOR SCEDULER CLAUDE CODE ALREADY HAVE THAT FEATURE PLEASE DO WEB SEARCH ABOUT CLAUDE CODE SCHEDULE."

**Claude Code scheduling options:**
- `/loop 2h /heartbeat` — session-scoped polling (3-day max)
- Desktop Tasks — persistent, runs on your machine, survives restarts
- `/schedule` — cloud triggers (requires git repo, 1-hour minimum)

**Eliminated:** All custom scheduling scripts.

### Q: How do I share this project with others?
**A: `npx create-orgagent` (npm scaffolding tool)**
> "BUT HOW DO I SHARE THIS PROJECT WITH OTHERS THEN AND MAKE IT EXTREMELY SIMPLE TO INSTALL AND USE?"

**Decision:** Package as npm scaffolding tool. Three commands to go:
```bash
npx create-orgagent my-company
cd my-company
claude
# then: /onboard
```

**Alternative:** GitHub template repository for fork-and-go distribution.

---

## Derived Requirements — Updated (from Round 3)

1. **No separate CLI** — the `orgagent` wrapper and all `scripts/cli/*.sh` are eliminated
2. **Skills are the interface** — 15 skills replace 14 CLI commands
3. **Claude Code scheduling** — `/loop`, Desktop Tasks, or `/schedule` replace custom scheduler
4. **npm distribution** — `npx create-orgagent` for one-command project setup
5. **GitHub template** — alternative distribution for users who prefer git
6. **Environment variable agent ID** — `ORGAGENT_CURRENT_AGENT` set by heartbeat script
7. **Workspace memory only** — disable Claude Code auto-memory for agent sessions
8. **Model tiering** — opus/sonnet/haiku based on agent role and budget

---

## Non-Requirements (explicitly NOT wanted)

- NOT Paperclip (explored but pivoted away from)
- NOT a chatbot interface
- NOT pre-defined static org chart (must be dynamic)
- NOT React for GUI (vanilla HTML/CSS/JS + D3/Chart.js)
- NOT a database (PostgreSQL, SQLite, etc.) — filesystem only
- NOT a simulation — agents do REAL work
- NOT a separate CLI wrapper (use Claude Code directly)
- NOT a custom scheduler (use Claude Code built-in scheduling)
- NOT Agent Teams for normal operation (only for exceptional no-brainer cases)

---

## Q&A Round 4: Deep Architecture Refinements (2026-03-31, later session)

### Q: Should all agents have the same tools?
**A: No — CAO + manager determine tools per agent**
> "IMPORTANT THAT THIS IS UP TO THE CAO-AGENT AND EVT. A EXECUTIVE/MANAGER AGENT TO DETERMINE WHICH TOOLS EACH AGENT SHOULD HAVE IN ORDER TO COMPLETE ITS TASKS. IN ADDITION AN AGENT CAN REQUEST TO BE UPDATED WITH NEW TOOLS PERMISSIONS FROM THE CAO-AGENT IF THE AGENT FINDS OUT IT NEEDS A TOOL TO BE ABLE TO SOLVE A TASK IN HAND."

**Key requirements:**
- CAO + agent's manager determine tool set at creation time
- Agents can REQUEST new tools from CAO
- CAO consults with agent's manager before granting
- ALL requests and decisions must be logged and tracked

### Q: Should all agents see all data?
**A: No — chain-of-command data access**
> "NOT ALL AGENTS SHOULD HAVE ACCESS TO ALL DATA AT ALL TIME... THIS IS ALSO A CHAIN-OF-COMMAND AND WHAT DATA/INFORMATION EACH AGENT SHOULD BE ABLE TO ACCESS TO (THEY CAN REQUEST PERMISSION BY THEIR SUPERIOR AGENT FOR SPECIFIC DATA, LIKE IT IS IN REAL LIFE COMPANIES). ONLY THE AGENTS WHERE THE BUDGET CONTEXT ARE RELEVANT FOR SHOULD HAVE THIS DATA."

**Key requirements:**
- Data access follows chain-of-command (like real companies)
- Workers don't see budgets unless relevant
- Workers don't see other departments' data
- Agents can REQUEST data access from their superior
- Enforced by hooks, not just instructions

### Q: Should the currency be hardcoded?
**A: No — determined during onboarding**
> "WE CANT BE DETERMINISTIC AND HARD-CODE THE CURRENCY AS THIS IS SOMETHING THE USER IN THE ALIGNMENT KICKOFF DISCUSSION WILL ANSWER AND BASED ON THE MARKETS THE ORGANISATION ARE WORKING IN."

### Q: How should CLAUDE.md work?
**A: Agent initialization guide, not board alignment**
> "WE SHOULD MERELY MAKE IT CLEAR WITH THE CLAUDE.MD HOW EACH AGENT CAN INITIALIZE ITSELF AND GET UP TO DATE. SO THE CLAUDE.MD FILE WOULD BE A CLEAR INSTRUCTION ON HOW EACH AGENT CAN INITIALIZE ITSELF AND GET UP TO DATE."

### Q: Should all prompts be optimized?
**A: Yes — via master-gpt-prompter skill**
> "ALL PROMPTS IN ALL AGENTS, SKILLS AND ANY INSTRUCTION THAT A LLM SHOULD READ SHALL ALWAYS BE OPTIMIZED AND BE MORE POTENT BY ALWAYS USING THE .claude\skills\master-gpt-prompter SKILL"

### Q: Should users be able to add custom rules?
**A: Yes — collected at kickoff and stored in org/rules/**
> "A USER CAN OF COURSE ADD THEIR OWN, ALSO AT KICKOFF AND THESE NEEDS TO BE RESPECTED."

### Q: Who can order the CAO to create agents?
**A: Executive-level agents (not just CEO)**
> "IMPORTANT THAT THE CAO GETS DIRECT ORDERS FROM AN EXECUTIVE AGENT TO CREATE NEW AGENTS OR FOLDERS."

### Q: Should we limit context per agent?
**A: No — use as much as necessary**
> "NO CONTEXT BUDGET. USE AS MUCH AS NECESSARY!!"

### Q: How to enforce skill access control?
**A: Via hooks**
> "HOW CAN WE VIA CODE ENSURE THIS? VIA HOOKS OR WHAT"
Decision: PreToolUse hook on Skill tool, checking ORGAGENT_CURRENT_AGENT.

### Q: Should Agent Teams be available?
**A: Yes, but only for exceptional cases**
> "WE NEED TO BE ABLE TO SPIN UP AGENT TEAMS WHEN NEEDED. BUT THIS HAVE TO BE DONE ONLY WHEN VERY VERY NO-BRAINER CASE."

---

## Q&A Round 5: Testing Observations & Continuous Operation (2026-03-31, post-implementation)

### Observation: Onboarding modified .claude/agents/ instead of org/agents/
**Fix:** `.claude/agents/` is now READ-ONLY after creation. All runtime changes happen in `org/` only. Hard rules added to governance.md, structured-autonomy.md, and both agent definitions.

### Observation: After /heartbeat ceo, Claude asked to manually start /heartbeat cao
**Fix:** Agents NEVER ask the user to run other agents. The heartbeat script runs all 4 phases automatically. Communication between agents goes through threads. Hard constraints added to agent definitions.

### Q: How to make it behave like a real organisation that runs continuously?
**A: Ralph Wiggum pattern**
> "CANT WE TRIGGER AN INFINITE LOOP VIA HOOKS... LIKE THE RALPH WIGGUM APPROACH"

**Decision:** Use the Ralph Wiggum Stop-hook pattern from Claude Code. One `/run-org` command starts a self-sustaining loop:
- Heartbeat cycles run automatically until all work is processed
- The Stop hook checks for pending work after each cycle
- If work exists → block exit → run another cycle
- If quiescent → allow exit
- Board intervenes only for approvals
- Safety: max 10 cycles per run, stale detection after 3 unchanged cycles

**Two operation modes:**
- Mode A: `/run-org` — continuous until quiescent
- Mode B: `/loop 30m /run-org` — scheduled wake-up for fully autonomous operation

**New skills:** `/run-org` (start loop) + `/cancel-org` (stop loop) = 18 total skills

---

## Q&A Round 6: Autonomy Philosophy & Dynamic Capabilities (2026-03-31, post-testing)

### Context: Dropshipping Ecom Stress Test
User tested the vision against a real business scenario (dropshipping ecommerce). This revealed gaps in external service integration, event-driven responses, financial tracking, customer data, and order management.

### Q: Should we pre-build integrations for Shopify, Gmail, etc.?
**A: NO. Agents build connectors dynamically.**
> "THE CORE IDEA AND MOAT OF THIS PROJECT IS ITS AUTONOMY, SO IT SHOULD BE ABLE TO BUILD THESE EXTERNAL SERVICE CONNECTORS ON THE FLY"
> "THE CAO AND SUPERIOR AGENT SHOULD DETERMINE WHICH CONNECTORS/TOOLS/SKILLS THE AGENT SHOULD BE ABLE TO USE"

Key decisions:
- CAO hires a DevOps/Integration team to build connectors
- Connectors stored in `org/connectors/` with registry
- Agent researches SOTA approach (MCP > CLI > API > browser), handles auth, builds, creates skill

### Q: Should we pre-build webhook systems?
**A: NO. Agents build them dynamically. All approaches available.**
> "D) All of the above — agent picks the best approach for each case"

n8n, Express.js, standalone scripts, or polling — agent determines best fit.

### Q: Should we pre-build finance, customer, order systems?
**A: NO. Agents create them when the business needs them.**
> "This is something the agents should be able to create on demand"

CEO/CFO designs the system, CAO hires the team if needed.

### Q: How should we handle real-money spending?
**A: Org wallet with configurable limits.**
> "The org should have its own wallet... approval or spending limits should be customizable in both onboarding and later"

- CEO can approve up to configured limit
- Board approval above threshold
- Limits in org/config.md, adjustable

### Q: Should we pre-build templates for internal systems (finance, CRM)?
**A: No templates. Capability + awareness only.**
> "I'm afraid B would prime the LLM too much and it will be too rigid... A is a good start. But we need to make it aware of the possibility and WHY"
> "THEY NEED TO UNDERSTAND THAT THEY ARE 100% AUTONOMOUS AGENTS THAT CAN DO EVERYTHING THEY WANT WITHOUT THE NEED FOR A HUMAN"

The WHY is critical. Agents need to understand their POWER, not just have tools.

### Q: Should the CAO build connectors itself?
**A: No, hire a team.**
> "Yes it should hire a team"

CAO hires DevOps/Integration engineers who specialise in building connectors.

### Q: Time/date awareness?
**A: CRITICAL. Agents must ALWAYS use current date.**
> "WE NEED TO MAKE SURE ALL THE AGENTS HAVE THEIR TIME AND DATE AND THAT THEY ACTUALLY USE THAT TIME/DATE AWARENESS WHEN DOING ONLINE SEARCH"

Example: "DALL-E is an old image model... now its nano banana 2"

### Q: Can the org hire external humans?
**A: Yes, for tasks impossible for AI.**
> "The system should be able to hire other companies/freelancers to perform tasks that is impossible for the system to do itself"

Use browser for freelancer platforms, email for communication, board approval for spending.

### Derived Requirements
1. Agents are FULLY AUTONOMOUS — can build anything within alignment boundaries
2. Nothing is pre-built — connectors, systems, webhooks all created on demand
3. The WHY matters more than the HOW — agents need to understand their power
4. CAO hires specialised teams, doesn't do technical work itself
5. Org wallet with configurable spending limits
6. Temporal awareness mandatory — always use current date in research
7. External hiring possible for impossible tasks
8. SOUL.md must instill initiative, not passivity — "do not create passive agents"
