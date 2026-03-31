# Claude Code Skills System — Exhaustive Deep-Dive

**Date:** 2026-03-31
**Source:** Claude Code documentation, web research, feature analysis

---

## Executive Summary

Claude Code skills are **reusable prompt-based knowledge modules** that extend Claude's capabilities. They're Markdown files with YAML frontmatter that can be invoked manually (via `/skill-name`) or automatically by Claude when relevant. Skills follow the Agent Skills open standard, extended with Claude Code-specific features like subagent execution, dynamic context injection, and invocation control.

---

## 1. How Skills Are Defined: Format & Structure

### File Format & Location

Every skill requires a `SKILL.md` file (Markdown with YAML frontmatter):

```
~/.claude/skills/my-skill/
├── SKILL.md           # Required: frontmatter + instructions
├── reference.md       # Optional: detailed docs
├── examples.md        # Optional: usage examples
└── scripts/
    └── helper.sh      # Optional: executable scripts
```

### Minimal Skill Example

```yaml
---
name: my-skill
description: What this skill does
---

Your markdown instructions here...
Claude reads and follows these instructions.
```

### Anatomy

**YAML Frontmatter** (between `---` markers):
- Configuration metadata about the skill
- Controls invocation behavior, tool access, context, etc.
- All fields optional except as noted below

**Markdown Body**:
- Plain text instructions Claude follows when the skill runs
- Can reference supporting files, use string substitutions, run shell commands
- Becomes the system prompt for the skill

---

## 2. Where Skills Live: Scopes & Discovery

### Location Hierarchy (Priority Order)

| Scope | Path | Applies To | Priority |
|-------|------|-----------|----------|
| **Plugin** | `<plugin>/skills/<name>/SKILL.md` | Where plugin is enabled | Lowest |
| **Project** | `.claude/skills/<name>/SKILL.md` | Current project only | 3rd |
| **Personal** | `~/.claude/skills/<name>/SKILL.md` | All your projects | 2nd |
| **Enterprise** | Server-managed settings | Org-wide | Highest |

When multiple skills share the same name across levels, higher priority wins.

Plugin skills use a namespaced reference: `plugin-name:skill-name` (no conflicts).

### Automatic Discovery

Claude Code automatically discovers skills from:
1. `.claude/skills/` in the current project
2. Nested `.claude/skills/` directories (supports monorepos)
3. `~/.claude/skills/` from your home directory
4. `.claude/skills/` in directories added via `--add-dir`

No registration needed — add a `SKILL.md` and it's live immediately (with live change detection during sessions).

### Legacy: `.claude/commands/`

Old-style command files (`.claude/commands/deploy.md`) still work identically, but skills are recommended because they support supporting files, frontmatter fields, and automatic activation.

---

## 3. How Skills Are Invoked

### Manual Invocation (User Triggers)

Type `/` followed by the skill name:

```
/explain-code src/auth/login.ts
/deploy
/fix-issue 123
```

### Automatic Invocation (Claude Decides)

Claude automatically loads skills when:
1. `disable-model-invocation: false` (default)
2. The skill's description matches the conversation context
3. Claude determines the skill is relevant

### Programmatic Invocation (Via Skill Tool)

Claude has access to a "Skill tool" that allows it to invoke skills by name with arguments. Restrict with:

```json
{
  "permissions": {
    "allow": ["Skill(commit)", "Skill(review-*)"],
    "deny": ["Skill(deploy)"]
  }
}
```

---

## 4. Skill Chaining & Composition

### Can Skills Invoke Other Skills?

**Directly within Markdown:** Not built-in, but you can:
1. Use shell commands to call other skills
2. Call `claude` CLI from within a skill script

**Via Claude's Skill Tool:** Yes — Claude can chain skills in sequence.

**Context Isolation:** Each skill invocation receives fresh context. Chaining happens through Claude's orchestration.

### Composition Patterns

**Pattern 1: Skill -> Subagent**
```yaml
---
name: research
context: fork
agent: Explore
---
Research $ARGUMENTS thoroughly
```

**Pattern 2: Skill -> Script -> Tool**
```yaml
---
name: validate
allowed-tools: Bash
---
Run validation:
!`./scripts/validate.sh`
```

**Pattern 3: Skill -> Another Skill (via Claude)**
Manual direction: "Use /skill1, then /skill2 with the results"

---

## 5. Tools & Capabilities

### Tool Access Model

Skills run in the same context as your conversation, inheriting your session's tools and permissions. Restrict with `allowed-tools`:

```yaml
---
name: safe-reader
allowed-tools: Read, Grep, Glob
---
```

### Full Tool Palette Available

- **File Operations**: Read, Write, Edit, Glob, Grep
- **Command Execution**: Bash
- **Web**: WebFetch, WebSearch
- **Code**: Git, Commit, CreatePullRequest
- **MCP Tools**: All configured MCP servers
- **Special**: AskUserQuestion, SendMessage
- **Subagents**: Agent tool (spawn and manage subagents)

### Can Skills Spawn Subagents?

**Yes, via two mechanisms:**

**1. Via `context: fork`** (skill runs in forked subagent):
```yaml
---
name: deep-research
context: fork
agent: Explore
---
```

**2. Via Agent tool** (skill invokes subagents programmatically):
```yaml
---
name: coordinator
---
Use the Agent tool to spawn research and review subagents in parallel.
```

---

## 6. Dynamic Creation & Runtime Behavior

Skills must be **predefined as files** on disk. They're discovered at session start and during live change detection.

However, you can:
1. **Modify skill files dynamically** and they reload automatically
2. **Generate skill files** with another process and they appear in subsequent sessions
3. **Use `--agents` flag** to pass temporary session-only skill-like agents in JSON

### Live Reload Behavior

Skills in `.claude/skills/` are watched for changes. Edit a `SKILL.md` and Claude picks it up in the next turn. No session restart needed.

---

## 7. Complete Frontmatter Schema

| Field | Type | Default | Purpose |
|-------|------|---------|---------|
| `name` | string | Directory name | Skill identifier (lowercase, hyphens, max 64 chars). Becomes `/slash-command`. |
| `description` | string | First paragraph | Tells Claude when to use the skill. Max 250 chars in listings. |
| `argument-hint` | string | (none) | UI hint for expected arguments. Example: `[issue-number]`. |
| `disable-model-invocation` | boolean | `false` | If `true`, only user can invoke (Claude cannot load automatically). |
| `user-invocable` | boolean | `true` | If `false`, hidden from `/` menu. Background knowledge only. |
| `allowed-tools` | string/array | Inherit | Comma-separated or YAML array of tools. Allowlist. |
| `model` | string | Inherit | Model: `sonnet`, `opus`, `haiku`, full ID, or `inherit`. |
| `effort` | string | Inherit | Effort level: `low`, `medium`, `high`, `max`. |
| `context` | string | Inline | Set to `fork` to run in a forked subagent context. |
| `agent` | string | `general-purpose` | Subagent type when `context: fork`. Options: `Explore`, `Plan`, `general-purpose`, custom. |
| `hooks` | object | (none) | Lifecycle hooks scoped to this skill. Same format as settings.json hooks. |
| `paths` | string/array | (all) | Glob patterns to limit activation. Example: `src/**/*.ts`. |
| `shell` | string | `bash` | Shell for inline commands: `bash` or `powershell`. |

### String Substitutions in Skill Content

| Variable | Value |
|----------|-------|
| `$ARGUMENTS` | All arguments passed |
| `$ARGUMENTS[N]` | Nth argument (0-indexed) |
| `$N` | Shorthand for `$ARGUMENTS[N]` |
| `${CLAUDE_SESSION_ID}` | Current session ID |
| `${CLAUDE_SKILL_DIR}` | Directory containing SKILL.md |

---

## 8. Interaction with Claude Code Ecosystem

### Skills <-> CLAUDE.md
- CLAUDE.md is global context (loaded into every turn)
- Skills are invoked context (loaded when used)
- Both coexist

### Skills <-> Memory
- Skills can reference and modify memory via Read/Write tools
- Subagents can use persistent agent memory

### Skills <-> Hooks
Skills can define their own hooks (scoped to skill lifecycle):
```yaml
---
name: secure-deploy
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "./scripts/security-check.sh"
---
```

### Skills <-> Subagents
Two-way:
1. Skill runs IN subagent (`context: fork`)
2. Subagent USES skill (`skills` field in agent definition)

### Skills <-> Permissions
Restrict with `allowed-tools`. Control invocation with permission rules.

---

## 9. Arguments & Parameters

### Passing Arguments
```
/fix-issue 123
/migrate-component SearchBar React Vue
```

### Using Arguments
1. **All arguments** (`$ARGUMENTS`): `Fix issue $ARGUMENTS`
2. **Indexed** (`$0`, `$1`): `Migrate $0 from $1 to $2`
3. **Explicit** (`$ARGUMENTS[N]`): `Deploy $ARGUMENTS[0] to $ARGUMENTS[1]`

If skill doesn't mention `$ARGUMENTS`, they're auto-appended.

---

## 10. Limits & Constraints

| Constraint | Limit |
|-----------|-------|
| Skill name length | 64 chars max |
| Description length | 250 chars (in listings) |
| Context window | Session limit |
| Subagent nesting | 1 level max |
| Tool restrictions | Via `allowed-tools` (allowlist only) |
| Script execution | Bash/PowerShell only |
| File I/O | Session permissions |
| Runtime creation | Not supported (must be predefined) |

---

## 11. Dynamic Context Injection (Shell Commands)

Skills can run shell commands BEFORE Claude sees them using `` !`command` ``:

```yaml
---
name: pr-analyzer
context: fork
agent: Explore
---

Analyze this PR:
- Diff: !`gh pr diff`
- Comments: !`gh pr view --comments`
```

Each `` !`command` `` runs immediately (preprocessing), output replaces the placeholder, Claude receives the fully-rendered skill.

---

## 12. Modeling Agent Roles with Skills

### Pattern 1: Skill-Based Roles (Simple)
```yaml
# ~/.claude/skills/ceo/SKILL.md
---
name: ceo
description: Strategic decision making
context: fork
agent: general-purpose
---
You are the CEO. Analyze strategic questions.
```

### Pattern 2: Subagent-Based Roles (More Control)
```yaml
# ~/.claude/agents/ceo/SKILL.md
---
name: ceo
skills: [market-analysis, financial-planning]
---
You are the CEO. Use preloaded skills.
```

### Pattern 3: Agent Teams (Parallel)
```bash
claude --experimental-agent-teams
```
Set up teammates with independent context, model, tools, and skills.

### Building a Role Skill Library
```
~/.claude/skills/
├── ceo/SKILL.md
├── hr-manager/SKILL.md
├── developer/SKILL.md
└── shared/
    ├── decision-framework.md
    └── approval-process.md
```

---

## 13. Built-in Skills

| Skill | Purpose |
|-------|---------|
| `/batch <instruction>` | Parallel large-scale changes via git worktrees |
| `/claude-api [language]` | Load Claude API/SDK reference |
| `/debug [description]` | Enable debug logging |
| `/loop [interval] <prompt>` | Run prompt repeatedly |
| `/simplify [focus]` | Review code and fix issues in parallel |

---

## 14. Quick Reference: Frontmatter Cheatsheet

```yaml
# Minimal
---
name: skill-name
description: What it does
---

# Reference/Background (Claude decides when to use)
---
name: conventions
description: Design patterns
user-invocable: false
---

# Task (Manual trigger only)
---
name: deploy
description: Deploy to production
disable-model-invocation: true
allowed-tools: Bash, Read
---

# With Subagent (Isolated context)
---
name: research
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob
---

# Complete Advanced
---
name: api-developer
description: Implement APIs with conventions
skills: [api-conventions, error-handling]
context: fork
agent: general-purpose
allowed-tools: Read, Write, Edit, Bash
hooks:
  PostToolUse:
    - matcher: Write|Edit
      hooks:
        - type: command
          command: ./format.sh
paths: src/api/**
---
```
