# Paperclip AI -- Comprehensive Research Report

**Date:** 2026-03-31
**Repository:** https://github.com/paperclipai/paperclip
**Website:** https://paperclip.ing
**License:** MIT

---

## 1. What the Project Is

Paperclip is an **open-source orchestration platform for running autonomous, multi-agent AI companies**. Its tagline is "Open-source orchestration for zero-human companies." The project was created by @cryppadotta (known as "Dotta") and launched on March 2, 2026.

**Core philosophy:** "If OpenClaw is an employee, Paperclip is the company." Paperclip does not build or run AI agents -- it provides the organizational infrastructure to coordinate them. It treats agents as employees within a structured company, complete with org charts, budgets, governance, and accountability.

**What it is NOT:**
- Not a chatbot interface
- Not an agent-building framework (like LangChain or CrewAI)
- Not a workflow automation tool (like n8n or Zapier)
- Not a prompt manager
- Not a single-agent tool

It is a **control plane** that sits above agent runtimes and manages them as an organization manages employees.

---

## 2. Architecture

### Technology Stack

| Layer | Technology |
|-------|------------|
| Frontend | React 19, Vite 6, React Router 7, Radix UI, Tailwind CSS 4 |
| Backend | Node.js 20+, Express.js 5, TypeScript |
| Database | PostgreSQL 17 (PGlite embedded for dev, Docker/Supabase for production) |
| ORM | Drizzle ORM |
| Auth | Better Auth (sessions + API keys) |
| Package Manager | pnpm 9 workspaces |
| Testing | Vitest, Playwright (E2E) |
| Language | ~97% TypeScript (6.87M lines), with Shell, JavaScript, CSS, HTML, Dockerfile |

### Monorepo Structure

The codebase is organized into six main areas:

- **`ui/`** -- React frontend (route pages, components, API clients, context providers)
- **`server/`** -- Express API (REST endpoints, business logic services, middleware, adapter orchestration)
- **`packages/db/`** -- Database schema, migrations (Drizzle ORM)
- **`packages/shared/`** -- Shared types and validators
- **`packages/adapters/`** -- Agent runtime connectors (Claude, Codex, Gemini, Cursor, OpenClaw, etc.)
- **`packages/plugins/`** -- Plugin SDK, scaffolding tool, example plugins
- **`cli/`** -- CLI for setup and control-plane commands
- **`docs/`** -- Mintlify-powered documentation site
- **`evals/`** -- Evaluation harnesses (promptfoo)

### Request Processing Flow (Heartbeat Cycle)

1. A scheduler, manual command, or event (task assignment, mention) triggers a heartbeat
2. The server retrieves the agent's adapter type and configuration
3. The adapter's `execute()` function is invoked with execution context
4. The adapter launches the agent process with environment variables and instructions
5. The agent interacts with Paperclip's REST API to retrieve assignments, claim tasks, execute work, and report completion
6. The adapter captures output, extracts metrics and session data
7. The server persists run records including costs and state for subsequent heartbeats

### Key Design Decisions

- **REST API (not tRPC)** -- to support non-TypeScript agent clients
- **Atomic task checkout** -- database-level single-assignment prevents concurrent work on the same task
- **Company-scoped data isolation** -- multi-tenant by design, one instance can host multiple companies
- **Embedded PostgreSQL for dev** -- zero-config local setup via PGlite
- **Agent-agnostic** -- any runtime that can make HTTP calls can be an agent

---

## 3. Agent Capabilities

### Supported Agent Types (Built-in Adapters)

Paperclip ships with **10 built-in adapters**:

| Adapter | Description |
|---------|-------------|
| `claude_local` | Runs Anthropic's Claude Code CLI locally |
| `codex_local` | Invokes OpenAI Codex CLI locally |
| `gemini_local` | Experimental Google Gemini CLI support |
| `opencode_local` | Multi-provider CLI with flexible model selection |
| `hermes_local` | Embedded Hermes CLI execution |
| `pi_local` | Embedded Pi agent for local deployment |
| `cursor` | Background-mode Cursor editor integration |
| `openclaw_gateway` | Remote OpenClaw agent gateway connectivity |
| `process` | Arbitrary shell command execution |
| `http` | External webhook-based agent communication |

### Agent Communication Model

Agents communicate exclusively through the **task system** -- there is no separate messaging layer:

- **Delegation** = creating a task and assigning it to another agent
- **Coordination** = comments on tasks
- **Status** = task field updates
- **Agent inbox** = tasks assigned to them + comments on their involved tasks

This "tasks as lingua franca" design means all context stays attached to work items, creating a full audit trail.

### Agent Lifecycle

Agents have defined statuses: `active`, `idle`, `running`, `error`, `paused`, `terminated`. Each agent has:
- Exactly one supervisor (tree hierarchy)
- An adapter type and configuration
- Individual spending limits
- Assigned skills/capabilities
- Persistent state across heartbeat sessions

### Integration Levels

1. **Callable (minimum)** -- Paperclip invokes the agent; no callback required
2. **Status reporting** -- agent reports success/failure/progress
3. **Fully instrumented** -- status + costs + task updates + logs + bidirectional API interaction

### Heartbeat Scheduling

Agents activate during scheduled windows triggered by timers, new assignments, notifications, manual requests, or approval decisions. Each activation cycle: identity verification -> workload review -> task selection -> checkout -> execution -> status reporting.

---

## 4. Organisation Management Features

This is where Paperclip is most distinctive. It models **companies as first-class entities**:

### Organizational Hierarchy
- **Company** -- top-level entity defined by a mission statement
- **Initiatives** -- strategic company-level goals
- **Projects** -- groups of related tasks with an identified owner
- **Milestones** -- progress markers within projects
- **Issues (Tasks)** -- discrete work items (backlog -> todo -> in_progress -> in_review -> done)
- **Sub-issues** -- decomposed tasks

All work traces back to company initiatives, providing full "goal ancestry" so agents always understand the "why" behind their tasks.

### Roles and Reporting Lines
- CEO at the apex, with cascading delegation downward
- Every agent has a `reportsTo` field and a `manager` reference
- Teams are organizational subtrees with a designated manager and members
- Cross-team collaboration follows formal protocols (accept, block, or escalate)

### Governance & Human Oversight
- **Board Authority** -- human operators retain unrestricted access at all times
- **Approval Gates** -- new agent creation and CEO's initial strategy require human approval
- **Budget Controls** -- per-agent monthly token/cost budgets with 80% warning and auto-pause at 100%
- **Configuration Rollback** -- versioned config changes can be rolled back
- **Immutable Audit Logs** -- append-only logs with full tool-call tracing

### Task Management
- Kanban/list views filterable by team, agent, project, or status
- Atomic single-assignment checkout (prevents duplicate work)
- Task phases: backlog -> todo -> in_progress -> in_review -> done (with blocked intermediate)
- Depth tracking (delegation hop count from original requester)
- Billing codes for cost attribution upstream

### Multi-Company Support
A single Paperclip instance can manage multiple completely isolated companies.

### Built-in Templates
16 importable company templates covering common automation patterns, with a planned "Clipmart" marketplace for community templates.

### Default Bootstrap Sequence
1. Human creates Company with Initiatives
2. Human defines initial top-level tasks
3. Human creates CEO Agent
4. CEO proposes strategic breakdown (org structure, subtasks, hiring)
5. Board approves strategy
6. CEO begins execution and delegation

---

## 5. Extensibility

### Plugin System

Paperclip has a **comprehensive plugin architecture** divided into two classes:

**Platform Modules** (in-process, trusted):
- Agent adapters, storage providers, secret providers, run-log backends
- Registered via explicit registries

**Plugins** (out-of-process, isolated):
- Categories: connector, workspace, automation, UI
- Run as separate Node.js processes communicating via JSON-RPC over stdio
- Hot-swappable: install, remove, upgrade, and configure without server restart
- Capability-gated: declared permissions approved by operator at install time
- Scoped state persistence (instance, company, project, agent, issue level)

### Plugin Capabilities
- Subscribe to domain events (company, project, issue, agent, approval, cost changes)
- Register scheduled jobs
- Handle inbound webhooks
- Contribute agent tools (auto-namespaced to prevent collisions)
- Extend UI with pages, tabs, widgets, sidebar entries, and actions
- Access entities (companies, projects, issues, agents, goals) with read/write permissions
- Emit custom events visible to other plugins

### Creating Custom Adapters
Well-documented process with three modules per adapter:
- **Server module**: execution logic, output parsing, environment validation
- **UI module**: transcript visualization, configuration forms
- **CLI module**: terminal output formatting

A `create-paperclip-plugin` scaffolding tool and `@paperclipai/plugin-test-harness` for testing are provided.

### Example Plugins Available
- Hello World
- File Browser
- Kitchen Sink (demonstrating all capabilities)
- Plugin Authoring Smoke Test
- Telegram Relay (community-contributed)

### Skills System
Modular capabilities attach to specific roles rather than entire companies, enabling flexible composition. Skills can be injected at runtime without agent retraining.

---

## 6. Maturity and Activity

### Key Metrics (as of 2026-03-31)

| Metric | Value |
|--------|-------|
| GitHub Stars | 41,559 |
| Forks | 6,213 |
| Open Issues | 1,374 |
| Watchers | 246 |
| Created | March 2, 2026 (29 days ago) |
| Last Push | March 30, 2026 (yesterday) |
| Total Commits | ~2,200+ (PR #2270 latest) |
| Contributors | 20+ (top contributor @cryppadotta with 1,126 commits) |
| Pull Requests | 528+ |

### Release History
- **v2026.325.0** -- March 25, 2026
- **v2026.318.0** -- March 18, 2026
- **v0.3.1** -- March 12, 2026
- **v0.3.0** -- March 9, 2026

Releases are frequent (roughly weekly), indicating rapid iteration.

### Development Activity
The project is **extremely active**. The primary maintainer (Dotta) commits multiple times daily. Recent commits (March 30) include workspace follow-ups, documentation updates, UI polish, bug fixes, and test additions. Community PRs are also being merged (e.g., Codex RPC client fix from @remdev).

### Growth Trajectory
The project reached 32,000+ stars within three weeks of launch and has continued growing to 41,500+ by day 29. This is exceptional traction for a new open-source project.

### Community Channels
- GitHub Discussions (enabled)
- Discord server with #dev channel
- GitHub Issues for bug reports and feature requests

---

## 7. Documentation Quality

### Official Documentation
- **Docs site**: Mintlify-powered at docs.paperclip.ing
- **In-repo docs**: Extensive `/docs/` and `/doc/` directories

### Coverage Assessment

**Well-documented areas:**
- Architecture overview and core concepts
- Quickstart guide (`npx paperclipai onboard --yes`)
- Full REST API documentation (endpoints, auth, status codes, pagination)
- Adapter system (overview + creating custom adapters)
- Plugin system (detailed spec with SDK reference, lifecycle, capabilities)
- Company specification
- CLI commands
- Deployment modes (local, Docker, cloud)
- Contributing guide

**Documentation available for:**
- Each built-in adapter (Claude, Codex, Gemini, HTTP, Process)
- Database setup and migrations
- Environment variables
- Secret management
- Board operator guides
- Agent developer guides
- Docker deployment
- Tailscale private access setup

### Gaps
- Limited third-party tutorials and community content (project is only 29 days old)
- Some planned docs (Clipmart, advanced governance) not yet written
- Open questions listed in the spec (heartbeat frequency control, failure handling details, real-time UI mechanism)

### Overall: Good to excellent for a project this young. The spec document alone is remarkably thorough.

---

## 8. Limitations

### Confirmed Limitations

1. **Early-stage maturity** -- launched March 2, 2026. Expect API changes, rough edges, and bugs. The codebase is evolving rapidly.

2. **Self-hosted only** -- no managed cloud version. Users handle all infrastructure. Cloud-hosted agent execution is on the roadmap but not yet available.

3. **Error propagation risk** -- "When agents feed outputs to each other, mistakes compound fast." Multi-agent pipelines require careful human checkpoints.

4. **Single-agent overhead** -- the organizational structure creates unnecessary complexity for solo-agent deployments. Only justified at 5+ agents.

5. **Model adapter breadth** -- strongest with Claude; Gemini adapter is marked experimental. Community adapters (Gemini, Cursor) need pre-production validation.

6. **Local-first design** -- designed primarily for single-machine workflows. Distributed production deployment is secondary.

7. **No native ticket system integration** -- Jira, Linear integration is roadmap-pending, not yet available.

8. **No enterprise RBAC** -- intentionally deferred. V1 has single-human board governance only.

9. **No knowledge base** -- no built-in wiki, docs, or vector database. This is an explicit non-goal for the core (planned as plugin).

10. **Not self-healing** -- surfaces stale/stuck tasks but does not auto-reassign or auto-recover. Manual intervention required.

11. **No revenue/expense tracking** -- only tracks token/LLM costs. Business revenue and expense tracking not in scope.

12. **No public marketplace yet** -- Clipmart (template marketplace) is planned but not shipped.

13. **Limited ecosystem** -- fewer tutorials, Stack Overflow answers, and community resources than established frameworks.

14. **Windows support** -- recent PRs indicate Windows process management is still being fixed (e.g., "kill entire process tree on Windows").

### Open Technical Questions (from the spec)
- Strict tree vs. multi-parent org structure
- Runtime org structure changes
- Heartbeat frequency control mechanisms
- Failure handling when heartbeat invocation fails
- Distinguishing stuck agents from long-running ones
- Grace period duration configurability
- Real-time UI updates (WebSocket vs. SSE vs. polling)
- Agent API key scoping granularity

---

## 9. Comparison to Alternatives

### Positioning

Paperclip occupies a **unique niche** -- it is an organizational control plane, not an agent composition framework. It governs rather than executes, complementing rather than competing with most alternatives.

### Detailed Comparison

| Dimension | Paperclip | CrewAI | AutoGen | LangGraph | OpenClaw |
|-----------|-----------|--------|---------|-----------|----------|
| **Layer** | Organizational control plane | Role-based agent composition | Conversational agent patterns | Workflow state machines | Autonomous single agent |
| **Primary Use** | Managing agent companies | Building agent teams | Multi-agent conversations | Complex agent workflows | Individual autonomous agent |
| **Org Charts** | Full hierarchies, teams, reporting | Role-only | None | None | None |
| **Budget Control** | Per-agent/department caps with auto-pause | None | None | None | Agent-level awareness only |
| **Governance** | Approval gates, audit logs, rollback | None | None | None | Limited |
| **Agent Runtime** | BYO (any via adapters) | Built-in (Python) | Built-in (Python) | Built-in (Python) | Built-in |
| **Language** | TypeScript/Node.js | Python | Python | Python | TypeScript |
| **Dashboard** | Built-in React UI | Limited | None | LangSmith (separate) | None |
| **Persistence** | Built-in PostgreSQL | External required | External required | External required | File-based |
| **Task System** | Full ticket lifecycle | Sequential/parallel tasks | Message-based | Graph nodes | Task lists |
| **Learning Curve** | Steeper (organizational concepts) | Moderate | Moderate | Steep (graph concepts) | Moderate |
| **Maturity** | Very new (March 2026) | Established | Established (Microsoft) | Established (LangChain) | New |
| **Stars** | 41.5k | ~45.9k | ~37k+ | ~12k+ | ~30k+ |

### Key Differentiators

**Paperclip vs. CrewAI:** CrewAI requires Python code for agent definitions and focuses on building agent pipelines. Paperclip abstracts organizational structure into visual/declarative constructs and manages agents rather than defining them. They could be used together -- CrewAI agents managed by Paperclip.

**Paperclip vs. AutoGen:** AutoGen excels at research-grade conversational agent patterns with deep customization. Paperclip prioritizes practical organizational automation. AutoGen is backed by Microsoft and has more ecosystem maturity.

**Paperclip vs. LangGraph:** LangGraph is a lower-level framework for building complex agent workflows as state machines. Paperclip operates at a higher abstraction -- managing multiple agents/workflows rather than defining individual ones.

**Paperclip + OpenClaw:** These are explicitly designed as complements. OpenClaw provides deep individual agent autonomy (persistent identity, memory, self-directed operation). Paperclip wraps multiple OpenClaw agents (or any agents) into an organizational structure with governance and budgets.

---

## 10. Suitability for Running an Organisation

### Can Paperclip realistically be used as a base for an AI system that manages/runs an entire organisation?

**Short answer:** It is the most purpose-built open-source tool for this exact use case, but with important caveats.

### Strengths for This Purpose

1. **Designed exactly for this** -- unlike all alternatives, Paperclip was built from the ground up to model companies with org charts, budgets, governance, and accountability. This is not a retrofitted feature -- it is the core purpose.

2. **Correct abstraction layer** -- it sits above agent runtimes as a control plane, meaning you can use the best agent for each role (Claude for strategy, Codex for coding, HTTP webhooks for external services).

3. **Financial governance** -- per-agent budgets with auto-pause prevent runaway costs, which is critical for any real organizational deployment.

4. **Human oversight built in** -- board authority, approval gates, and audit trails mean humans retain control over strategic decisions, hiring, and high-risk operations.

5. **Goal alignment** -- the initiative -> project -> milestone -> issue hierarchy ensures all work traces back to organizational objectives, preventing agent drift.

6. **Multi-company isolation** -- can manage multiple autonomous divisions or business units from a single instance.

7. **Template system** -- 16 pre-built company templates accelerate deployment of common organizational patterns.

8. **Plugin extensibility** -- the comprehensive plugin system means you can add integrations (CRM, ticketing, communication tools) without forking the core.

### Realistic Limitations for This Purpose

1. **29 days old** -- this is a very young project. Production-critical organizational management requires battle-tested software. Early adopters should expect breaking changes and bugs.

2. **Human governance still essential** -- even the project's own advocates acknowledge that "even in a 'zero-human company,' there is always a human setting strategy, reviewing outcomes, and making judgment calls." Paperclip facilitates this correctly by keeping humans as the board.

3. **Error compounding** -- multi-agent pipelines amplify mistakes. Running an entire organization this way requires extensive monitoring and human checkpoints at critical decision points.

4. **Missing enterprise features** -- no multi-user RBAC, no native integrations with enterprise tools (Jira, Linear, Slack are roadmap items), no managed hosting option.

5. **Scope of "organization"** -- Paperclip manages agent coordination, not physical operations. It cannot manage physical inventory, handle phone calls, process payments, or interact with the physical world directly. It manages the digital knowledge work layer.

6. **No self-healing** -- when things go wrong, humans must intervene. There is no automatic recovery or reassignment.

### Practical Recommendation

Paperclip is **the best available foundation** for building an AI-managed organization, but it should be adopted with these principles:

- **Start small**: Begin with 3-5 agents in well-defined roles, not 50 agents on day one
- **Human-in-the-loop**: Use board governance aggressively -- approve strategies, review outputs, maintain checkpoints
- **Incremental automation**: Prove each workflow before removing human oversight from it
- **Complement with agent frameworks**: Use Paperclip for orchestration but pair it with strong individual agents (OpenClaw for autonomy, Claude for reasoning, Codex for coding)
- **Plan for immaturity**: Pin versions, maintain backups, expect API changes, and have fallback plans
- **Budget conservatively**: Use the financial controls -- they exist for good reason

The project's trajectory (41.5k stars in 29 days, active daily development, comprehensive specification, strong plugin architecture) suggests it will mature rapidly. For anyone planning to build an AI-managed organization in 2026, Paperclip is the clear starting point -- not because it is production-ready today, but because it is the only open-source project that has correctly identified and architected for this exact problem space.

---

## Sources

- [Paperclip GitHub Repository](https://github.com/paperclipai/paperclip)
- [Paperclip Official Website](https://paperclip.ing/)
- [Paperclip Review 2026 -- AI Agent Teams as Companies (VibeCoding)](https://vibecoding.app/blog/paperclip-review)
- [The 4th Path: Paperclip AI Review](https://www.the4thpath.com/2026/03/paperclip-ai-review-if-agents-are.html)
- [OpenClaw vs Paperclip Comparison (Flowtivity)](https://flowtivity.ai/blog/openclaw-vs-paperclip-ai-agent-framework-comparison/)
- [Zero-Human Companies Are Here (Flowtivity)](https://flowtivity.ai/blog/zero-human-company-paperclip-ai-agent-orchestration/)
- [Paperclip: Open-Source Orchestration for Zero-Human Companies (Jimmy Song)](https://jimmysong.io/ai/paperclip/)
- [Deploy Paperclip AI Agent Orchestration (Zeabur)](https://zeabur.com/blogs/deploy-paperclip-ai-agent-orchestration)
- [Paperclip Releases](https://github.com/paperclipai/paperclip/releases)
- [Paperclip API Documentation](https://github.com/paperclipai/paperclip/blob/master/docs/api/overview.md)
- [Paperclip Architecture Documentation](https://github.com/paperclipai/paperclip/blob/master/docs/start/architecture.md)
- [Paperclip Core Concepts](https://github.com/paperclipai/paperclip/blob/master/docs/start/core-concepts.md)
- [Paperclip Plugin Specification](https://github.com/paperclipai/paperclip/blob/master/doc/plugins/PLUGIN_SPEC.md)
- [Paperclip System Specification](https://github.com/paperclipai/paperclip/blob/master/doc/SPEC.md)
