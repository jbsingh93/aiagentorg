# GAP-04: Long-Running Processes — Sidecar Process Model

**Date:** 2026-04-02
**Status:** Research complete, ready for implementation
**Priority:** HIGH — Enables real-time event response, the foundation for a living organisation
**Dependencies:** GUI server (exists), n8n MCP (connected), Claude Code Channels (research preview)
**Estimated Effort:** Phase 1: 2-4 hours, Phase 2: 4-8 hours, Phase 3: 8-16 hours

---

## 1. The Problem

OrgAgent operates in **burst mode**: heartbeat fires, agents process work, everything stops. There are NO persistent background processes. This creates three critical limitations:

1. **Latency:** External events (new orders, payment notifications, support emails) must wait for the next heartbeat cycle. With `/loop 30m`, that's an average 15-minute delay. Real companies respond in seconds.

2. **No Event Reception:** The org cannot receive webhooks from external services (Shopify, Stripe, GitHub, etc.) because nothing is listening when the heartbeat isn't running.

3. **No Persistent Monitoring:** Agents can build connectors, webhook receivers, and file watchers during their invocation, but these processes die when the agent session ends.

### Current State

- Heartbeat runs phases: Alignment Board → CEO → Managers → Workers → CAO
- Each agent is a `claude --agent <name>` invocation (stateless, terminates after work)
- Ralph Wiggum pattern keeps cycling until quiescent, but still batch-oriented
- The spec (TO-DO/21-AUTONOMY-AND-DYNAMIC-CAPABILITIES.md) acknowledges 4 approaches: n8n workflows, Express.js extension, standalone webhook server, polling script — but NONE are built
- GUI already runs Express + WebSocket + chokidar at localhost:3000
- n8n MCP server is connected and healthy (instance ID: `49c092ac-da00-407b-b9c4-ded3b0b4a810`)

---

## 2. Research Findings

### 2.1 Claude Code Channels (The Game-Changer)

**Source:** [Channels reference — Claude Code Docs](https://code.claude.com/docs/en/channels-reference)

Claude Code Channels, launched March 20, 2026 as a research preview (v2.1.80+), are MCP servers that **push events INTO a running Claude Code session**. This inverts the traditional model where Claude pulls data — channels enable external systems to proactively notify Claude.

**How It Works:**

1. A channel is an MCP server spawned as a subprocess by Claude Code, communicating over stdio
2. The server declares `claude/channel` capability in its MCP constructor
3. External events (webhooks, file changes, monitoring alerts) arrive at the channel server
4. The server emits `notifications/claude/channel` to push event data into Claude's context
5. Claude receives the event as a `<channel source="name" ...>content</channel>` tag and acts autonomously

**Architecture:**

```
External Service (Shopify, Stripe, GitHub)
    |
    | HTTP POST (webhook)
    v
Hookdeck CLI / ngrok / direct
    |
    | localhost forward
    v
Channel Server (webhook.ts, Bun/Node.js, port 8788)
    |
    | MCP notification (stdio)
    v
Claude Code Session
    |
    | Reads <channel> tag, acts autonomously
    v
Writes to org/ filesystem (inbox, threads, tasks)
```

**Key Implementation Details:**

The channel server is a single TypeScript file:

```typescript
const mcp = new Server(
  { name: 'webhook', version: '0.0.1' },
  {
    capabilities: { experimental: { 'claude/channel': {} } },
    instructions: 'Events arrive as <channel source="webhook" ...>. Act on them.',
  }
);

// Push events:
await mcp.notification({
  method: 'notifications/claude/channel',
  params: {
    content: body,
    meta: { path: url.pathname, method: req.method },
  },
});
```

**Two-Way Communication:** Channels can expose reply tools via standard MCP tool registration, enabling Claude to respond back through the channel (e.g., reply to a Telegram message, acknowledge a webhook).

**Permission Relay:** Two-way channels can opt into permission relay (`claude/channel/permission` capability), allowing remote approval/denial of tool-use prompts from Telegram, Discord, or custom interfaces. The board could approve agent actions from a phone.

**Limitations:**
- Research preview only — requires `--dangerously-load-development-channels` flag
- Requires active Claude Code session — events only arrive when the session is open
- `claude.ai` login required — Console/API key auth not supported
- Team/Enterprise needs admin enablement via `channelsEnabled` managed setting
- No approved custom allowlist yet — custom channels must use the development flag

**Sources:**
- [Channels reference — Claude Code Docs](https://code.claude.com/docs/en/channels-reference)
- [How to Connect External Webhooks to Claude Code Using Channels and Hookdeck CLI](https://hookdeck.com/webhooks/platforms/claude-code-channels-webhooks-hookdeck)
- [What are Claude Code channels?](https://www.atcyrus.com/stories/what-are-claude-code-channels)
- [Claude Code Channels: Telegram, Discord & iMessage](https://claudefa.st/blog/guide/development/claude-code-channels)

### 2.2 Claude Code Hooks — Lifecycle Integration

**Source:** [Automate workflows with hooks — Claude Code Docs](https://code.claude.com/docs/en/hooks-guide)

Claude Code hooks (21 lifecycle events, 4 handler types) are user-defined commands that execute at specific points in Claude Code's lifecycle.

**Relevant Hook Events for Sidecar Integration:**

| Event | Use for OrgAgent |
|-------|-----------------|
| `SessionStart` | Initialize sidecar processes when org starts |
| `PostToolUse` (Write/Edit) | Already used for activity logging and state reminders |
| `Stop` | Already used for state/communication enforcement |
| `FileChanged` | Watch for specific file changes (e.g., new inbox notifications) |
| `Notification` | React when Claude Code sends notifications |
| `SubagentStart/Stop` | Log agent lifecycle (already implemented) |

**HTTP Hooks:** Can POST event data to HTTP endpoints:
```json
{
  "hooks": {
    "PostToolUse": [{
      "hooks": [{
        "type": "http",
        "url": "http://localhost:8080/hooks/tool-use",
        "headers": { "Authorization": "Bearer $MY_TOKEN" }
      }]
    }]
  }
}
```

**FileChanged Hook:** Watches for specific file changes:
```json
{
  "hooks": {
    "FileChanged": [{
      "matcher": ".envrc|.env",
      "hooks": [{
        "type": "command",
        "command": "direnv export bash >> \"$CLAUDE_ENV_FILE\""
      }]
    }]
  }
}
```

**Limitations:** Hooks are reactive to Claude Code lifecycle events, not external events. They cannot directly receive inbound webhooks (unlike Channels). `FileChanged` watches for specific filenames, not directories.

### 2.3 GUI Server Extension (Express.js Webhook Receiver)

**Current Architecture Analysis:**

The existing GUI server at `gui/server.js` already provides:
- **Express 5** HTTP server on port 3000
- **WebSocket** for real-time push to dashboard clients
- **chokidar** file watcher monitoring all of `org/` with categorized events
- **9 API route modules** (orgchart, agents, agent, tasks, messages, budget, audit, approvals, chat)
- **Live activity feed** broadcasting to connected clients
- **Agent status tracking** via current-state.md monitoring

The server already has the complete infrastructure for receiving, routing, and broadcasting events. It watches `org/` for changes and categorizes them (threads, tasks, activity, messages, approvals, etc.).

**Extension Approach:**

Adding a webhook receiver requires ONE new API module and ONE line in server.js:

```javascript
// gui/api/webhooks.js — new API module
module.exports = function (router, orgDir) {
  router.post('/webhooks/:service/:event', (req, res) => {
    const { service, event } = req.params;
    const payload = req.body;
    const timestamp = new Date().toISOString();
    const filename = `${service}-${event}-${Date.now()}.md`;
    
    // Determine target agent from connector registry
    const targetAgent = lookupAgentForService(orgDir, service);
    
    // Write event file to agent inbox
    const inboxPath = path.join(orgDir, 'agents', targetAgent, 'inbox', filename);
    const content = `---
type: external-event
source: ${service}
event: ${event}
timestamp: ${timestamp}
urgency: ${payload.urgency || 'normal'}
read: false
---

${JSON.stringify(payload, null, 2)}
`;
    fs.writeFileSync(inboxPath, content);
    
    // chokidar automatically detects the new file and broadcasts via WebSocket
    res.status(200).json({ received: true, agent: targetAgent });
  });
};
```

Then add one line to `server.js`:
```javascript
require('./api/webhooks')(apiRouter, orgDir);
```

**Why this works immediately:** The GUI server's chokidar watcher already monitors the entire `org/` directory. When a webhook handler writes an event file to `org/agents/{name}/inbox/`, the watcher automatically:
1. Detects the new file
2. Categorizes it as 'messages'
3. Broadcasts a WebSocket event to all dashboard clients
4. The dashboard updates in real-time

The event pipeline from "webhook received" to "dashboard updated" already exists — you only need the inbound endpoint.

**Sources:**
- [Webhook Example with NodeJS and Express](https://softwareengineeringstandard.com/2025/08/26/webhook-example/)
- [Building a Webhook Listener with Node.js](https://dev.to/lucasbrdt268/building-a-webhook-listener-with-nodejs-step-by-step-guide-3ai5)
- [Express.js Dynamic Runtime Routing](https://alexanderzeitler.com/articles/expressjs-dynamic-runtime-routing/)

### 2.4 n8n as Sidecar Workflow Engine

**Current Status:** The n8n MCP server is **already connected and functional**. Health check confirms:
```json
{
  "status": "ok",
  "message": "n8n API is configured and accessible",
  "instanceId": "49c092ac-da00-407b-b9c4-ded3b0b4a810"
}
```

**Available MCP Tools (Already Accessible to Claude Code):**

| Tool | Purpose |
|------|---------|
| `n8n_create_workflow` | Create workflows programmatically |
| `n8n_generate_workflow` | Natural language to workflow (3-step flow) |
| `n8n_update_partial_workflow` | Incremental workflow modifications |
| `n8n_test_workflow` | Trigger webhook/form/chat workflows |
| `n8n_list_workflows` | List existing workflows |
| `n8n_get_workflow` | Get workflow details |
| `n8n_deploy_template` | Deploy from 2,700+ templates |
| `n8n_autofix_workflow` | Auto-fix common issues |
| `n8n_validate_workflow` | Validate before deploy |
| `search_nodes` | Search 1,396 automation nodes (812 core + 584 community) |
| `search_templates` | Search 2,700+ templates |

**Key n8n Nodes for OrgAgent:**
- **Webhook** (`nodes-base.webhook`): Starts workflow when webhook is called
- **MCP Server Trigger** (`nodes-langchain.mcpTrigger`): Expose n8n tools as MCP endpoint
- **MCP Client Tool** (`nodes-langchain.mcpClientTool`): Connect to external MCP servers
- **Execute Command** (`nodes-base.executeCommand`): Run shell commands on host
- **Local File Trigger** (`nodes-base.localfiletrigger`): Watch filesystem for changes
- **SSH** (`nodes-base.ssh`): Execute remote commands

**Architecture: n8n as Event Bridge:**

```
External Service (Shopify, Stripe, Gmail)
    |
    | Webhook / API polling
    v
n8n Workflow (always-on, running in Docker/host)
    |
    ├─> Write event file to org/agents/{name}/inbox/
    ├─> Execute Command: claude --agent <name> -p "Event: ..."
    ├─> HTTP Request: POST to GUI server webhook endpoint
    └─> Write to org/threads/ for agent communication
```

**Bidirectional Integration:** n8n supports MCP on both sides:
- **As MCP Server**: Expose workflows as tools for Claude Code to call
- **As MCP Client**: n8n workflows can call external MCP servers

**Practical Pattern:**
1. Agent builds n8n workflow using MCP tools (agents can create workflows via natural language)
2. n8n receives webhooks from external services
3. n8n writes event files to `org/agents/{name}/inbox/` or `org/connectors/{service}/events/`
4. n8n optionally triggers `claude --agent <name>` for urgent events via Execute Command node
5. chokidar watcher in GUI server detects new files and pushes WebSocket updates
6. Next heartbeat cycle processes non-urgent events normally

**Windows Docker Considerations:** Local File Trigger has reported issues with mounted Windows directories. Workaround: use n8n's HTTP Request node to POST to the GUI server instead of direct filesystem writes.

**Sources:**
- [n8n MCP Server Documentation](https://docs.n8n.io/advanced-ai/accessing-n8n-mcp-server/)
- [n8n-MCP GitHub (czlonkowski)](https://github.com/czlonkowski/n8n-mcp)
- [n8n + Claude Code via MCP: Real Production Guide (2026)](https://medium.com/@rentierdigital/one-open-source-repo-turned-claude-code-into-an-n8n-architect-and-n8n-has-never-been-more-useful-f68f4ec63d02)
- [n8n as Agentic MCP Hub](https://www.infralovers.com/blog/2026-03-09-n8n-agentic-mcp-hub/)
- [n8n Docker Installation](https://docs.n8n.io/hosting/installation/docker/)

### 2.5 PM2 Process Management

PM2 is the most widely used Node.js process manager with 100M+ downloads. It could manage all sidecar processes as a unified fleet:

```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'orgagent-dashboard',
      script: './gui/server.js',
      watch: false,
      instances: 1,
    },
    {
      name: 'orgagent-webhook',
      script: './sidecar/webhook-server.js',
      watch: false,
      instances: 1,
    },
    {
      name: 'orgagent-file-watcher',
      script: './sidecar/file-watcher.js',
      watch: false,
      instances: 1,
    }
  ]
};
```

**Key PM2 Features:**
- Auto-restart on crash: `max_restarts: 10`, `min_uptime: '5s'`
- System startup: `pm2 startup` generates OS-specific startup script
- Ecosystem file: Declarative configuration for multiple processes
- Log management: Built-in log rotation
- Monitoring: `pm2 monit` for real-time dashboard

**Windows Support Caveats:** `pm2 startup` may not work natively on Windows 11. Alternative: **NSSM (Non-Sucking Service Manager)** for running PM2 as a Windows service. Modern approach uses PowerShell 7 script for service management.

**Sources:**
- [PM2 Home](https://pm2.io/)
- [PM2 Process Management Guide (2026)](https://oneuptime.com/blog/post/2026-01-22-nodejs-pm2-process-management/view)
- [PM2 as Windows Service](https://medium.com/@gzthomasliang/run-pm2-as-service-on-windows-server-in-modern-way-286b9f4b8228)

### 2.6 Event-Driven AI Agent Patterns (SOTA 2025-2026)

The 2025-2026 industry consensus is clear: **the future of AI agents is event-driven.** More than 72% of enterprises already rely on event-driven architecture. Webhook-driven workflows reduce latency by 90% compared to polling.

**Key Patterns Validated by Research:**

**A) Filesystem-as-Message-Bus Pattern:** A notable 2026 approach uses the filesystem itself as an event bus — JSON/Markdown files store tasks and events, file watchers detect new files and trigger agent processing. This is **exactly what OrgAgent already does** with `org/threads/` and `org/agents/*/inbox/`.

**B) Listen-Understand-Act Pattern (Moveworks):** Ambient agent architecture follows three steps: Listen (detect triggers), Understand (LLM reasoning), Act (execute with optional human approvals). Maps directly to OrgAgent's: Webhook received → Agent processes event → Board approves if needed.

**C) IDE Agent Kit Pattern:** Webhook Relay → normalized JSONL queue → IDE agent reads and acts → receipt written. Append-only receipts document every action. Trace IDs + idempotency keys prevent duplicate processing.

**Sources:**
- [Event-Driven AI Agent Architecture Guide (2026)](https://fast.io/resources/ai-agent-event-driven-architecture/)
- [The Future of AI Agents is Event-Driven](https://seanfalconer.medium.com/the-future-of-ai-agents-is-event-driven-9e25124060d6)
- [Ambient Agent Webhook Triggers (Moveworks)](https://www.moveworks.com/us/en/resources/blog/webhooks-triggers-for-ambient-agents)
- [CrewAI Flows](https://docs.crewai.com/en/concepts/flows)
- [IDE Agent Kit](https://github.com/ThinkOffApp/ide-agent-kit)

### 2.7 Claude Code Background Processes

Claude Code (v1.0.71+) supports running bash commands in the background:
- `run_in_background: true` parameter in Bash tool calls
- Press Ctrl+B to push a foreground process to the background
- Background tasks persist across Claude Code sessions
- Claude monitors output in real-time, spotting errors and offering fixes

The GUI server can be started via `run_in_background` and persist across the session. Webhook receiver servers can similarly be backgrounded.

**Clautel** wraps Claude Code as a proper background daemon via Telegram bridge — runs as a system service with session resumption across disconnections.

**Sources:**
- [What are Background Commands in Claude Code](https://claudelog.com/faqs/what-are-background-commands/)
- [Run Claude Code as Background Daemon (Clautel)](https://www.clautel.com/blog/how-to-run-claude-code-as-a-background-daemon)

---

## 3. Recommended Architecture — Layered Sidecar Model

Based on all research, the recommended approach is a **four-layer architecture** where each layer adds capability on top of the previous one:

### Layer 1: GUI Server Extension (Immediate, Low Effort)

**What:** Extend `gui/server.js` with a `/api/webhooks/:service/:event` endpoint.

**Why:** Requires adding ONE new API module file and ONE line in server.js. The existing chokidar + WebSocket infrastructure handles everything else.

**What it gives you:** Any external service that can send webhooks can write event files to agent inboxes. The dashboard shows events in real-time. The next heartbeat cycle processes them.

**New files:**
- `gui/api/webhooks.js` — Webhook receiver API module

**Modified files:**
- `gui/server.js` — Add `require('./api/webhooks')(apiRouter, orgDir);`

### Layer 2: n8n Workflow Sidecar (Medium Effort, High Value)

**What:** Use the already-connected n8n MCP server to let agents programmatically create webhook receiver workflows.

**Why:** n8n is already connected. Agents can create workflows via `n8n_create_workflow` or `n8n_generate_workflow`. n8n handles retry logic, error handling, and credential management. 1,396 integration nodes cover virtually any service.

**What it gives you:** Robust, visual, persistent webhook processing. Agents can build integrations without writing raw webhook code.

**New files:**
- `org/connectors/n8n-bridge/README.md` — Documentation for n8n integration pattern
- Updates to `.claude/system-reference.md` — Section on using n8n MCP for event systems

### Layer 3: Claude Code Channels (Future, High Value)

**What:** Build an OrgAgent channel server that receives events from both the GUI webhook endpoint and n8n workflows, and pushes them directly into the board's Claude Code session.

**Why:** True real-time event response in the board's session. Remote approval capability via permission relay. Direct integration with Claude Code's lifecycle.

**What it gives you:** Sub-second event response in the active session. Remote board approvals via Telegram/Discord.

**New files:**
- `sidecar/webhook-channel.ts` — Channel server for Claude Code Channels
- `.claude/mcp.json` update — Channel server registration

**Condition:** Wait for Channels to exit research preview, or use `--dangerously-load-development-channels` flag.

### Layer 4: PM2 Process Fleet (Optional, For Production)

**What:** Wrap all sidecar processes in a PM2 ecosystem for auto-restart, log management, and system startup.

**Why:** Production-grade process management. Processes survive terminal closure and system reboots.

**What it gives you:** Auto-restart, log rotation, monitoring, system startup scripts.

**New files:**
- `ecosystem.config.js` — PM2 ecosystem file
- `scripts/start-sidecar.sh` — Unified startup script

### Combined Event Flow

```
Shopify order → n8n webhook workflow → write to org/agents/sales/inbox/
                                     → POST to GUI /api/webhooks/shopify/order
                                     → GUI broadcasts WebSocket event
                                     → Dashboard shows event in real-time
                                     → chokidar detects new inbox file
                                     → If /run-org active: next cycle processes it
                                     → If Channels active: push to board session
                                     → For urgent: exec claude --agent sales -p "..."
```

---

## 4. Event File Format

When an event arrives from any source, the sidecar writes to `org/agents/{agent}/inbox/`:

```markdown
---
type: external-event
source: shopify
event: order-created
timestamp: 2026-04-01T10:05:00Z
urgency: high
read: false
idempotency_key: shopify-order-1042-20260401T100500
---

New order #1042 from john@example.com
Total: 349.00 DKK
Items: 2x "Wireless Headphones"

Raw webhook data: org/connectors/shopify/events/order-1042.json
```

**Critical: Idempotency Key.** Every event file includes a deterministic idempotency key derived from source + event type + unique identifier + timestamp. Before writing, the webhook handler checks if a file with that key already exists in the inbox. This prevents duplicate processing on webhook retries.

---

## 5. Connector Registry Integration

When an agent builds a connector for an external service (per TO-DO/21-AUTONOMY-AND-DYNAMIC-CAPABILITIES.md), it registers the webhook endpoint in `org/connectors/registry.md`:

```markdown
## shopify

- **Status:** active
- **Type:** n8n-workflow
- **Workflow ID:** 42
- **Webhook URL:** https://n8n.example.com/webhook/shopify-orders
- **Local Endpoint:** /api/webhooks/shopify/order-created
- **Target Agent:** sales-manager
- **Events:** order-created, order-updated, order-cancelled
- **Credentials:** org/connectors/shopify/credentials.md
- **Built by:** devops-agent
- **Built on:** 2026-04-15
```

The webhook handler in `gui/api/webhooks.js` reads this registry to determine which agent should receive events from which service.

---

## 6. Triggering Agent Processing

When an urgent event arrives, the sidecar has three escalation paths:

1. **Normal (default):** Write event file to inbox. Next heartbeat cycle processes it. Average latency: half the heartbeat interval.

2. **Fast (if /run-org active):** The Ralph Wiggum Stop hook detects new unread notifications in `check_pending_work()` and triggers another heartbeat cycle immediately. Latency: seconds to minutes.

3. **Urgent (direct invocation):** The webhook handler invokes `claude --agent <name> -p "Urgent event: {summary}"` directly via `child_process.exec()`. Latency: seconds. Cost: one agent invocation.

The `urgency` field in the event file determines which path is used. The webhook handler checks the connector registry for urgency configuration per event type.

---

## 7. Architecture Decision Alignment

This approach aligns with existing OrgAgent decisions:

- **Decision 47** (Agent Picks Best Event Approach): Agents choose between n8n, Express, standalone, or polling based on situation
- **Decision 45** (Agents Build Their Own Integrations): The n8n MCP tools enable agents to dynamically create webhook workflows
- **Decision 50** (Agents Are Autonomous, Not Passive): Event-driven processing makes agents reactive, not just batch-processing

The filesystem-as-event-bus pattern that OrgAgent already uses (`org/threads/`, `org/agents/*/inbox/`) is validated by SOTA research as a legitimate architecture for multi-agent systems. The sidecar model simply adds inbound bridges to that filesystem bus from external systems.

---

## 8. Implementation Plan

### Phase 1: GUI Webhook Endpoint (2-4 hours)

1. Create `gui/api/webhooks.js` with parameterized route
2. Add route to `gui/server.js`
3. Add connector registry lookup function
4. Add idempotency key checking
5. Test with `curl -X POST http://localhost:3000/api/webhooks/test/ping -d '{}'`
6. Update system-reference.md with webhook documentation
7. Update connector registry format spec

### Phase 2: n8n Integration Pattern (4-8 hours)

1. Document the n8n workflow creation pattern for agents
2. Create a reference n8n workflow that receives webhooks and writes to org/
3. Create the `/build-connector` skill (or extend create-skill) that guides agents through:
   - Researching the service API
   - Creating an n8n workflow via MCP
   - Registering the connector
   - Testing the integration
4. Update CAO INSTRUCTIONS.md with DevOps/Integration team hiring guidance
5. Test end-to-end: n8n workflow → event file → dashboard update → heartbeat processing

### Phase 3: Claude Code Channel (8-16 hours, when Channels exits preview)

1. Build `sidecar/webhook-channel.ts` channel server
2. Configure channel registration in `.claude/mcp.json`
3. Add CLAUDE.md instructions for handling `<channel>` events
4. Implement permission relay for remote board approvals
5. Test with development flag
6. Monitor Channels GA timeline for production readiness

### Phase 4: PM2 Process Fleet (Optional, 2-4 hours)

1. Create `ecosystem.config.js`
2. Create `scripts/start-sidecar.sh`
3. Document Windows service setup (NSSM or PowerShell)
4. Add to `/onboard` skill: ask user if they want persistent sidecar processes

---

## 9. New Architecture Decisions

### Decision 53: Sidecar Event Reception via GUI Server Extension
**Decision:** Add webhook endpoint to existing GUI Express server as the primary event reception mechanism. No standalone webhook server needed initially.
**Reasoning:** Reuses existing infrastructure (Express, chokidar, WebSocket). Zero new dependencies. The GUI server is already running when the dashboard is active. Adding a webhook endpoint is a single-file, single-line change.

### Decision 54: n8n as Primary Integration Engine
**Decision:** Use the already-connected n8n MCP server as the primary mechanism for agents to build external service integrations. n8n handles webhook reception, retry logic, credential management, and event routing.
**Reasoning:** n8n is already connected, has 1,396 nodes covering virtually any service, agents can create workflows programmatically via MCP tools, and it runs as a persistent process independent of Claude Code sessions.

### Decision 55: Claude Code Channels for Real-Time Board Notification
**Decision:** Adopt Claude Code Channels (when GA) as the real-time event notification mechanism for the board's session. Build a channel server that aggregates events from the GUI webhook endpoint and n8n workflows.
**Reasoning:** Channels push events directly into the active Claude Code session, enabling sub-second response. Permission relay enables remote board approvals. This is the most architecturally aligned approach since the board IS a Claude Code session.

### Decision 56: Idempotency Keys on All Event Files
**Decision:** Every event file written to an agent's inbox includes a deterministic `idempotency_key` in frontmatter. The webhook handler checks for existing files with the same key before writing.
**Reasoning:** Webhooks retry on failure. Without idempotency, a single Shopify order could create 3 duplicate event files. The key is deterministic (source + event + ID + timestamp) so duplicates are always detected.

### Decision 57: Three-Tier Urgency for Event Processing
**Decision:** Events are classified into three urgency tiers: normal (wait for heartbeat), fast (Ralph Wiggum detects and cycles), urgent (direct agent invocation). Urgency is configurable per service per event type in the connector registry.
**Reasoning:** Not all events need immediate response. An order notification can wait 30 minutes. A payment failure needs immediate attention. Matching urgency to response path optimizes cost and latency.
