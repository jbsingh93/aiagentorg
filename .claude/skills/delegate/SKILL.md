---
name: delegate
description: "Create a task for a subordinate and notify them via thread. Validates chain-of-command — the assignee must report to the assigner. Creates task file, appends directive to department thread, sends inbox notification."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[assignee] [task-title] — or omit for interactive mode"
---

# Delegate Task to Subordinate

## Step 1: Determine delegation parameters
If `$ARGUMENTS` provided, parse assignee and task title.
If not, ask the user:
- Who should this be delegated to? (agent ID)
- What is the task? (title and description)
- What priority? (critical / high / medium / low)
- What deadline? (date or "none")
- Which initiative does this support? (check org/initiatives/)

## Step 2: Validate chain-of-command
1. Read `org/orgchart.md`
2. Confirm the assignee reports to the assigning agent (check the tree — assignee must be a direct subordinate or a subordinate-of-subordinate for CEO)
3. If the assignee does NOT report to the assigner: BLOCK and suggest the correct route.
   Example: "You cannot delegate to @seo-agent directly. Delegate to @marketing-manager instead, who manages @seo-agent."
4. Confirm the assignee's status is `active` in orgchart (not terminated, paused, or pending-approval)

## Step 3: Generate task ID
1. Read existing files in the assignee's `org/agents/{assignee}/tasks/backlog/` directory
2. Find the highest task number for today's date prefix: `task-{YYYYMMDD}-NNN`
3. Increment by 1. If none exist for today, start at 001.

## Step 4: Create the task file
Write to `org/agents/{assignee}/tasks/backlog/task-{YYYYMMDD}-{NNN}.md`:

```markdown
---
id: task-{YYYYMMDD}-{NNN}
title: {TASK_TITLE}
priority: {PRIORITY}
status: backlog
assigned_to: {ASSIGNEE}
assigned_by: {ASSIGNER}
initiative: {INITIATIVE_SLUG}
created: {NOW_ISO8601}
started:
completed:
deadline: {DEADLINE_OR_EMPTY}
estimated_cost_usd:
---

## Description
{TASK_DESCRIPTION}

## Acceptance Criteria
{CRITERIA — generate reasonable criteria from the description if not explicitly provided}

## Context
Ref: org/initiatives/{INITIATIVE_SLUG}.md
Reports to: @{ASSIGNER}

## Results
_(filled in by the assigned agent upon completion)_
```

## Step 5: Communicate via thread
1. Determine the correct department thread:
   - If an existing thread covers this topic in `org/threads/{department}/`: append to it
   - If new topic: create `org/threads/{department}/thread-{topic-slug}-{YYYYMMDD}.md` with proper frontmatter
2. Append a message block to the thread:
   ```
   ---
   ### [MSG-{YYYYMMDD}-{HHMMSS}-{assigner}] {TIMESTAMP} — {EMOJI} {ASSIGNER_TITLE} → {EMOJI} {ASSIGNEE_TITLE} [directive]

   Task delegated: **{TASK_TITLE}**
   Task file: `org/agents/{assignee}/tasks/backlog/task-{ID}.md`
   Priority: {PRIORITY} | Deadline: {DEADLINE}
   Initiative: {INITIATIVE}

   {Brief context or specific instructions}
   ```
3. Update thread frontmatter: increment `message_count`, update `last_activity`
4. Update thread index if a new thread was created

## Step 6: Send notification
Write lightweight notification to `org/agents/{assignee}/inbox/notif-{YYYYMMDD}-{HHMMSS}-{assigner}.md`:
```markdown
---
type: thread-notification
thread_id: {THREAD_ID}
thread_path: org/threads/{department}/{thread-file}
msg_id: MSG-{YYYYMMDD}-{HHMMSS}-{assigner}
from: {ASSIGNER}
timestamp: {NOW_ISO8601}
read: false
subject: "New task: {TASK_TITLE}"
---
```

## Step 7: Confirm
Tell the user: "Task `{ID}` delegated to @{assignee}: {title} (priority: {priority}, deadline: {deadline})"
