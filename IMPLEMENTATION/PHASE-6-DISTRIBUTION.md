# Phase 6: Distribution — create-orgagent npm Package

**Objective:** Package the project as `npx create-orgagent` for one-command setup.
**Files to create:** 3 (in a separate `create-orgagent/` directory)
**Depends on:** Phases 1-5 (all implementation complete)
**Estimated effort:** 2-3 hours

---

## Reference

- **Primary spec:** `TO-DO/11-DISTRIBUTION-PLAN.md` (complete packaging spec with code)
- **Also:** `TO-DO/09-ARCHITECTURE-DECISIONS.md` → Decision 2

---

## Task 6.1: `create-orgagent/package.json` — npm Package Manifest

- [ ] **Create file:** `create-orgagent/package.json`
- **Spec:** `TO-DO/11-DISTRIBUTION-PLAN.md` → npm package section
- **Key content:**
  ```json
  {
    "name": "create-orgagent",
    "version": "1.0.0",
    "description": "Create a dynamic AI agent organisation powered by Claude Code",
    "bin": { "create-orgagent": "./bin/index.js" },
    "keywords": ["ai", "agent", "organisation", "claude-code", "autonomous"],
    "license": "MIT"
  }
  ```
- **Dependencies:** None (uses Node.js built-ins only)
- **Verify:** `node create-orgagent/bin/index.js --help` shows usage

---

## Task 6.2: `create-orgagent/bin/index.js` — Scaffolding CLI

- [ ] **Create file:** `create-orgagent/bin/index.js`
- **Spec:** `TO-DO/11-DISTRIBUTION-PLAN.md` → bin/index.js section (full code provided)
- **Key content:**
  - Shebang: `#!/usr/bin/env node`
  - Reads project name from argv[2]
  - Copies entire `template/` directory to target
  - Runs `npm install` in target
  - Runs `git init` in target
  - Prints welcome message with next steps
  - `copyDirRecursive()` helper
- **Template directory:** `create-orgagent/template/` — this IS the built project (everything from Phases 1-5)
- **Dependencies:** Task 6.1
- **Verify:** `node create-orgagent/bin/index.js test-project` creates a working project

---

## Task 6.3: `README.md` — Project Documentation

- [ ] **Create file:** `README.md` (project root)
- **Spec:** `TO-DO/11-DISTRIBUTION-PLAN.md` → README hero section
- **Key content:**
  - Hero: project name, tagline, description
  - Quick Start: 3 commands (npx, cd, claude → /onboard)
  - Features list (self-organizing, OpenClaw-inspired, filesystem DB, governance, dashboard, multilingual)
  - Architecture overview (brief)
  - Skills reference table
  - GUI screenshot placeholder
  - Requirements (Node.js 20+, Claude Code, Anthropic API key)
  - License
- **Dependencies:** None
- **Verify:** Reads well in GitHub markdown preview

---

## Distribution Build Process

After all tasks are done, to prepare for npm publish:

```bash
# 1. Create template directory (copy from project)
mkdir -p create-orgagent/template
cp -r .claude create-orgagent/template/
cp -r scripts create-orgagent/template/
cp -r gui create-orgagent/template/
cp package.json create-orgagent/template/
cp .gitignore create-orgagent/template/
cp CLAUDE.md create-orgagent/template/
cp README.md create-orgagent/template/

# 2. Remove user-specific files from template
rm -f create-orgagent/template/.claude/settings.local.json

# 3. Test scaffolding
cd /tmp
node /path/to/create-orgagent/bin/index.js test-company
cd test-company
claude  # Should load correctly
# Type /onboard to test

# 4. Publish to npm (when ready)
cd create-orgagent
npm publish
```

**Alternative: GitHub Template Repository**
1. Push project to GitHub
2. Settings → check "Template repository"
3. Users click "Use this template" to create their own copy

---

## Phase 6 Verification

```bash
# Distribution files exist
[ -f create-orgagent/package.json ] && echo "OK: package.json" || echo "MISSING"
[ -f create-orgagent/bin/index.js ] && echo "OK: bin/index.js" || echo "MISSING"
[ -f README.md ] && echo "OK: README.md" || echo "MISSING"

# Scaffolding works end-to-end
node create-orgagent/bin/index.js /tmp/test-orgagent-$(date +%s)
ls /tmp/test-orgagent-*/.claude/settings.json  # Should exist
```
