# Browser Automation — Complete Specification

**Date:** 2026-03-31
**Purpose:** Enable agents to interact with websites and web applications when no API/MCP/CLI exists. Agents can create accounts, fill forms, extract data, and automate browser workflows.

---

## 1. Why Browser Automation

Many real-world tasks have no API:
- Creating a Google Cloud account to get API credentials
- Logging into a CRM to export customer data
- Filling out a web form to register a service
- Scraping a competitor's public pricing page
- Managing social media through web UI

Agents need browser access as a **fallback tool** when API/MCP/CLI isn't available.

---

## 2. Three-Tier Browser Strategy

Based on research ([source analysis](https://github.com/microsoft/playwright-mcp), [Claude Chrome docs](https://code.claude.com/docs/en/chrome), [Playwright CLI](https://github.com/microsoft/playwright-cli)):

| Tier | Tool | Use Case | Autonomous? | Token Efficiency |
|------|------|----------|-------------|-----------------|
| **Primary** | Playwright MCP | Autonomous agent browser tasks | YES (headless) | Medium (~50k tokens) |
| **Secondary** | Playwright CLI | Token-efficient batch workflows | YES (headless) | Best (~27k tokens, 4x better) |
| **Interactive** | Claude in Chrome | Human-guided debugging/setup | NO (needs human) | Best (~7.7% context) |

### Why Playwright MCP as Primary (not CLI)

For OrgAgent, **Playwright MCP is the better primary choice** because:
1. **MCP is native to Claude Code** — agents call MCP tools directly (no Bash wrapping needed)
2. **Structured tool interface** — `mcp__playwright__click`, `mcp__playwright__fill`, etc. are first-class tools in Claude Code
3. **Permission integration** — MCP tools can be controlled via settings.json permissions just like any other tool
4. **Standard protocol** — works across Claude Code, Claude Desktop, VS Code
5. **Persistent profiles** — can maintain login state across heartbeat cycles

Playwright CLI is the **secondary choice** for:
- Token-sensitive operations (CLI is ~4x more efficient)
- Batch/parallel browser tasks (multi-session support)
- When agents need to control what enters the context window

Claude in Chrome is for **interactive/human-guided** use only — not for autonomous agents.

---

## 3. Installation & Configuration

### 3.1 Playwright MCP Server

Add to the project's MCP configuration. In `.claude/mcp.json` (or via CLI):

```bash
claude mcp add --scope project playwright -- npx @playwright/mcp@latest
```

Or create `.claude/mcp.json`:
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "env": {}
    }
  }
}
```

**Headless mode (default for agents):**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--headless"]
    }
  }
}
```

**With persistent profile (maintains login state):**
```json
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--headless", "--user-data-dir", "./org/.browser-profiles/default"]
    }
  }
}
```

### 3.2 Playwright CLI (Secondary)

Install globally or as project dependency:
```bash
npm install -g @playwright/cli@latest
```

Or add to package.json:
```json
{
  "devDependencies": {
    "@playwright/cli": "latest"
  }
}
```

Usage via Bash tool:
```bash
playwright-cli open https://example.com --headless
playwright-cli snapshot
playwright-cli click "Sign Up"
playwright-cli fill "#email" "agent@org.com"
```

### 3.3 Claude in Chrome (Interactive Only)

No configuration needed — it's built into Claude Code:
```bash
claude --chrome
```
Or within a session: `/chrome`

**Not for autonomous agents.** Only for human-guided interactive browser use.

---

## 4. Tool Permission Integration

Browser tools follow the same permission system as all other tools.

### 4.1 Tool Categories (Updated)

| Category | Tools | Typical Access |
|----------|-------|---------------|
| **Core (all agents)** | Read, Write, Edit, Glob, Grep | Every agent |
| **Execution** | Bash | Agents that run scripts |
| **Web Research** | WebFetch, WebSearch | Research agents |
| **Browser (MCP)** | mcp__playwright__* | Agents with browser permission |
| **Browser (CLI)** | Bash(playwright-cli *) | Agents with browser + Bash |
| **Communication** | Agent (spawn subagents) | Only CEO in interactive mode |

### 4.2 Who Gets Browser Access

Browser access is a **privileged tool** — not granted by default. The CAO and the agent's supervisor determine if an agent needs browser access during hiring or reconfiguration.

**Decision framework for CAO:**
1. Does the agent's task REQUIRE browser interaction?
2. Is there an API/MCP/CLI alternative? If yes, use that instead.
3. What is the minimum browser access needed? (read-only snapshot vs full interaction)
4. What sites will the agent access? (document in IDENTITY.md)

**IDENTITY.md example with browser tools:**
```yaml
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - mcp__playwright__goto
  - mcp__playwright__click
  - mcp__playwright__fill
  - mcp__playwright__snapshot
  - mcp__playwright__screenshot
```

### 4.3 Settings.json Permission

Add browser tools to the allow list in `.claude/settings.json`:
```json
{
  "permissions": {
    "allow": [
      "mcp__playwright__goto",
      "mcp__playwright__click",
      "mcp__playwright__fill",
      "mcp__playwright__snapshot",
      "mcp__playwright__screenshot"
    ]
  }
}
```

Or deny by default and allow per-agent via `--allowedTools` in heartbeat.sh.

---

## 5. Browser Skill (`/browser`)

A skill that wraps browser automation for agents. Provides a structured interface for common browser tasks.

**File:** `.claude/skills/browser/SKILL.md`

```yaml
---
name: browser
description: "Browser automation for tasks that have no API/MCP/CLI. Navigate websites, fill forms, extract data, create accounts. Uses Playwright MCP (headless) for autonomous operation."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Bash, mcp__playwright__goto, mcp__playwright__click, mcp__playwright__fill, mcp__playwright__type, mcp__playwright__snapshot, mcp__playwright__screenshot, mcp__playwright__select, mcp__playwright__check, mcp__playwright__evaluate
argument-hint: "[url] [task-description] — or omit for interactive"
---

# Browser Automation

Use this skill when you need to interact with a website and no API, MCP server, or CLI tool exists for the task.

## When to Use
- Creating accounts on web services (Google Cloud, AWS, social media)
- Filling forms that have no API endpoint
- Extracting data from web pages that don't have an API
- Automating web UI workflows (CRM data entry, dashboard configuration)
- Any task where the only interface is a web browser

## When NOT to Use
- If an API exists → use WebFetch or a dedicated MCP server
- If a CLI tool exists → use Bash
- If data can be read from a public URL → use WebFetch
- Browser is a FALLBACK, not the primary approach

## How to Use

### Step 1: Navigate
```
mcp__playwright__goto(url: "https://example.com")
```

### Step 2: Understand the page
```
mcp__playwright__snapshot()
```
This returns the accessibility tree — a structured representation of all interactive elements on the page.

### Step 3: Interact
```
mcp__playwright__click(selector: "text=Sign Up")
mcp__playwright__fill(selector: "#email", value: "user@example.com")
mcp__playwright__click(selector: "button[type=submit]")
```

### Step 4: Verify
```
mcp__playwright__snapshot()
mcp__playwright__screenshot()
```

### Step 5: Extract data
Use snapshot to read page content, or evaluate JavaScript:
```
mcp__playwright__evaluate(expression: "document.querySelector('.result').textContent")
```

## Important Rules
- ALWAYS check your IDENTITY.md for browser tool permissions before using
- ALWAYS log browser actions in your activity/current-state.md
- ALWAYS report browser workflow results in the relevant thread
- NEVER enter credentials that aren't provided to you or generated for this purpose
- NEVER interact with sites outside the scope of your assigned task
- If you encounter a CAPTCHA: STOP, log the issue, and escalate to your supervisor
```

---

## 6. Browser Profiles (Authentication Persistence)

For agents that need to maintain login state across heartbeat cycles:

**Directory:** `org/.browser-profiles/`

```
org/.browser-profiles/
├── default/              # Shared profile (if needed)
├── ceo/                  # CEO's browser profile
├── marketing-manager/    # Marketing manager's profile
└── seo-agent/           # SEO agent's profile
```

**Gitignored:** Add to `.gitignore`:
```
org/.browser-profiles/
```

**Playwright MCP with per-agent profile:**
The heartbeat script can pass agent-specific profile:
```bash
# In heartbeat.sh run_agent() function, if agent has browser tools:
# Start Playwright MCP with agent-specific profile
BROWSER_PROFILE="$ORG_DIR/.browser-profiles/$agent_name"
mkdir -p "$BROWSER_PROFILE"
```

---

## 7. Security Considerations

| Risk | Mitigation |
|------|-----------|
| Agent visits malicious sites | INSTRUCTIONS.md limits which domains agent can access |
| Agent leaks credentials | Credentials stored in org/agents/{name}/ (access-controlled) |
| Agent creates unauthorized accounts | Account creation requires supervisor approval |
| Browser tool abuse | Tool permissions in IDENTITY.md + data-access-check hook |
| CAPTCHA blocking | Agent escalates to supervisor, does not attempt to solve |
| Cost (browser is resource-heavy) | Budget caps still apply; browser tasks are bounded |

---

## 8. Integration with Existing Architecture

### Onboarding
During `/onboard`, ask: "Will your agents need browser access for web automation? (e.g., creating service accounts, managing web platforms)"

If yes: configure Playwright MCP in `.claude/mcp.json` during bootstrap.

### CAO Hiring
When the CAO creates a new agent that needs browser access:
1. Add `mcp__playwright__*` tools to IDENTITY.md
2. Document which sites the agent will access
3. Create agent-specific browser profile directory
4. Note browser access in the hire approval proposal

### Heartbeat
Browser tools work normally during heartbeat — they're just MCP tools that the agent invokes like any other.

### Observability
Browser actions are logged by the activity-logger hook (PostToolUse fires for MCP tools too).

---

## 9. Architecture Decision

### Decision 41: Browser Automation via Playwright MCP + CLI + Chrome

**Decision:** Three-tier browser strategy:
- Primary: Playwright MCP (autonomous, headless, MCP-native)
- Secondary: Playwright CLI via Bash (token-efficient batch workflows)
- Interactive: Claude in Chrome (human-guided only)

**Browser access is a privileged tool** — not granted by default. CAO + supervisor determine which agents get it. Follows the same permission system as all other tools.

**See:** `19-BROWSER-AUTOMATION.md` for complete specification.
