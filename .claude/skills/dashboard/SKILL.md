---
name: dashboard
description: "Start the GUI dashboard web server. Opens a dark-theme dashboard at localhost:3000 with org chart, task board, budget charts, thread view, and approval management."
disable-model-invocation: true
user-invocable: true
allowed-tools: Bash
---

# Start Dashboard

## Pre-flight Check
1. Verify `gui/server.js` exists
2. Verify `org/config.md` exists (org must be onboarded)
3. Verify node_modules/ exists (run `npm install` if missing)

If any check fails, tell the user what's missing.

## Start Server
```bash
node gui/server.js &
```

## Confirm
Tell the user:
"Dashboard running at http://localhost:3000

Views available:
- Overview — org summary with key metrics
- Org Chart — interactive hierarchy visualization
- Agents — click any agent for detail view
- Tasks — kanban board (backlog / active / done)
- Threads — conversation feed with message search
- Budget — spending charts and per-agent breakdown
- Board — pending approvals with approve/reject buttons
- Activity — real-time agent activity streams

The dashboard auto-refreshes every 5 seconds. Press Ctrl+C to stop the server."
