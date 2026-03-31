# Autonomy & Dynamic Capabilities — The Core Philosophy

**Date:** 2026-03-31
**Purpose:** This document captures the fundamental philosophy of OrgAgent: agents are FULLY AUTONOMOUS and can build ANYTHING they need. Nothing is pre-built — agents research, design, build, and deploy connectors, internal systems, event listeners, and workflows on the fly.

---

## 1. The Core Philosophy

**OrgAgent's moat is not pre-built integrations. It's AUTONOMY.**

The agents in this system are not passive executors following pre-made scripts. They are autonomous entities that:
- RESEARCH how to solve problems (WebSearch, WebFetch with temporal awareness)
- BUILD solutions (write code, install packages, configure services, use browser)
- DEPLOY systems (set up connectors, create event listeners, design data structures)
- MAINTAIN what they build (monitor, update, troubleshoot)
- TEACH other agents (create skills, document systems, transfer knowledge)

**The only boundaries are:**
1. The board's alignment (mission, values, ethics)
2. The IDENTITY.md permissions (tools, data access — expandable via CAO)

Everything else — what to build, how to build it, which tools to use — is determined by the agents themselves based on business needs.

---

## 2. What Changed From Previous Architecture

| Before | After |
|--------|-------|
| Pre-build Shopify connector | Agent researches and builds any connector on demand |
| Pre-build finance system | Agents create `org/finance/` when the business needs it |
| Pre-build customer DB | Agents create `org/customers/` when the business needs it |
| Pre-build webhook server | Agents build event listeners when real-time response is needed |
| Fixed tool set per agent | Dynamic — agents request tools, CAO grants based on need |
| Limited to known APIs | Agent researches current SOTA approach (temporal awareness) |
| Human does operational work | Human only governs — agents do ALL operational work |

---

## 3. Dynamic External Service Connectors

### The Problem
A business needs to connect to dozens of external services (ecommerce platform, email, payment, ads, social media, CRM, shipping, analytics...). Pre-building each one is rigid and doesn't scale.

### The Solution
The CAO hires a DevOps/Integration team. When any agent needs an external service, this team:

1. **RESEARCHES** the service using WebSearch (with current date for SOTA):
   - API documentation
   - Existing MCP servers (search: "{service} MCP server npm {year}")
   - CLI tools (search: "{service} CLI npm {year}")
   - SDKs/libraries
   - Authentication methods

2. **DETERMINES** the best integration approach (priority):
   a. Existing MCP server → `claude mcp add {name} npx @{package}`
   b. CLI tool → `npm install -g {tool}`, wrap as skill
   c. REST API → write Node.js/Python wrapper script or n8n workflow
   d. Browser automation → Playwright MCP for services without APIs
   e. Combination → API for data + browser for auth setup

3. **HANDLES AUTH** (often requires browser):
   - Navigate to developer portal via Playwright
   - Create application / API key
   - Complete OAuth consent flow if needed
   - Store credentials in `org/connectors/{service}/credentials.md`

4. **BUILDS** the connector:
   - Code in `org/connectors/{service}/`
   - Tests it
   - Creates a SKILL wrapping it (`/create-skill`)
   - Documents in registry

5. **DEPLOYS** and assigns:
   - CAO updates relevant agents' IDENTITY.md with new tools
   - Skill registered in `org/skills/` library
   - Agents trained (INSTRUCTIONS.md updated with skill reference)

### Connector Directory Structure
```
org/connectors/
├── registry.md                    # Index of all built connectors
├── shopify/
│   ├── connector.js               # Integration code (or n8n workflow reference)
│   ├── credentials.md             # Auth credentials (access-controlled)
│   ├── README.md                  # Documentation
│   └── test.js                    # Test script
├── gmail/
│   └── ...
├── stripe/
│   └── ...
└── facebook-ads/
    └── ...
```

### Key Principles
- **Never hardcode credentials** — read from credentials.md
- **Always test before deploying** — run test.js
- **Create a skill for every connector** — so other agents can use it as a workflow
- **Use temporal awareness** — always search for the CURRENT approach, not outdated libraries
- **Prefer MCP > CLI > API > Browser** — use the most structured/efficient approach available

---

## 4. Dynamic Webhook & Event Systems

### The Problem
Heartbeat cycles run every 30min–2h. Some events need sub-minute response (new orders, payment notifications, support emails).

### The Solution
Agents build event listeners dynamically when real-time response is needed.

### Approaches (Agent Picks Best)

**A) n8n Workflows (Recommended if n8n is available)**
- n8n receives the webhook from the external service
- n8n workflow writes an event file to the agent's inbox
- n8n can also trigger `claude --agent <name>` directly for urgent events
- Pro: Visual editor, robust, designed for this
- Con: Requires n8n instance running

**B) Express.js Extension**
- Extend the GUI server (gui/server.js) with new webhook endpoints
- Handler writes event file to agent inbox
- Pro: Single process, simple
- Con: Limited scalability

**C) Standalone Webhook Server**
- Agent writes a dedicated Node.js/Python webhook receiver
- Runs as a background process
- Pro: Maximum flexibility
- Con: Need process management

**D) Polling Script**
- A scheduled script that checks for changes (new emails, new orders)
- Writes findings to agent inbox
- Pro: Works when service doesn't support webhooks
- Con: Not real-time

### Event File Format
When an event arrives, the listener writes to `org/agents/{agent}/inbox/`:
```markdown
---
type: external-event
source: shopify
event: order-created
timestamp: 2026-04-01T10:05:00
urgency: high
read: false
---

New order #1042 from john@example.com
Total: 349.00 DKK
Items: 2x "Wireless Headphones"

Raw webhook data: org/connectors/shopify/events/order-1042.json
```

### Integration with Ralph Wiggum Loop
If `/run-org` is active, the Stop hook detects the new unread notification and triggers another heartbeat cycle → the agent processes the event. For truly urgent events, the listener can invoke `claude --agent <name> -p "Urgent event: {summary}"` directly.

---

## 5. Dynamic Internal Business Systems

### The Philosophy
Agents CREATE internal systems when the business needs them. These are NOT pre-built. The CEO/CFO/managers identify needs and build what's required.

### How It Works
1. **CEO identifies need:** "We need to track our finances"
2. **CEO delegates to CFO/Finance Manager** (or CAO hires one if it doesn't exist)
3. **Finance Manager designs the system:**
   - Uses master-gpt-prompter to design well-structured schemas
   - Creates `org/finance/` with ledger, P&L template, expense tracking
   - Creates a skill (`/create-skill`) for common finance workflows
   - Documents the system in a README
4. **CAO grants access** — updates relevant agents' IDENTITY.md
5. **System is operational** — agents use it in their daily work

### Examples of Systems Agents Might Build
- `org/finance/` — Revenue, expenses, P&L, tax tracking
- `org/customers/` — Customer profiles, order history, segments
- `org/orders/` — Order pipeline (pending → processing → shipped → delivered)
- `org/inventory/` — Stock levels, reorder thresholds, supplier info
- `org/content/` — Content calendar, editorial pipeline
- `org/research/` — Market research, competitor analysis
- `org/vendors/` — External vendor/supplier management
- `org/contracts/` — Freelancer and service contracts
- `org/analytics/` — KPIs, dashboards, performance metrics

### Key Principle
**Don't wait. Don't ask for pre-built systems. When you need it, build it.** Use master-gpt-prompter to design the structure well. Document it. Create skills for it. This is autonomy.

---

## 6. Financial Management & Org Wallet

### Dual Budget System

**API Cost Budget (Existing)**
- Tracks what it costs to RUN agents (LLM API costs)
- `org/budgets/overview.md` + `org/budgets/spending-log.md`
- Per-agent allocation, hook-enforced

**Business Finance (Built on Demand)**
- Tracks REAL business money (revenue, expenses, subscriptions, ad spend)
- Created by Finance Manager when the business starts operating
- `org/finance/` directory structure

### Org Wallet
The organisation may have access to real money for business operations. Spending limits are configurable:
- Set during onboarding in `org/config.md`:
  ```yaml
  spending_limits:
    ceo_approval_limit: 500          # CEO can approve up to this amount
    manager_approval_limit: 100      # Managers can approve up to this
    board_required_above: 500        # Board approval needed above this
    currency: DKK
  ```
- Adjustable by the board at any time
- ALL financial transactions logged in the finance ledger
- Board approval required for amounts above the configured threshold

---

## 7. Hiring External Help

### When to Outsource
- Physical tasks impossible for AI (shipping, photography, warehouse)
- Tasks requiring legal human signatures
- Phone calls or in-person meetings
- CAPTCHAs or human-verification walls the system can't bypass
- Highly specialised creative work (when AI output isn't sufficient)

### How It Works
1. Agent identifies an impossible task → escalates to supervisor
2. Supervisor (or CEO) approves outsourcing → creates an "external hire" request
3. Board approves the budget (if above spending limit)
4. Designated agent uses browser to:
   - Post job on freelancer platform (Upwork, Fiverr, etc.)
   - Evaluate proposals
   - Hire and manage the contractor
5. Track the engagement in `org/vendors/` or `org/contracts/`
6. Communicate via email connector
7. Review deliverables, process payment
8. Document outcomes for future reference

---

## 8. Temporal Awareness — ALWAYS Use Current Date

### Why This Is Critical
The LLMs powering agents have a knowledge cutoff. Technologies change rapidly:
- Libraries get deprecated
- APIs change versions
- New SOTA tools emerge monthly
- Best practices evolve

### Rules for All Agents
1. **ALWAYS include year/month in web searches** — "best X March 2026"
2. **ALWAYS check if a tool/library is current** before recommending
3. **ALWAYS prefer sources from the last 6 months**
4. **NEVER assume your training data is current** — verify via web search
5. **The heartbeat prompt includes today's date** — USE it in every search

### Implementation
- The heartbeat script passes: `Today is $(date +%Y-%m-%d)`
- The system-reference.md Section 0 explicitly teaches temporal awareness
- Every agent's INSTRUCTIONS.md should reinforce this

---

## 9. The CAO's Role in Dynamic Capabilities

The CAO is the key enabler. It must understand it can:

1. **Hire specialised teams:**
   - DevOps/Integration Engineer — builds connectors and event systems
   - Finance Manager/CFO — creates financial tracking
   - CRM Manager — builds customer database
   - Infrastructure Agent — manages persistent processes, servers
   - Any other role the business needs

2. **Each hired agent receives:**
   - Full understanding of their autonomy (system-reference.md Section 0)
   - The tools they need (Bash, browser, WebSearch, etc.)
   - Permission to create directories and files in `org/`
   - Access to the skill library and connector registry
   - The master-gpt-prompter principles

3. **The CAO creates agents that CREATE, not just agents that EXECUTE.**
   - A passive agent waits to be told each step → BAD
   - An autonomous agent identifies problems and builds solutions → GOOD
   - The SOUL.md should instill initiative, problem-solving, creativity

---

## 10. Architecture Decisions

### Decision 45: Agents Build Their Own Integrations
**Decision:** External service connectors are NOT pre-built. Agents research, build, and deploy integrations dynamically based on business needs.
**Reasoning:** This is the project's moat. Pre-built integrations are rigid and don't scale. Dynamic building allows the org to connect to ANY service.

### Decision 46: Dynamic Internal Systems
**Decision:** Internal business systems (finance, CRM, orders, etc.) are NOT pre-built. Agents create them on demand when the business needs them.
**Reasoning:** Different businesses need different systems. Pre-building assumes requirements. Dynamic creation adapts to actual needs.

### Decision 47: Agent Picks Best Event Approach
**Decision:** For webhook/event systems, the agent determines the best approach (n8n, Express, standalone, polling) based on the specific situation.
**Reasoning:** No single approach is best for all cases. Agent autonomy means choosing the right tool.

### Decision 48: Org Wallet with Configurable Limits
**Decision:** The org has a wallet for real business spending. Spending limits are configurable during onboarding. Board approval required above threshold.
**Reasoning:** Autonomous operation requires the ability to spend money. But financial governance requires approval for significant amounts.

### Decision 49: Temporal Awareness is Mandatory
**Decision:** All agents MUST use the current date in web searches and MUST verify tools/libraries are current before recommending or using them.
**Reasoning:** LLM training data becomes stale. The web is the source of truth for current information.

### Decision 50: Agents Are Autonomous, Not Passive
**Decision:** Every agent created by the CAO must understand they are fully autonomous and capable. Their SOUL.md must instill initiative, not passivity.
**Reasoning:** Passive agents that wait for instructions are bottlenecks. Autonomous agents that identify and solve problems are force multipliers.

### Decision 51: External Hiring When AI Can't
**Decision:** The org can hire freelancers and external companies for tasks impossible for AI. Requires board approval for spending above configured limits.
**Reasoning:** Some tasks require humans. The org should handle this like a real company — outsource what you can't do internally.
