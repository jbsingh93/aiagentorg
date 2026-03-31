---
name: task
description: "Task management: assign, list, view, or move tasks across agents. Provides a unified interface for task operations."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[assign|list|view|move] [args] — or omit for interactive"
---

# Task Management

## Subcommands

### `assign` — Create and assign a task
Same workflow as the `/delegate` skill. When `/task assign` is invoked, execute the full `/delegate` workflow internally.

Arguments: `/task assign [assignee] [title]`

### `list` — List tasks
Arguments: `/task list [agent-name | all]`

If agent name provided: list that agent's tasks from all 3 directories.
If "all" or omitted: list tasks across ALL agents.

Read from:
- `org/agents/*/tasks/backlog/*.md`
- `org/agents/*/tasks/active/*.md`
- `org/agents/*/tasks/done/*.md`

Parse frontmatter for: id, title, status, priority, assigned_to, deadline, initiative.

Display as:
```
| ID | Title | Agent | Status | Priority | Deadline | Initiative |
|--- |-------|-------|--------|----------|----------|-----------|
| task-20260331-001 | Q2 SEO Strategy | seo-agent | active | high | 2026-04-15 | q2-marketing |
```

Sort by: priority (critical first), then deadline (earliest first).

### `view` — View a specific task
Arguments: `/task view [task-id]`

1. Search for the task file across all agents' task directories (use Glob: `org/agents/*/tasks/*/task-id.md`)
2. Read the full file
3. Display: all frontmatter fields + full body (Description, Acceptance Criteria, Context, Results)

### `move` — Move a task between states
Arguments: `/task move [task-id] [backlog|active|done]`

1. Find the task file (Glob search)
2. Determine current location (which status directory it's in)
3. Move the file to the target status directory:
   - To `active`: set `status: active`, `started: {NOW_ISO8601}`
   - To `done`: set `status: done`, `completed: {NOW_ISO8601}`
   - To `backlog`: set `status: backlog`, clear `started` and `completed`
4. Communicate the status change in the relevant department thread
5. Send notification to the task's `assigned_by` agent

## Interactive Mode
If no subcommand provided:
1. Show summary: "X active, Y backlog, Z done across N agents"
2. Ask: "What would you like to do? (assign / list / view / move)"
