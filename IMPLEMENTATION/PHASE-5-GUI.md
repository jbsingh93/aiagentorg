# Phase 5: GUI Dashboard

**Objective:** Build the Express.js dashboard server with dark-theme SPA frontend.
**Files to create:** 12
**Depends on:** Phases 1-4 (needs org structure, file formats, hook scripts)
**Estimated effort:** 8-12 hours

---

## Architecture Reference

- **Spec:** `TO-DO/01-MASTER-PLAN.md` → Section 8 (GUI Dashboard)
- **File formats (API parsing):** `TO-DO/10-FILE-FORMAT-SPECIFICATIONS.md` (all 26 formats)
- **Chat view:** `TO-DO/15-CHAT-LAYER-CHAIN-OF-COMMAND.md` → Section 9
- **Activity view:** `TO-DO/16-OBSERVABILITY-AND-MEMORY-ARCHITECTURE.md` → GUI Integration
- **Design decisions:** `TO-DO/09-ARCHITECTURE-DECISIONS.md` → Decision 20

**Tech stack:**
- Express.js 5 server on port 3000 (configurable via PORT env)
- `gray-matter` for YAML frontmatter parsing
- `marked` for markdown → HTML rendering
- Vanilla HTML/CSS/JS (no React)
- D3.js for org chart (CDN)
- Chart.js for budget charts (CDN)
- CSS grid for kanban task board
- Dark theme (#0d1117 background)
- Polling every 5 seconds for updates
- Bind to 127.0.0.1 (localhost only, no auth)

**Design tokens:**
```css
--bg-primary: #0d1117;
--bg-card: #161b22;
--border: #30363d;
--text-primary: #e6edf3;
--text-secondary: #8b949e;
--accent-blue: #58a6ff;
--accent-green: #3fb950;
--accent-red: #f85149;
--accent-yellow: #d29922;
```

---

## Task 5.1: `gui/server.js` — Express Server

- [ ] **Create file:** `gui/server.js`
- **Key content:**
  - Express.js setup, port from env or 3000, bind to 127.0.0.1
  - Static file serving from `gui/public/`
  - Import API route modules from `gui/api/`
  - Resolve org directory: `path.resolve(__dirname, '..', 'org')`
  - Pass org path to each API route
  - CORS for localhost
  - Error handling middleware
- **Dependencies:** package.json (express installed)
- **Verify:** `node gui/server.js` starts without error, serves index.html

---

## Task 5.2: `gui/public/index.html` — Dashboard SPA

- [ ] **Create file:** `gui/public/index.html`
- **Key content:**
  - Dark theme HTML shell
  - Tab navigation: Overview | Org Chart | Agents | Tasks | Threads | Budget | Board | Activity
  - CDN includes: D3.js, Chart.js
  - Script include: app.js
  - Style include: style.css
  - Tab content divs (show/hide based on active tab)
  - Board send-message form in Threads tab
  - Approve/reject buttons in Board tab
- **Dependencies:** None
- **Verify:** Opens in browser, shows dark theme with tabs

---

## Task 5.3: `gui/public/style.css` — Dark Theme Stylesheet

- [ ] **Create file:** `gui/public/style.css`
- **Key content:**
  - CSS variables for design tokens (colors above)
  - Dark background, card-based layout
  - Tab navigation styling
  - CSS grid for kanban task board (3 columns: backlog/active/done)
  - Table styling for audit log, budget tables
  - Agent status indicators (colored dots: green=active, yellow=pending, red=terminated)
  - Message type badges (colored labels: blue=directive, green=report, red=escalation, yellow=request)
  - Thread indentation for message chains
  - Responsive layout
  - System font stack
- **Dependencies:** None
- **Verify:** Visual inspection in browser

---

## Task 5.4: `gui/public/app.js` — Dashboard JavaScript

- [ ] **Create file:** `gui/public/app.js`
- **Key content:**
  - Tab switching logic (show/hide divs)
  - API fetch functions for each endpoint
  - 5-second polling interval for auto-refresh
  - D3.js org chart rendering (tree layout from orgchart API data)
  - Chart.js budget pie/bar charts
  - Kanban board rendering (tasks grouped by status)
  - Thread view rendering (grouped by thread_id, message blocks)
  - Activity stream rendering (agent filter, chronological)
  - Approval buttons: POST to approve/reject endpoints
  - Board message form: POST to send message
  - Utility: format dates, parse currency from config
- **Dependencies:** index.html, style.css
- **Verify:** All 8 views render with sample data

---

## Tasks 5.5-5.12: API Routes

Each route reads markdown files from `org/` and returns JSON.

### Task 5.5: `gui/api/orgchart.js` — GET /api/orgchart

- [ ] **Create file**
- **Parses:** `org/orgchart.md` → JSON tree
- **Parse logic:** See `TO-DO/10-FILE-FORMAT-SPECIFICATIONS.md` → Format 3 (parsing pseudocode)
- **Returns:** `{ tree: { name, status, agentId, title, children: [...] } }`

### Task 5.6: `gui/api/agents.js` — GET /api/agents

- [ ] **Create file**
- **Reads:** All `org/agents/*/IDENTITY.md` files
- **Parses:** YAML frontmatter with gray-matter
- **Returns:** `[{ name, title, status, model, department, emoji, ... }]`

### Task 5.7: `gui/api/agent.js` — GET /api/agent/:name

- [ ] **Create file**
- **Reads:** Agent's SOUL.md, IDENTITY.md, INSTRUCTIONS.md, current-state.md, tasks/, reports/
- **Returns:** `{ soul, identity, instructions, currentState, tasks: [...], reports: [...] }`

### Task 5.8: `gui/api/tasks.js` — GET /api/tasks

- [ ] **Create file**
- **Reads:** All `org/agents/*/tasks/{backlog,active,done}/*.md`
- **Parses:** Frontmatter for id, title, priority, status, assigned_to, deadline
- **Returns:** `[{ id, title, priority, status, agent, deadline, ... }]`
- **Filters:** `?agent=name`, `?status=active`, `?initiative=slug`

### Task 5.9: `gui/api/messages.js` — GET /api/messages (Threads)

- [ ] **Create file**
- **Reads:** All `org/threads/**/*.md` files
- **Parses:** Thread frontmatter + message blocks (regex for `### [MSG-...]`)
- **Returns:** `[{ threadId, topic, department, participants, messages: [...] }]`
- **Filters:** `?department=marketing`, `?agent=ceo`, `?thread=id`

### Task 5.10: `gui/api/budget.js` — GET /api/budget

- [ ] **Create file**
- **Reads:** `org/config.md` (currency), `org/budgets/overview.md`, `org/budgets/spending-log.md`
- **Parses:** Frontmatter for totals, markdown table for per-agent rows
- **Returns:** `{ currency, total, allocated, spent, remaining, agents: [...], recentTransactions: [...] }`

### Task 5.11: `gui/api/audit.js` — GET /api/audit

- [ ] **Create file**
- **Reads:** `org/board/audit-log.md`
- **Parses:** Markdown table rows
- **Returns:** `[{ timestamp, agent, action, target, details }]`
- **Pagination:** `?page=1&limit=50`

### Task 5.12: `gui/api/approvals.js` — GET/POST /api/approvals

- [ ] **Create file**
- **GET:** Lists `org/board/approvals/*.md` where status=pending
- **POST /api/approvals/:id/approve:** Updates frontmatter, moves to decisions/
- **POST /api/approvals/:id/reject:** Updates frontmatter with reason, moves to decisions/
- **Returns GET:** `[{ id, type, proposed_by, date, status, ... }]`

---

## Phase 5 Verification

```bash
# All GUI files exist
for f in gui/server.js gui/public/index.html gui/public/style.css gui/public/app.js; do
  [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
done
for f in gui/api/orgchart.js gui/api/agents.js gui/api/agent.js gui/api/tasks.js gui/api/messages.js gui/api/budget.js gui/api/audit.js gui/api/approvals.js; do
  [ -f "$f" ] && echo "OK: $f" || echo "MISSING: $f"
done

# Server starts
node gui/server.js &
sleep 2
curl -s http://localhost:3000 | head -5
kill %1

# API returns JSON (requires org/ from /onboard)
# curl -s http://localhost:3000/api/orgchart | jq .
```
