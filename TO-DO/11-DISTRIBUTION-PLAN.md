# Distribution Plan — Packaging & Sharing OrgAgent

**Date:** 2026-03-31
**Purpose:** How to package, distribute, and make OrgAgent extremely simple to install and use.

---

## Distribution Strategy

**Primary:** npm package (`npx create-orgagent`)
**Secondary:** GitHub template repository
**Target audience:** Anyone with Claude Code and Node.js installed

---

## Option 1: npm Package (Recommended)

### User Experience

```bash
# Step 1: Create a new org project (one command)
npx create-orgagent my-company

# Step 2: Enter the project and open Claude Code
cd my-company
claude

# Step 3: Run onboarding (inside Claude Code)
/onboard
```

That's it. Three steps. The onboarding conversation handles everything else.

### What `npx create-orgagent` Does

1. **Creates project directory** (`my-company/`)
2. **Copies template files** — all `.claude/` config, scripts, GUI
3. **Runs `npm install`** — installs Express + dependencies for GUI
4. **Initializes git** — `git init` for version control of org state
5. **Prints welcome message** with next steps

### Package Structure

```
create-orgagent/                      # Published to npm
├── package.json                      # npm package manifest
├── bin/
│   └── index.js                      # CLI entry point
├── template/                         # Files copied to new project
│   ├── .claude/
│   │   ├── CLAUDE.md                 # Org-level instructions
│   │   ├── settings.json             # Hooks, permissions
│   │   ├── agents/
│   │   │   ├── ceo.md                # CEO agent definition
│   │   │   └── cao.md                # CAO agent definition
│   │   ├── skills/
│   │   │   ├── onboard/SKILL.md
│   │   │   ├── heartbeat/SKILL.md
│   │   │   ├── delegate/SKILL.md
│   │   │   ├── escalate/SKILL.md
│   │   │   ├── report/SKILL.md
│   │   │   ├── message/SKILL.md
│   │   │   ├── approve/SKILL.md
│   │   │   ├── budget-check/SKILL.md
│   │   │   ├── hire-agent/SKILL.md
│   │   │   ├── fire-agent/SKILL.md
│   │   │   ├── reconfigure-agent/SKILL.md
│   │   │   ├── review-work/SKILL.md
│   │   │   ├── status/SKILL.md
│   │   │   ├── dashboard/SKILL.md
│   │   │   ├── task/SKILL.md
│   │   │   └── master-gpt-prompter/SKILL.md  # + references/
│   │   └── rules/
│   │       ├── governance.md
│   │       └── structured-autonomy.md
│   ├── scripts/
│   │   ├── heartbeat.sh              # Multi-phase orchestration
│   │   └── hooks/                    # 11 governance & observability hooks
│   │       ├── activity-logger.sh          # Log every action (replaces audit-log.sh)
│   │       ├── remind-state-update.sh      # Periodic reminder for current-state.md
│   │       ├── require-state-and-communication.sh  # Block session end if stale
│   │       ├── data-access-check.sh        # Chain-of-command file access
│   │       ├── message-routing-check.sh    # Chain-of-command message routing
│   │       ├── require-board-approval.sh   # Board-only decisions
│   │       ├── require-cao-or-board.sh     # Agent definition protection
│   │       ├── skill-access-check.sh       # Agent management skill restriction
│   │       ├── budget-check.sh             # Budget enforcement
│   │       ├── log-agent-activation.sh     # Agent session start
│   │       └── log-agent-deactivation.sh   # Agent session end
│   ├── gui/
│   │   ├── server.js
│   │   ├── public/
│   │   │   ├── index.html
│   │   │   ├── style.css
│   │   │   └── app.js
│   │   └── api/
│   │       ├── orgchart.js
│   │       ├── agents.js
│   │       ├── tasks.js
│   │       ├── messages.js
│   │       ├── budget.js
│   │       ├── audit.js
│   │       ├── approvals.js
│   │       └── agent.js
│   ├── package.json                  # Project deps (express, marked, etc.)
│   ├── .gitignore
│   └── README.md
└── README.md                         # Package documentation
```

### `bin/index.js` Implementation

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const projectName = process.argv[2];

if (!projectName) {
  console.log('Usage: npx create-orgagent <project-name>');
  console.log('Example: npx create-orgagent my-company');
  process.exit(1);
}

const targetDir = path.resolve(process.cwd(), projectName);
const templateDir = path.resolve(__dirname, '..', 'template');

// Check if directory exists
if (fs.existsSync(targetDir)) {
  console.error(`Error: Directory "${projectName}" already exists.`);
  process.exit(1);
}

console.log(`\n  Creating OrgAgent project: ${projectName}\n`);

// Copy template
copyDirRecursive(templateDir, targetDir);
console.log('  ✓ Project files created');

// Install dependencies
console.log('  ⏳ Installing dependencies...');
execSync('npm install', { cwd: targetDir, stdio: 'inherit' });
console.log('  ✓ Dependencies installed');

// Initialize git
execSync('git init', { cwd: targetDir, stdio: 'pipe' });
console.log('  ✓ Git repository initialized');

// Print success message
console.log(`
  ✓ OrgAgent project created successfully!

  Next steps:

    cd ${projectName}
    claude

  Then inside Claude Code, type:

    /onboard

  This starts the alignment conversation to set up your AI organisation.

  Optional — start the dashboard:

    /dashboard

  Optional — schedule automatic heartbeats:

    /loop 2h /heartbeat

  Documentation: https://github.com/yourusername/orgagent
`);

// Helper function
function copyDirRecursive(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}
```

### `package.json` (npm package)

```json
{
  "name": "create-orgagent",
  "version": "1.0.0",
  "description": "Create a dynamic AI agent organisation powered by Claude Code",
  "bin": {
    "create-orgagent": "./bin/index.js"
  },
  "keywords": [
    "ai", "agent", "organisation", "claude-code", "claude",
    "multi-agent", "autonomous", "scaffolding"
  ],
  "license": "MIT",
  "repository": {
    "type": "git",
    "url": "https://github.com/yourusername/create-orgagent"
  }
}
```

### `package.json` (project template)

```json
{
  "name": "orgagent",
  "version": "1.0.0",
  "private": true,
  "description": "AI Agent Organisation — powered by Claude Code",
  "scripts": {
    "dashboard": "node gui/server.js",
    "heartbeat": "bash scripts/heartbeat.sh"
  },
  "dependencies": {
    "express": "^5.0.0",
    "marked": "^15.0.0",
    "gray-matter": "^4.0.3"
  }
}
```

### `.gitignore` (project template)

```
node_modules/
.claude/settings.local.json
.claude/agent-memory/
.claude/agent-memory-local/

# OS
.DS_Store
Thumbs.db

# Temp
*.tmp
*.swp
```

---

## Option 2: GitHub Template Repository

For users who prefer not to use npm, or for zero-infrastructure distribution.

### Setup

1. Push the template files to a GitHub repository
2. Go to repository Settings → check "Template repository"
3. Users click "Use this template" → creates their own copy

### User Experience

```bash
# Via GitHub UI:
# 1. Go to github.com/yourusername/orgagent
# 2. Click "Use this template" → "Create a new repository"
# 3. Clone your new repo

git clone https://github.com/myuser/my-company.git
cd my-company
npm install
claude
/onboard
```

### Pros/Cons vs npm

| Aspect | npx | GitHub Template |
|--------|-----|----------------|
| **Setup steps** | 1 command | 3-4 steps |
| **Requires npm account** | Yes (to publish) | No |
| **Auto-updates** | Yes (npx gets latest) | No (manual sync) |
| **Customizable name** | Yes (argument) | Yes (repo name) |
| **GitHub account needed** | No | Yes |
| **Offline use** | No | Yes (after clone) |

---

## Option 3: Combined Approach (Recommended)

Publish BOTH:

1. **npm package** — `npx create-orgagent` for quick setup
2. **GitHub template** — for users who want to fork/customize
3. **GitHub releases** — `.zip`/`.tar.gz` downloads for manual setup

All three point to the same source of truth (the template files).

---

## Update Strategy

When the OrgAgent template is updated:

### For npm users
```bash
# New projects get the latest template automatically
npx create-orgagent new-project

# Existing projects: manual update
# (no auto-update — org state is user-specific)
```

### For template users
- Check the upstream repo for changes
- Cherry-pick relevant updates to `.claude/` files

### What's safe to update
- `.claude/skills/` — skills can be updated without affecting org state
- `.claude/rules/` — rules can be updated
- `gui/` — dashboard can be updated independently
- `scripts/hooks/` — hooks can be updated

### What should NOT be auto-updated
- `.claude/agents/` — may contain user-created agents
- `.claude/settings.json` — may have user customizations
- `org/` — this IS the user's data

---

## Prerequisites

### Required
- **Node.js 20+** — for GUI server and npm
- **Claude Code** — the AI engine (`npm install -g @anthropic-ai/claude-code` or via Claude Desktop)
- **Anthropic API key** — for Claude Code to function (or Claude Max subscription)

### Optional
- **Git** — for version control of org state (recommended)
- **jq** — for hook scripts that parse JSON (install: `npm install -g jq` or OS package manager)

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| **macOS** | Full support | Native bash, all features work |
| **Linux** | Full support | Native bash, all features work |
| **Windows** | Supported via Git Bash | Install Git for Windows; `jq` via winget/choco |
| **WSL** | Full support | Runs as Linux |

---

## Marketing & README

### Tagline
"Spin up an AI-powered organisation in 3 commands."

### README.md Hero Section

```markdown
# OrgAgent

> Dynamic, self-organizing AI agent organisations powered by Claude Code.

Create an AI company where a CEO delegates to managers, managers delegate to
workers, and a Chief Agents Officer dynamically hires and fires agents as
business needs evolve — all running on Claude Code with markdown files as
the database.

## Quick Start

\```bash
npx create-orgagent my-company
cd my-company
claude
\```

Then type `/onboard` to start the alignment conversation.

## Features

- 🏗️ **Self-organizing** — CAO dynamically creates agents as needed
- 🧠 **OpenClaw-inspired** — Each agent has SOUL, IDENTITY, MEMORY, HEARTBEAT
- 📁 **Filesystem = Database** — All state in readable markdown files
- 🔒 **Governance** — Hooks enforce audit trails, budgets, and approval gates
- 📊 **Dashboard** — Dark-theme GUI with org chart, task board, budget charts
- ⏰ **Autonomous** — Schedule heartbeats for fully autonomous operation
- 🌍 **Multilingual** — Set the org language during onboarding
```

---

## File Count Summary

### Template files created by scaffolding: ~30 files

| Category | Count | Files |
|----------|-------|-------|
| Claude Code config | 5 | CLAUDE.md, settings.json, 2 rules, .gitignore |
| Agent definitions | 2 | ceo.md, cao.md |
| Skills | 16 | 16 SKILL.md files (incl. master-gpt-prompter + references) |
| Scripts | 12 | heartbeat.sh + 11 hook scripts |
| GUI | 11 | server.js + 3 public + 8 API routes |
| Project files | 2 | package.json, README.md |
| **Total** | **~48** | |

### Files created by onboarding: ~20+ files

| Category | Count | Files |
|----------|-------|-------|
| Org state | 5 | alignment.md, config.md, orgchart.md, audit-log.md, budget files |
| CEO workspace | 9 | SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY + dirs |
| CAO workspace | 9 | SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY + dirs |
| Initiatives | 1+ | initial-goals.md |
| **Total** | **~25+** | |

### Dynamically created by CAO: unlimited
Each new agent adds:
- 1 agent definition in `.claude/agents/`
- 9+ workspace files in `org/agents/{name}/`
- 1 approval file in `org/board/approvals/`
- 1 orgchart entry
