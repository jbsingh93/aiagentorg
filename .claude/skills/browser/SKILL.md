---
name: browser
description: "Browser automation for tasks that have no API/MCP/CLI. Navigate websites, fill forms, extract data, create accounts. Uses Playwright MCP (headless) for autonomous operation. Playwright CLI via Bash for token-efficient workflows. This is a FALLBACK tool — always prefer APIs when available."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Bash, mcp__playwright__goto, mcp__playwright__click, mcp__playwright__fill, mcp__playwright__type, mcp__playwright__snapshot, mcp__playwright__screenshot, mcp__playwright__select, mcp__playwright__check, mcp__playwright__evaluate, mcp__playwright__go_back, mcp__playwright__go_forward
argument-hint: "[url] [task-description] — or omit for interactive"
---

# Browser Automation

Use this skill when you need to interact with a website and **no API, MCP server, or CLI tool exists** for the task.

## When to Use
- Creating accounts on web services (Google Cloud, AWS, social media platforms)
- Filling forms that have no API endpoint
- Extracting data from web pages without an API
- Automating web UI workflows (CRM data entry, dashboard configuration)
- Managing services through their web interface when no CLI/API alternative exists

## When NOT to Use
- If an API exists → use WebFetch or a dedicated MCP server instead
- If a CLI tool exists → use Bash instead
- If data can be read from a public URL → use WebFetch instead
- **Browser is a FALLBACK, not the primary approach**

## Prerequisites
- Browser tools (Playwright MCP) must be listed in your IDENTITY.md `tools`
- If you don't have browser tools: create a tool request to the CAO
- Playwright MCP server must be configured (check with your supervisor)

## Method 1: Playwright MCP (Primary — Structured Tools)

### Step 1: Navigate to the target
```
Use tool: mcp__playwright__goto
Parameters: url: "https://example.com"
```

### Step 2: Understand the page structure
```
Use tool: mcp__playwright__snapshot
```
This returns the **accessibility tree** — a structured representation of all interactive elements. Each element has a reference ID (e.g., `e8`, `e21`) you can use for interaction.

### Step 3: Interact with elements
```
Click:    mcp__playwright__click     (selector: "text=Sign Up" or ref: "e8")
Fill:     mcp__playwright__fill      (selector: "#email", value: "user@example.com")
Type:     mcp__playwright__type      (selector: "#search", text: "query", submit: true)
Select:   mcp__playwright__select    (selector: "#country", value: "DK")
Check:    mcp__playwright__check     (selector: "#agree-terms")
```

### Step 4: Verify results
```
Snapshot: mcp__playwright__snapshot    (re-read the page state)
Screenshot: mcp__playwright__screenshot (visual capture if needed)
```

### Step 5: Extract data
```
Evaluate: mcp__playwright__evaluate   (expression: "document.querySelector('.result').textContent")
```

## Method 2: Playwright CLI (Secondary — Token Efficient)

For batch workflows or when token efficiency matters:

```bash
# Open a page
playwright-cli open https://example.com --headless

# Take a snapshot (saved to disk, not context)
playwright-cli snapshot

# Interact
playwright-cli click "text=Sign Up"
playwright-cli fill "#email" "user@example.com"
playwright-cli click "button[type=submit]"

# Save state for later
playwright-cli state-save ./browser-state.json
```

**Why CLI?** ~4x more token-efficient than MCP. Snapshots save to disk instead of flooding the context window.

## Important Rules

1. **ALWAYS check your IDENTITY.md** for browser tool permissions before using
2. **ALWAYS log browser actions** in your activity/current-state.md (what site, what action, what result)
3. **ALWAYS report browser workflow results** in the relevant thread
4. **NEVER enter credentials** that aren't provided to you or generated for this task
5. **NEVER interact with sites** outside the scope of your assigned task
6. **NEVER attempt to solve CAPTCHAs** — STOP, log the issue, escalate to your supervisor
7. **NEVER store passwords in plain text** — use the org's credential storage (org/agents/{name}/credentials/)
8. **PREFER APIs over browser** — only use browser when there truly is no alternative

## Error Handling

| Error | Action |
|-------|--------|
| CAPTCHA encountered | STOP. Escalate to supervisor. Do not attempt to bypass. |
| Login required | Check if credentials exist in your workspace. If not, escalate. |
| Page not loading | Retry once. If still failing, log error and try alternative URL. |
| Element not found | Take snapshot, verify selector, try alternative selector. |
| Timeout | Wait 10 seconds, retry. If persistent, escalate. |
| Unexpected redirect | Take snapshot, log the redirect, assess if it's safe to continue. |

## Credential Storage

If you obtain credentials through browser automation (e.g., API keys from Google Cloud):

```
org/agents/{your-name}/credentials/
└── google-cloud.md
```

Format:
```markdown
---
service: Google Cloud
created: {DATE}
created_by: {YOUR_NAME}
type: api-key
---

Project ID: {value}
API Key: {value}
```

**This directory MUST be in your access_write list.** Credentials are sensitive — only you and your supervisor should have read access.
