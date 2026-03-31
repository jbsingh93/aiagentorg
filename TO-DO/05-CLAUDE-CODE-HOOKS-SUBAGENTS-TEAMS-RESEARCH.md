# Claude Code Hooks, Subagents & Agent Teams — Exhaustive Deep-Dive

**Date:** 2026-03-31
**Source:** Claude Code documentation, web research, feature analysis

---

# PART 1: HOOKS

## 1.1 How Hooks Are Defined

Hooks are user-defined shell commands, HTTP endpoints, or LLM prompts that execute automatically at specific points in Claude Code's lifecycle.

### Settings.json Structure (three-level hierarchy):
```json
{
  "hooks": {
    "HookEventName": [
      {
        "matcher": "pattern",
        "if": "PermissionRuleSyntax",
        "hooks": [
          {
            "type": "command|http|prompt|agent",
            // ... type-specific fields
          }
        ]
      }
    ]
  }
}
```

### Configuration Scopes (by priority):
1. `~/.claude/settings.json` — Global (all projects)
2. `.claude/settings.json` — Project (shareable, checked in)
3. `.claude/settings.local.json` — Project (gitignored)
4. Managed policy settings (org-wide, admin-controlled)
5. Plugin `hooks/hooks.json`
6. Skill/agent frontmatter

---

## 1.2 All Hook Events (29 lifecycle points)

### Session Events
- `SessionStart` — When session begins or resumes (matcher: `startup`, `resume`, `clear`, `compact`)
- `SessionEnd` — When session terminates (matcher: `clear`, `resume`, `logout`, etc.)
- `InstructionsLoaded` — CLAUDE.md/rules files loaded

### Tool Events (Pre/Post)
- `PreToolUse` — Before tool executes (can **block**)
- `PostToolUse` — After tool succeeds
- `PostToolUseFailure` — After tool fails
- `PermissionRequest` — Permission dialog about to show (can **auto-approve/deny**)

### User & Task Events
- `UserPromptSubmit` — User submits prompt
- `TaskCreated` — Task created via Agent tool (can block)
- `TaskCompleted` — Task marked complete (can block)
- `Stop` — Claude finishes responding (can block continuation)
- `StopFailure` — Turn ends due to API error

### Agent & Team Events
- `SubagentStart` — Subagent spawned (matcher: agent type name)
- `SubagentStop` — Subagent finishes
- `TeammateIdle` — Agent team teammate about to idle (can block)

### Context & Configuration Events
- `ConfigChange` — Config file changes externally
- `CwdChanged` — Working directory changes
- `FileChanged` — Watched file changes on disk
- `PreCompact` — Before context compaction
- `PostCompact` — After context compaction

### Notification & Integration Events
- `Notification` — Claude needs user attention
- `Elicitation` — MCP server requests user input
- `ElicitationResult` — User responds to MCP elicitation

### Git & Environment Events
- `WorktreeCreate` — Worktree being created
- `WorktreeRemove` — Worktree being removed

---

## 1.3 Hook Types (4 variants)

### Command hooks (`type: "command"`)
```json
{
  "type": "command",
  "command": "script.sh",
  "async": false,
  "shell": "bash"
}
```
Receives JSON on stdin, returns exit code (0=allow, 2=block, other=warn).

### HTTP hooks (`type: "http"`)
```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks",
  "headers": {"Authorization": "Bearer $MY_TOKEN"},
  "allowedEnvVars": ["MY_TOKEN"]
}
```

### Prompt hooks (`type: "prompt"`)
```json
{
  "type": "prompt",
  "prompt": "Is this safe? $TOOL_NAME $ARGUMENTS",
  "model": "fast-model"
}
```

### Agent hooks (`type: "agent"`)
```json
{
  "type": "agent",
  "agent": "validator",
  "prompt": "Validate this: $TOOL_INPUT"
}
```

---

## 1.4 Hook Matchers

| Event | Matcher Filters On | Examples |
|-------|-------------------|----------|
| `PreToolUse`/`PostToolUse` | Tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart`/`SessionEnd` | Session source/reason | `startup`, `resume`, `clear` |
| `SubagentStart`/`SubagentStop` | Agent type name | `Explore`, `code-reviewer` |
| `Notification` | Notification type | `permission_prompt`, `idle_prompt` |
| `ConfigChange` | Config source | `user_settings`, `project_settings` |
| `FileChanged` | Filename | `.env`, `.envrc`, `package.json` |
| `StopFailure` | Error type | `rate_limit`, `billing_error` |

**Matcher Syntax:** Exact match (`"Bash"`), pipe alternation (`"Edit|Write"`), regex (`"mcp__.*"`), omit for match-all.

**Advanced `if` field:** Uses permission rule syntax for deeper filtering:
```json
{
  "matcher": "Bash",
  "if": "Bash(git *)",
  "hooks": [{"type": "command", "command": "./check-git.sh"}]
}
```

---

## 1.5 Blocking & Modifying Tool Calls

### Block: Exit code 2 from `PreToolUse` hook
```bash
#!/bin/bash
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command')
if [[ "$COMMAND" == "rm -rf"* ]]; then
  echo "Blocked: destructive command" >&2
  exit 2
fi
exit 0
```

### Modify: Return `updatedInput` in JSON
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "updatedInput": { "command": "safer-command" }
  }
}
```

### Permission Decision: Allow/deny/ask
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask",
    "permissionDecisionReason": "explanation"
  }
}
```

---

## 1.6 Hook Data Flow

### Input (all hooks receive):
```json
{
  "session_id": "abc123",
  "cwd": "/current/dir",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" }
}
```

### Output mechanisms:
- **Exit codes:** 0=allow, 2=block, other=warn
- **JSON stdout:** Structured decisions + reasons
- **Stderr (exit 2):** Feedback message to Claude
- **Environment variables:** Via `CLAUDE_ENV_FILE`
- **Context injection:** `SessionStart` stdout or `additionalContext`
- **Tool input modification:** `updatedInput` field

---

## 1.7 Hook Chaining

**Direct chaining:** NO. Hooks cannot invoke other hooks.
**Indirect chaining:** Limited YES — via file writes triggering `FileChanged`, config changes triggering `ConfigChange`.
**Multiple hooks on same event:** Run in parallel (not sequential).

---

# PART 2: SUBAGENTS (Agent Tool)

## 2.1 How Subagents Work

The Agent tool spawns a specialized subagent to handle a specific task. The main session delegates work and waits for results.

### Parameters:
```
Agent(
  agent_type: string,        # Name of subagent
  task_description: string,  # What to do
  model?: string,            # Override model
  isolation?: string         # "worktree" for isolated git copy
)
```

### Result Format:
```json
{
  "agent_id": "agent-12345",
  "status": "completed|failed|timeout",
  "summary": "What the subagent accomplished",
  "output": "Full results"
}
```

---

## 2.2 Available Subagent Types

### Built-in:
| Name | Model | Tools | Purpose |
|------|-------|-------|---------|
| **Explore** | Haiku (fast) | Read-only | Codebase search & analysis |
| **Plan** | Inherits | Read-only | Research for planning mode |
| **general-purpose** | Inherits | All tools | Complex multi-step tasks |
| **Bash** | Inherits | Tool-specific | Terminal commands |
| **statusline-setup** | Sonnet | All | Configure status line |
| **Claude Code Guide** | Haiku | Tool-specific | Answer Claude Code questions |

### Custom (you define):
- `.claude/agents/` (project scope)
- `~/.claude/agents/` (user scope)
- `--agents` JSON flag (session-only)
- Plugin `agents/` directory

### Priority (name conflicts):
1. `--agents` CLI flag (highest)
2. `.claude/agents/` (project)
3. `~/.claude/agents/` (user)
4. Plugin `agents/` (lowest)

---

## 2.3 Subagent Nesting

**Subagents CANNOT spawn other subagents.** No nesting beyond 1 level.

Workarounds:
1. Chain subagents from main conversation
2. Design parent to spawn multiple in parallel
3. Use agent teams for coordinated parallel work
4. Design subagent prompts for multi-step workflows internally

---

## 2.4 Background vs Foreground

| Mode | Blocking? | Permissions | Best For |
|------|-----------|-----------|----------|
| **Foreground** | Yes | Prompted real-time | Iterative work, debugging |
| **Background** | No | Pre-approved upfront | Research, testing, long-running |

Background: Claude Code prompts for all permissions upfront. Auto-denies anything not pre-approved. Ctrl+B to background a running task.

---

## 2.5 Sending Messages to Agents

```
SendMessage(
  to: "agent-abc123xyz",
  message: "Continue with new instruction"
)
```
Agent resumes with full history. Works with idle agents.

---

## 2.6 Isolation Model

### Default: No isolation
Subagents work in same directory, share files.

### Worktree isolation (`isolation: "worktree"`):
- Creates temporary git worktree copy
- Changes only affect the worktree
- Auto-cleanup if no changes made
- Must be manually pulled if changes exist

---

## 2.7 Subagent Configuration File Format

```yaml
---
name: code-reviewer
description: Expert code reviewer
tools: Read, Grep, Glob, Bash
disallowedTools: Write, Edit
model: sonnet
permissionMode: default
maxTurns: 20
skills: [code-style-guide, security-checklist]
memory: project
background: false
isolation: worktree
mcpServers:
  - slack
  - playwright:
      type: stdio
      command: npx
      args: ["-y", "@playwright/mcp@latest"]
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./validate.sh"
---

You are a code reviewer. Focus on quality and security.
```

---

## 2.8 Subagent Context Access

| Context Type | Access |
|-------------|--------|
| **Files** | Yes (unless worktree isolated) |
| **CLAUDE.md** | Yes (loaded at startup) |
| **Rules** | Yes (`.claude/rules/`) |
| **MCP servers** | Yes (unless scoped) |
| **Skills** | Only if explicitly listed in frontmatter |
| **Memory** | Only if enabled via `memory: user\|project\|local` |
| **Conversation history** | No (fresh context) |
| **Permissions** | Inherited from parent |
| **Environment variables** | Inherited |

---

## 2.9 Persistent Memory for Subagents

| Scope | Location |
|-------|----------|
| `user` | `~/.claude/agent-memory/<name>/` |
| `project` | `.claude/agent-memory/<name>/` |
| `local` | `.claude/agent-memory-local/<name>/` (gitignored) |

First 200 lines of MEMORY.md injected at startup. Topic files read on-demand.

---

# PART 3: AGENT TEAMS

## 3.1 What Are Agent Teams?

Agent teams coordinate multiple Claude Code instances working in parallel, with a lead session managing work and teammates executing independently.

**Status:** Experimental (requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)

### Architecture:
| Component | Role |
|-----------|------|
| **Team Lead** | Main session that creates, spawns, coordinates |
| **Teammates** | Separate Claude Code instances |
| **Task List** | Shared `.claude/tasks/{team-name}/` |
| **Mailbox** | Messaging between agents |
| **Team Config** | `~/.claude/teams/{team-name}/config.json` |

---

## 3.2 How Teams Work

1. You ask lead to create a team
2. Lead creates team config and task list
3. Lead spawns teammates (separate sessions)
4. Teammates load CLAUDE.md, MCP, skills + spawn prompt
5. Teammates claim tasks independently
6. Teammates work in parallel
7. Teammates message each other or lead
8. Lead synthesizes findings
9. Team cleanup on completion

---

## 3.3 Teams vs Subagents

| Aspect | Subagents | Agent Teams |
|--------|-----------|------------|
| **Scope** | Single session | Multiple sessions |
| **Context** | Own context, results return | Fully independent |
| **Communication** | Report to main only | Direct inter-teammate messaging |
| **Token Cost** | Lower | Higher (N x full context) |
| **Coordination** | Main manages all | Self-organize via task list |
| **Nesting** | Cannot spawn subagents | Cannot spawn teams |

---

## 3.4 Team Coordination

### Task States: Pending -> In Progress -> Completed

### Coordination Mechanisms:
1. **Shared task list** — all see same items
2. **Direct messaging** — teammate-to-teammate
3. **Broadcast** — message all (use sparingly)
4. **Idle notifications** — auto-notify lead when done

### Dependency Management:
- Tasks can depend on other tasks
- Blocked tasks auto-unblock when dependencies complete

---

## 3.5 Team Hierarchy

**Flat structure only.** No nested teams, no sub-leaders.

Workarounds:
1. Task dependencies for implicit hierarchy
2. Explicit sequential assignments
3. Multiple teams sequentially
4. Subagents within lead

---

## 3.6 Interrelationships

### Hooks + Subagents:
- `SubagentStart`/`SubagentStop` hooks fire on spawn/finish
- Subagents can define own hooks in frontmatter

### Hooks + Teams:
- `TeammateIdle` hook fires when teammate about to idle
- `TaskCreated`/`TaskCompleted` hooks can block
- Hooks run in lead only, not teammates

### Subagents + Teams:
- Teammates can reference subagent types
- Lead can spawn subagents while managing team
- Teammates cannot create sub-teams

### Context Isolation (most to least):
1. Agent Team Teammate (own session)
2. Subagent with worktree (temp git copy)
3. Subagent default (same directory, own context)
4. Skill (main context)
5. Hook (zero isolation, shell)

### Token Cost (high to low):
1. Agent Teams (N x full context)
2. Subagent with results (subagent + summary)
3. Skill (main conversation)
4. Hooks (minimal)
