# GAP-13: No Testing Infrastructure — Comprehensive Test Suite

**Date:** 2026-04-02
**Status:** Research complete, ready for implementation
**Priority:** HIGH — Without this, governance hooks, skills, and scripts are unvalidated
**Dependencies:** bats-core (to install), vitest (to install), supertest (to install), zod (to install)
**Estimated Effort:** Phase 1: 6-10 hours, Phase 2: 8-12 hours, Phase 3: 4-8 hours, Phase 4: future

---

## 1. The Problem

OrgAgent has **zero tests** anywhere in the codebase:

- **14 bash hook scripts** enforce governance but are NEVER tested — a bug in `data-access-check.sh` means unauthorized data access goes undetected
- **24 skills** define workflows but are NEVER validated — a malformed skill could produce corrupted state
- **heartbeat.sh** orchestrates multi-agent execution but is NEVER tested — a parsing bug in orgchart processing could invoke wrong agents
- **run-org.sh** implements the Ralph Wiggum loop but is NEVER tested — a logic error in pending-work detection could cause infinite loops
- **GUI (Express + WebSocket + chokidar)** has no tests — broken API responses = broken dashboard
- **26 file formats** specified in TO-DO/10 have no schema validation — any file can be silently malformed
- **No CI pipeline** — no GitHub Actions workflows exist
- `package.json` has no `test` script and no test dependencies
- `IMPLEMENTATION/PHASE-7-TESTING.md` contains only manual verification checklists (18 scenarios + 5 edge cases), zero automated tests

---

## 2. Research Findings

### 2.1 Bash Script Testing — bats-core

**Source:** [bats-core documentation](https://bats-core.readthedocs.io/en/stable/writing-tests.html)

**Why bats-core wins for OrgAgent:**
- TAP-compliant output (CI-friendly)
- Native stdin piping support via `bats_pipe` helper — critical since all 14 hooks read JSON from stdin via `INPUT=$(cat)`
- npm installable: `npm install --save-dev bats` (latest: 1.13.0)
- Runs on Windows Git Bash (MSYS2-based) — the project's target platform
- Ecosystem libraries: `bats-assert` (assertions), `bats-support` (helpers), `bats-mock` (stubbing external commands)

**How OrgAgent hooks work (input/output contract):**

Every hook script follows the same pattern:
1. Reads JSON from stdin: `INPUT=$(cat)`
2. Extracts fields with `jq`: tool_name, tool_input.file_path, tool_input.content, agent_name
3. Reads environment variables: `ORGAGENT_CURRENT_AGENT`, `ORGAGENT_ORG_DIR`
4. Reads filesystem state: IDENTITY.md, orgchart.md, config.md, activity files
5. Exits with code: `0` (allow), `1` (warn with JSON output), `2` (block with stderr message)

This is perfectly testable with bats-core: pipe JSON to stdin, set env vars, create temp filesystem fixtures, assert exit codes and stderr output.

**Example test for `data-access-check.sh`:**

```bash
#!/usr/bin/env bats

setup() {
  export ORGAGENT_ORG_DIR="$BATS_TMPDIR/test-org-$$"
  mkdir -p "$ORGAGENT_ORG_DIR/agents/worker1"
  
  cat > "$ORGAGENT_ORG_DIR/agents/worker1/IDENTITY.md" << 'EOF'
---
access_read:
  - org/agents/worker1/
  - org/threads/
access_write:
  - org/agents/worker1/
---
EOF
}

teardown() {
  rm -rf "$ORGAGENT_ORG_DIR"
}

@test "board has full access" {
  export ORGAGENT_CURRENT_AGENT="board"
  run bash scripts/hooks/data-access-check.sh <<< \
    '{"tool_name":"Read","tool_input":{"file_path":"org/budgets/overview.md"}}'
  [ "$status" -eq 0 ]
}

@test "worker blocked from reading budget" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash scripts/hooks/data-access-check.sh <<< \
    '{"tool_name":"Read","tool_input":{"file_path":"org/budgets/overview.md"}}'
  [ "$status" -eq 2 ]
  [[ "$output" == *"ACCESS DENIED"* ]]
}

@test "worker allowed to read own workspace" {
  export ORGAGENT_CURRENT_AGENT="worker1"
  run bash scripts/hooks/data-access-check.sh <<< \
    '{"tool_name":"Read","tool_input":{"file_path":"org/agents/worker1/IDENTITY.md"}}'
  [ "$status" -eq 0 ]
}
```

### 2.2 Hook-by-Hook Testability Analysis

| Hook | Exit Codes | External Deps | Filesystem Deps | Test Difficulty |
|------|-----------|---------------|-----------------|----------------|
| `data-access-check.sh` | 0, 2 | jq, awk, grep | Reads IDENTITY.md | Easy (pure logic) |
| `message-routing-check.sh` | 0, 2 | jq, grep, sed, awk | Reads orgchart.md | **Hard** (complex hierarchy parsing) |
| `alignment-protect.sh` | 0, 2 | jq | None (path check) | Trivial |
| `require-board-approval.sh` | 0, 2 | jq | None (path check) | Trivial |
| `require-cao-or-board.sh` | 0, 2 | jq | None (path check) | Trivial |
| `skill-access-check.sh` | 0, 2 | None | None (env check) | Trivial |
| `activity-logger.sh` | 0 only | jq, date | Creates dirs, writes files | Medium (verify file creation) |
| `budget-check.sh` | 0, 2 | grep, awk | Reads budgets/overview.md | Easy |
| `remind-state-update.sh` | 0, 1 | grep, stat, date | Reads activity, current-state | Medium |
| `spending-governor.sh` | 0, 2 | jq, grep, awk | Reads config.md | Easy |
| `alignment-check.sh` | 0, 1 | jq, grep | None (content check) | Easy |
| `log-agent-activation.sh` | 0 | jq, date | Writes to audit-log.md | Easy (verify append) |
| `log-agent-deactivation.sh` | 0 | jq, date | Writes to audit-log.md | Easy (verify append) |
| `require-state-and-communication.sh` | 0, 2 | grep, awk, date | Reads current-state, activity | Medium |

**Highest-value test target:** `message-routing-check.sh` — parses orgchart hierarchy by walking lines with indentation-based depth, finds supervisors by traversing upward, and applies 6 different routing rules. A bug here silently allows unauthorized communication.

**Sources:**
- [bats-core GitHub](https://github.com/bats-core/bats-core)
- [bats-assert npm](https://www.npmjs.com/package/bats-assert)
- [bats-mock GitHub](https://github.com/jasonkarns/bats-mock)
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck)
- [Testing Bash Scripts with BATS — Baeldung](https://www.baeldung.com/linux/testing-bash-scripts-bats)

### 2.3 Testing AI Agent Systems (SOTA 2025-2026)

**What is testable WITHOUT running the LLM:**

| Component | Testable? | Framework |
|-----------|-----------|-----------|
| All 14 hook scripts | YES (pure bash, deterministic) | bats-core |
| All 9 GUI API modules | YES (Express routes reading filesystem) | vitest + supertest |
| WebSocket broadcast logic | YES (event categorization) | vitest |
| heartbeat.sh orchestration | YES (with mocked `claude` CLI) | bats-core |
| run-org.sh loop logic | YES (pending work detection, stop signals) | bats-core |
| File format validation | YES (all 26 formats have schemas) | vitest + zod |
| Orgchart parsing | YES (pure text processing) | bats-core |
| Budget calculations | YES (arithmetic on frontmatter) | bats-core |

**Requires LLM (integration/E2E only):**
- Skill execution (Claude follows markdown instructions)
- Agent quality of output
- Full heartbeat cycle with real agent reasoning

**Modular testing pyramid (from PwC validation framework):**
1. **Unit tests** — individual hook logic, parsers, validators
2. **Contract tests** — verify inter-agent communication protocols (thread format, inbox format)
3. **Integration tests** — verify agent A's output is valid input for agent B
4. **System tests** — full heartbeat cycle with real/mocked LLM
5. **Governance tests** — verify constitutional constraints (alignment protection, chain-of-command)

**Record-and-Replay pattern (Docker Cagent):** Capture real LLM API interactions once, replay deterministically in future test runs. Applicable for heartbeat.sh tests: record one real `claude --agent ceo` execution, replay in subsequent test runs.

**Sources:**
- [PwC: Validating Multi-Agent AI Systems](https://www.pwc.com/us/en/services/audit-assurance/library/validating-multi-agent-ai-systems.html)
- [Docker Cagent Deterministic Testing — InfoQ](https://www.infoq.com/news/2026/01/cagent-testing/)
- [AI Agent Testing 2026 — testomat.io](https://testomat.io/blog/ai-agent-testing/)
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)

### 2.4 Express.js API and WebSocket Testing — Vitest + Supertest

**Why Vitest over Jest:**
- 10-20x faster on large codebases (2025 benchmarks)
- Native ESM support
- Surpassed Jest for new projects in 2025
- Built-in snapshot testing
- Compatible with Supertest

**API Testing Pattern:**

All 9 API modules follow: `module.exports = function(router, orgDir)`. They read markdown from `orgDir`, parse with `gray-matter`, return JSON. Trivially testable:

1. Create temporary `orgDir` with fixture markdown files
2. Mount router on Express app
3. Use Supertest to hit endpoints
4. Assert JSON responses

**Example for `/api/agents`:**

```javascript
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import express from 'express';
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import os from 'os';

describe('GET /api/agents', () => {
  let app, tmpDir;

  beforeAll(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orgagent-test-'));
    const agentDir = path.join(tmpDir, 'agents', 'ceo');
    fs.mkdirSync(agentDir, { recursive: true });
    fs.writeFileSync(path.join(agentDir, 'IDENTITY.md'), `---
name: ceo
title: Chief Executive Officer
status: active
model: opus
department: executive
---
# CEO Identity
`);
    app = express();
    const router = express.Router();
    require('../gui/api/agents')(router, tmpDir);
    app.use('/api', router);
  });

  afterAll(() => { fs.rmSync(tmpDir, { recursive: true }); });

  it('returns agents with parsed frontmatter', async () => {
    const res = await request(app).get('/api/agents');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(1);
    expect(res.body[0].name).toBe('ceo');
    expect(res.body[0].model).toBe('opus');
  });

  it('returns empty array when no agents dir', async () => {
    const emptyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'empty-'));
    const app2 = express();
    const router2 = express.Router();
    require('../gui/api/agents')(router2, emptyDir);
    app2.use('/api', router2);
    const res = await request(app2).get('/api/agents');
    expect(res.body).toEqual([]);
    fs.rmSync(emptyDir, { recursive: true });
  });
});
```

**WebSocket Testing:** Use `ws` library client (already a dependency), connect to test server, trigger file changes, assert received messages. Set 15s timeouts and force-close connections in `afterAll`.

**Sources:**
- [Vitest in 2026](https://dev.to/ottoaria/vitest-in-2026-the-testing-framework-that-makes-you-actually-want-to-write-tests-kap)
- [WebSocket Integration Tests (Medium)](https://thomason-isaiah.medium.com/writing-integration-tests-for-websocket-servers-using-jest-and-ws-8e5c61726b2a)
- [Using temporary files with Vitest](https://sdorra.dev/posts/2024-02-12-vitest-tmpdir)

### 2.5 File Format Schema Validation — gray-matter + Zod

**Why gray-matter + Zod:**
- `gray-matter` is already a dependency — used by 6 of 9 API modules
- `zod-matter` wraps gray-matter with Zod schema validation
- Zod schemas can be reused as both runtime validators AND test assertions
- Clear error messages for debugging

**Schema example for IDENTITY.md:**

```javascript
import { z } from 'zod';

export const identitySchema = z.object({
  name: z.string().min(1),
  title: z.string().min(1),
  status: z.enum(['active', 'pending-approval', 'paused', 'terminated']),
  model: z.enum(['opus', 'sonnet', 'haiku']).optional(),
  department: z.string().optional(),
  reports_to: z.string().min(1),
  tools: z.array(z.string()).optional(),
  skills: z.array(z.string()).optional(),
  access_read: z.array(z.string()),
  access_write: z.array(z.string()),
  created: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});
```

**Schema catalog to build (maps to the 26 file formats):**

| Schema | File Pattern | Key Fields |
|--------|-------------|-----------|
| configSchema | org/config.md | name, language, oversight_level, currency |
| identitySchema | org/agents/*/IDENTITY.md | name, title, status, model, tools, access_* |
| taskSchema | org/agents/*/tasks/*/*.md | id, title, priority, status, assigned_to, initiative |
| threadSchema | org/threads/**/*.md | thread_id, topic, department, participants, status |
| notificationSchema | org/agents/*/inbox/*.md | type, from, thread_id, read |
| approvalSchema | org/board/approvals/*.md | id, type, proposed_by, status |
| budgetOverviewSchema | org/budgets/overview.md | total_budget_usd, total_allocated_usd |
| currentStateSchema | org/agents/*/activity/current-state.md | agent, status, last_updated |

**Sources:**
- [zod-matter GitHub](https://github.com/HiDeoo/zod-matter)
- [Zod GitHub](https://github.com/colinhacks/zod)
- [Comparing Schema Validation Libraries (Bitovi)](https://www.bitovi.com/blog/comparing-schema-validation-libraries-ajv-joi-yup-and-zod)

### 2.6 Snapshot / Golden File Testing

**Applicable scenarios:**
1. **API response snapshots:** Set up fixture org, snapshot JSON responses from each API endpoint. Changes that break response shape are caught.
2. **Hook output snapshots:** For hooks that produce output, snapshot the exact format.
3. **Org scaffolding snapshots:** After running `create-orgagent`, snapshot the directory tree.

```javascript
it('GET /api/orgchart returns expected tree structure', async () => {
  const res = await request(app).get('/api/orgchart');
  expect(res.body).toMatchSnapshot();
});
```

**Caveat:** Snapshots are fragile — any formatting change requires updating. Use for structural contracts (API shapes, directory layouts) not frequently changing content.

### 2.7 Static Analysis — ShellCheck

ShellCheck catches portability issues, quoting bugs, uninitialized variables in bash scripts. Pre-installed on GitHub Actions Ubuntu runners.

```bash
shellcheck scripts/hooks/*.sh scripts/*.sh
```

Should be run as part of every CI pipeline and as a pre-commit check.

---

## 3. Recommended Test Architecture

### 3.1 Dependencies to Add

```json
{
  "devDependencies": {
    "vitest": "^3.0.0",
    "supertest": "^7.0.0",
    "zod": "^3.24.0",
    "bats": "^1.13.0"
  }
}
```

### 3.2 Test Directory Structure

```
tests/
  hooks/                           # bats-core tests for all 14 bash hooks
    activity-logger.test.bats
    alignment-check.test.bats
    alignment-protect.test.bats
    budget-check.test.bats
    data-access-check.test.bats
    log-agent-activation.test.bats
    log-agent-deactivation.test.bats
    message-routing-check.test.bats
    remind-state-update.test.bats
    require-board-approval.test.bats
    require-cao-or-board.test.bats
    require-state-and-communication.test.bats
    skill-access-check.test.bats
    spending-governor.test.bats
    helpers/
      setup.bash                   # Shared: create tmp org dir, fixtures
  scripts/                         # bats-core tests for orchestration
    heartbeat.test.bats            # Orgchart parsing, phase ordering
    run-org.test.bats              # Pending work detection, stop signal, idle
  gui/
    api/
      agents.test.js               # Vitest + Supertest
      agent.test.js
      approvals.test.js
      audit.test.js
      budget.test.js
      chat.test.js
      messages.test.js
      orgchart.test.js
      tasks.test.js
    server.test.js                 # WebSocket + categorize() tests
  schemas/                         # Zod schema definitions (reusable)
    config.js
    identity.js
    task.js
    thread.js
    notification.js
    approval.js
    budget.js
    current-state.js
  validation/                      # Schema validation tests
    file-formats.test.js           # Validates all 26 file formats against schemas
  fixtures/                        # Shared test fixtures
    org/                           # Minimal valid org directory
      config.md
      alignment.md
      orgchart.md
      agents/
        ceo/
          IDENTITY.md
          SOUL.md
          INSTRUCTIONS.md
          HEARTBEAT.md
          MEMORY.md
          activity/current-state.md
          tasks/backlog/
          tasks/active/
          tasks/done/
          inbox/
        cao/
          IDENTITY.md
      board/
        audit-log.md
        approvals/
        decisions/
      budgets/
        overview.md
        spending-log.md
      threads/
        executive/
  integration/                     # End-to-end (optional, requires LLM)
    scaffolding.test.js            # Test create-orgagent output
```

### 3.3 Package.json Scripts

```json
{
  "scripts": {
    "test": "vitest run && bats tests/hooks/*.bats tests/scripts/*.bats",
    "test:hooks": "bats tests/hooks/*.bats",
    "test:scripts": "bats tests/scripts/*.bats",
    "test:gui": "vitest run tests/gui/",
    "test:schemas": "vitest run tests/validation/",
    "test:watch": "vitest watch",
    "test:coverage": "vitest run --coverage",
    "lint:bash": "shellcheck scripts/hooks/*.sh scripts/*.sh"
  }
}
```

---

## 4. Test Priority (by risk and value)

### Priority 1: Governance Hooks (~50 test cases)

These are security boundaries. A bug means unauthorized access.

| Hook | Test Cases | Critical Scenarios |
|------|-----------|-------------------|
| `data-access-check.sh` | 8 | Board bypass, worker read own workspace, worker blocked from budget, path traversal |
| `message-routing-check.sh` | 12 | Worker→CEO blocked, worker→manager allowed, cross-dept blocked, urgent bypass, CEO→all allowed |
| `alignment-protect.sh` | 5 | Agent blocked from alignment.md, board allowed, drift file detection |
| `require-board-approval.sh` | 4 | Agent blocked from decisions/, board allowed |
| `require-cao-or-board.sh` | 5 | Worker blocked from .claude/agents/, CAO allowed, board allowed |
| `skill-access-check.sh` | 4 | Worker blocked from hire-agent, CAO allowed |
| `spending-governor.sh` | 6 | Below threshold allowed, above threshold blocked, board exempt, alignment-board exempt |
| `budget-check.sh` | 6 | Budget OK, budget exhausted, budget >80% warning |

### Priority 2: GUI API Modules (~40 test cases)

Dashboard data correctness.

| Module | Test Cases | Critical Scenarios |
|--------|-----------|-------------------|
| agents.js | 5 | List agents, empty org, parse frontmatter, handle missing fields |
| tasks.js | 8 | Filter by status/agent/initiative, sorting, empty backlog |
| budget.js | 5 | Parse budget table, calculate remaining, handle missing spending-log |
| orgchart.js | 5 | Parse hierarchy, handle malformed input |
| approvals.js | 5 | List pending, filter by status |
| messages.js | 6 | Parse message blocks, filter by thread |
| audit.js | 3 | Parse audit log table |
| chat.js | 3 | API endpoint contract |

### Priority 3: File Format Schemas (~100 test cases)

Contract validation between skills, hooks, and GUI.

- ~26 schemas × ~4 test cases each (valid, missing required field, invalid enum value, edge cases)

### Priority 4: Orchestration Scripts (~20 test cases)

| Script | Test Cases | Critical Scenarios |
|--------|-----------|-------------------|
| heartbeat.sh `parse_orgchart()` | 6 | Parse hierarchy, identify agents by depth, handle empty org |
| heartbeat.sh `run_agent()` | 4 | Success, failure, cost extraction, model detection |
| run-org.sh `check_pending_work()` | 6 | Unread inbox, pending approvals, recent tasks, empty org |
| run-org.sh `check_stop_signal()` | 3 | No signal, signal exists, signal created during cycle |

### Priority 5: Operational Hooks (~20 test cases)

| Hook | Test Cases | Critical Scenarios |
|------|-----------|-------------------|
| activity-logger.sh | 4 | Creates activity dir, writes log entry, handles missing dirs |
| remind-state-update.sh | 4 | Fresh state OK, stale state warning, missing state |
| require-state-and-communication.sh | 6 | State current, state stale, tasks without threads |

### Priority 6: WebSocket Integration (~10 test cases)

Verify broadcast on file change, event categorization, client connection handling.

### Priority 7 (Deferred): LLM Integration (~5 test cases)

Record-and-replay a real heartbeat cycle. Complex setup, high cost.

---

## 5. Test Fixtures

### Minimal Valid Org Fixture

A complete, valid `org/` directory that all tests can use as a baseline:

```
tests/fixtures/org/
  config.md          — valid config with all required fields
  alignment.md       — valid alignment document
  orgchart.md        — 3 agents (board → ceo → worker1)
  agents/
    ceo/
      IDENTITY.md    — active, opus, reports to board
      SOUL.md        — minimal valid
      INSTRUCTIONS.md
      HEARTBEAT.md
      MEMORY.md
      activity/
        current-state.md — today's date, idle status
      tasks/
        backlog/
        active/
        done/
      inbox/
      reports/
    worker1/
      IDENTITY.md    — active, haiku, reports to ceo
      ... (same structure)
  board/
    audit-log.md     — valid table header + 1 entry
    approvals/       — empty (no pending)
    decisions/       — empty
  budgets/
    overview.md      — valid budget with 2 agent allocations
    spending-log.md  — valid table header + 1 entry
  threads/
    executive/       — empty
```

Each test copies this fixture to a temp directory, modifies what it needs, and cleans up after.

---

## 6. CI Pipeline

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npm run lint:bash
      - run: npm run test
```

**Note:** bats-core requires `jq` on the runner (pre-installed on GitHub Actions Ubuntu). Windows CI would need Git Bash.

---

## 7. Implementation Plan

### Phase 1: Governance Hook Tests (6-10 hours)

1. Install dependencies: `npm install --save-dev vitest supertest zod bats`
2. Create `tests/hooks/helpers/setup.bash` with shared fixture creation
3. Write tests for all 7 PreToolUse hooks (security boundaries):
   - `data-access-check.test.bats` (8 tests)
   - `message-routing-check.test.bats` (12 tests) — highest complexity
   - `alignment-protect.test.bats` (5 tests)
   - `require-board-approval.test.bats` (4 tests)
   - `require-cao-or-board.test.bats` (5 tests)
   - `skill-access-check.test.bats` (4 tests)
   - `spending-governor.test.bats` (6 tests)
4. Add `npm run test:hooks` script
5. Run ShellCheck on all hooks, fix any warnings

### Phase 2: GUI API & Schema Tests (8-12 hours)

6. Create Zod schemas for all 26 file formats in `tests/schemas/`
7. Create test fixtures in `tests/fixtures/org/`
8. Write API tests for all 9 modules:
   - agents.test.js, tasks.test.js, budget.test.js, orgchart.test.js
   - approvals.test.js, messages.test.js, audit.test.js, chat.test.js, agent.test.js
9. Write schema validation tests in `tests/validation/file-formats.test.js`
10. Write WebSocket tests in `tests/gui/server.test.js`
11. Add `npm run test:gui` and `npm run test:schemas` scripts

### Phase 3: Orchestration Script Tests (4-8 hours)

12. Write `tests/scripts/heartbeat.test.bats`:
    - Mock `claude` CLI with a bash function that outputs JSON
    - Test orgchart parsing (`parse_orgchart()` function)
    - Test phase ordering (alignment → CEO → managers → workers → CAO)
    - Test cost extraction from mock output
    - Test model detection from IDENTITY.md
13. Write `tests/scripts/run-org.test.bats`:
    - Test pending work detection (`check_pending_work()`)
    - Test stop signal detection
    - Test idle check logic
    - Test max cycle limit

### Phase 4: CI Pipeline & Advanced (Future)

14. Create `.github/workflows/test.yml`
15. Add `npm test` to package.json as the unified test command
16. Add test coverage tracking (`vitest --coverage`)
17. Create integration test framework with record-and-replay
18. Create scaffolding test (`create-orgagent` output validation)
19. Add chaos tests (fault injection for self-healing validation — per GAP-06)

---

## 8. Architecture Decisions

### Decision 77: bats-core for Bash, Vitest for JavaScript
**Decision:** Use bats-core for testing all bash scripts (hooks, heartbeat.sh, run-org.sh). Use Vitest + Supertest for testing all JavaScript code (GUI server, API modules). Use Zod for file format schema validation.
**Reasoning:** Each framework is the best fit for its domain. bats-core handles stdin piping for hook testing. Vitest is the fastest modern JS test runner. Zod schemas can be reused for both testing and runtime validation (per GAP-06 integrity checker).

### Decision 78: Test Fixtures as Minimal Valid Org
**Decision:** Create a shared test fixture directory (`tests/fixtures/org/`) containing a minimal but complete valid org state. All tests copy from this fixture and modify as needed.
**Reasoning:** A shared fixture prevents test duplication and ensures consistency. Each test starts from known-good state. Temp directories with cleanup prevent test pollution.

### Decision 79: Governance Hooks Are Highest Test Priority
**Decision:** The first tests written should be for the 7 PreToolUse governance hooks. These are security boundaries — a bug means unauthorized data access, communication bypass, or alignment violation.
**Reasoning:** The governance layer is OrgAgent's key differentiator. If hooks don't work correctly, the entire trust model collapses. Other tests validate convenience; governance tests validate safety.

### Decision 80: Schema Validation Serves Double Duty
**Decision:** Zod schemas created for testing are also usable at runtime by the integrity checker (GAP-06) and by the GUI API modules. The schemas are shared code, not test-only artifacts.
**Reasoning:** Writing schemas once and using them for both testing and runtime validation eliminates divergence. A format change updates one schema, not separate test expectations and validation code.

---

## 9. Sources

- [bats-core documentation](https://bats-core.readthedocs.io/en/stable/writing-tests.html)
- [bats-core GitHub](https://github.com/bats-core/bats-core)
- [ShellCheck GitHub](https://github.com/koalaman/shellcheck)
- [Vitest in 2026](https://dev.to/ottoaria/vitest-in-2026-the-testing-framework-that-makes-you-actually-want-to-write-tests-kap)
- [node:test vs Vitest vs Jest 2026](https://www.pkgpulse.com/blog/node-test-vs-vitest-vs-jest-native-test-runner-2026)
- [Supertest GitHub](https://github.com/ladjs/supertest)
- [zod-matter GitHub](https://github.com/HiDeoo/zod-matter)
- [Zod GitHub](https://github.com/colinhacks/zod)
- [PwC: Validating Multi-Agent AI Systems](https://www.pwc.com/us/en/services/audit-assurance/library/validating-multi-agent-ai-systems.html)
- [Docker Cagent Deterministic Testing — InfoQ](https://www.infoq.com/news/2026/01/cagent-testing/)
- [AI Agent Testing 2026 — testomat.io](https://testomat.io/blog/ai-agent-testing/)
- [Testing Bash Scripts with BATS — Baeldung](https://www.baeldung.com/linux/testing-bash-scripts-bats)
- [Vitest Snapshot Guide](https://vitest.dev/guide/snapshot)
- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
