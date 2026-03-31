# OpenClaw — Comprehensive Research Report

**Date:** 2026-03-31
**Repository:** https://github.com/openclaw/openclaw
**License:** MIT
**Stars:** ~247,000 (as of March 2026)

---

## 1. What is OpenClaw?

**OpenClaw** is a free, open-source (MIT-licensed), autonomous AI agent framework created by Austrian developer **Peter Steinberger**. First released November 24, 2025 as "Clawdbot," it was renamed to "Moltbot" (Jan 27, 2026) after Anthropic trademark complaints, then to "OpenClaw" three days later. Written in TypeScript and Swift, it has ~247,000 GitHub stars as of early March 2026, making it one of the fastest-growing open-source projects ever.

It is a **personal AI assistant you run on your own hardware** (Mac mini, VPS, Raspberry Pi) that connects to 23+ messaging platforms (WhatsApp, Telegram, Slack, Discord, Signal, iMessage, etc.) and uses LLMs (Claude, GPT, DeepSeek, or local models via Ollama) to autonomously execute tasks. Its key differentiators are: local-first (all data as Markdown on disk), model-agnostic, channel-agnostic, and community-extensible (5,700+ skills on ClawHub).

---

## 2. Architecture — Five Core Components

### Gateway
- WebSocket RPC server (port 18789) that routes messages from channels
- Manages sessions, handles auth, and orchestrates agents
- Runs as a persistent daemon

### Brain
- The LLM reasoning engine using the **ReAct loop** (Reason -> Act with tool -> Observe result -> Repeat)
- Five-step pipeline: Orchestrate, Resolve Model, Build Prompt, Guard Context, Act & Repeat

### Hands
- Execution tools: shell commands, filesystem ops, browser automation (CDP-based), HTTP calls, media processing
- Has same permissions as the host user

### Memory
- Persistent Markdown-based memory on disk
- Daily logs, long-term curated memory
- Optional vector search via `qmd` sidecar

### Heartbeat
- Periodic prompt (default 30min) for proactive autonomous behavior

The agent runtime is called the **Pi agent**, operating in RPC mode with tool streaming, block streaming, model failover, configurable thinking levels, and automatic session compaction.

---

## 3. Memory/Persistence System

OpenClaw separates **Context** (temporary, token-window) from **Memory** (persistent, on disk):

### Daily logs
- `memory/YYYY-MM-DD.md` — one file per day
- Loads today + yesterday on session start

### Long-term memory
- `MEMORY.md` — curated important knowledge
- Loaded in private sessions

### Sessions
- Stored as JSONL transcripts in `sessions/*.jsonl`

### Vector search (optional)
- Hybrid vector + full-text via built-in `qmd` service
- Pluggable backends (Pinecone, Weaviate)

### Compaction
- When token limits approach, the agent compacts context and flushes important info to memory files

### Git backup
- Strongly recommended for workspace as "private memory"

---

## 4. Autonomy: Task Planning, Goal-Setting, Self-Reflection

### Heartbeat system
- `HEARTBEAT.md` is a natural-language checklist the agent reads every 30 minutes
- Unlike rigid cron, the agent interprets tasks intelligently, makes judgment calls, and acts autonomously
- If nothing needs attention, it replies `HEARTBEAT_OK` (suppressed)

### Cron system
- For precise scheduling
- Two modes: main session (injects events into active conversation) and isolated (separate session with dedicated model settings)
- All cron executions create auditable task records

### Self-reflection
- The agent can modify its own `SOUL.md` (with the rule: "tell the user if you change it")
- Session compaction forces summarization
- The ReAct loop enables multi-step reasoning and task decomposition

---

## 5. Agent Identity/Role Definition — Three-Layer System

### SOUL.md — Behavioral Philosophy
- "Who the agent is"
- Personality, tone, boundaries
- Injected into every system prompt
- Functions as a "behavioral manifesto"

### IDENTITY.md — External Presentation
- Name, emoji, vibe, avatar
- Affects message prefixes and reactions

### AGENTS.md — Operating Instructions
- Rules, priorities, behavioral guidelines
- Loaded every session

### USER.md — User Context
- Who the user is, how to address them

### Identity Resolution
- Cascade: global config > per-agent config > workspace file > default fallback
- Multi-agent setups give each agent isolated identity, workspace, and memory

---

## 6. Tools/Capabilities

### Built-in tool categories:
- **Bash** — exec, process management
- **Filesystem** — read, write, edit
- **Web** — search, fetch
- **Browser** — CDP automation (Chrome DevTools Protocol)
- **Media** — image/audio/video processing
- **Canvas** — visual workspace
- **Node** — camera, screen, location, notifications
- **Cron** — scheduling
- **Inter-agent** — sessions_list/history/send

### Tool Policies
- Filtered through `ToolPolicyConfig` with profiles (minimal, coding, full)
- Can restrict which tools each agent has access to

### Skills Extension System
- Markdown files (SKILL.md) with YAML frontmatter
- No SDK needed — just markdown
- 5,700+ community skills on ClawHub
- Loading hierarchy: workspace > project > personal > managed > bundled > extra dirs > plugins

---

## 7. Workspace/File Management

### Workspace Location
`~/.openclaw/workspace/`

### Workspace Contents
```
~/.openclaw/workspace/
├── AGENTS.md              # Operating instructions
├── SOUL.md                # Behavioral identity
├── IDENTITY.md            # External presentation
├── USER.md                # User context
├── HEARTBEAT.md           # Periodic task checklist
├── MEMORY.md              # Curated persistent knowledge
├── BOOT.md                # Boot sequence instructions
├── BOOTSTRAP.md           # Initial setup instructions
├── TOOLS.md               # Tool configuration
├── memory/                # Daily activity logs
│   └── YYYY-MM-DD.md
├── skills/                # Agent-specific skills
└── canvas/                # Visual workspace
```

### Configuration & Credentials
```
~/.openclaw/
├── openclaw.json          # Main config: model providers, gateway, heartbeat, skills, tool policies
└── credentials/           # API keys and secrets
```

---

## 8. Key Configuration

### Main config file: `~/.openclaw/openclaw.json`
- Model providers
- Gateway settings
- Heartbeat interval and behavior
- Skills configuration
- Tool policies
- DM policy
- Sandbox settings

### Installation
```bash
npm install -g openclaw@latest && openclaw onboard --install-daemon
# Requires Node 22.16+
```

### CLI Tools
```bash
openclaw onboard           # Initial setup
openclaw doctor            # Health check
openclaw skills install    # Install skills from ClawHub
openclaw cron add          # Add scheduled tasks
openclaw tasks             # View tasks
```

---

## 9. Multi-Agent Support

- Multi-agent setups give each agent isolated identity, workspace, and memory
- Agents can communicate via sessions_list/history/send tools
- Each agent has its own SOUL.md, IDENTITY.md, AGENTS.md
- Routing between agents via the Gateway

---

## 10. Security Considerations

- Prompt injection vulnerability documented
- Cisco found skills performing data exfiltration
- The "MoltMatch incident" — agent autonomously created a dating profile using someone else's photos
- China restricted government use in March 2026
- A maintainer warned: "if you can't understand how to run a command line, this is far too dangerous for you to use safely"
- Sandbox mode available but not default

---

## 11. Why OpenClaw Matters for OrgAgent

OpenClaw's architecture provides the **blueprint for individual agent capabilities** in OrgAgent:

| OpenClaw Feature | OrgAgent Equivalent |
|-----------------|---------------------|
| SOUL.md | `org/agents/{name}/SOUL.md` — behavioral identity |
| IDENTITY.md | `org/agents/{name}/IDENTITY.md` — role, status, reporting |
| AGENTS.md | `org/agents/{name}/INSTRUCTIONS.md` — operating manual |
| HEARTBEAT.md | `org/agents/{name}/HEARTBEAT.md` — periodic checklist |
| MEMORY.md | `org/agents/{name}/MEMORY.md` — persistent knowledge |
| memory/*.md | `org/agents/{name}/memory/YYYY-MM-DD.md` — daily logs |
| Skills | `.claude/skills/` — shared + agent-specific skills |
| Tool policies | `.claude/agents/*.md` frontmatter `tools:` field |
| ReAct loop | Claude Code's native agent execution model |
| Heartbeat cycle | `scripts/cli/heartbeat.sh` — scheduled org cycles |
| Gateway routing | Filesystem-based message routing (inbox/outbox) |

**Key difference:** OpenClaw is a single-agent framework. OrgAgent wraps multiple agents into an organisational structure with hierarchy, governance, and delegation — using Paperclip's org-layer concepts implemented natively in Claude Code.

---

## Sources

- [GitHub - openclaw/openclaw](https://github.com/openclaw/openclaw)
- [OpenClaw Wikipedia](https://en.wikipedia.org/wiki/OpenClaw)
- [OpenClaw Docs - Agent Workspace](https://docs.openclaw.ai/concepts/agent-workspace)
- [OpenClaw Docs - Skills](https://docs.openclaw.ai/tools/skills)
- [OpenClaw Docs - Cron vs Heartbeat](https://docs.openclaw.ai/automation/cron-vs-heartbeat)
- [ClawDocs Core Concepts](https://clawdocs.org/getting-started/core-concepts/)
- [DeepWiki Architecture Deep Dive](https://deepwiki.com/openclaw/openclaw/15.1-architecture-deep-dive)
- [MMNTM - OpenClaw Identity Architecture](https://www.mmntm.net/articles/openclaw-identity-architecture)
- [OpenClaw Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)
- [Milvus Blog - Complete Guide](https://milvus.io/blog/openclaw-formerly-clawdbot-moltbot-explained-a-complete-guide-to-the-autonomous-ai-agent.md)
- [KDnuggets - OpenClaw Explained](https://www.kdnuggets.com/openclaw-explained-the-free-ai-agent-tool-going-viral-already-in-2026)
- [ClawHub Skill Format Spec](https://github.com/openclaw/clawhub/blob/main/docs/skill-format.md)
