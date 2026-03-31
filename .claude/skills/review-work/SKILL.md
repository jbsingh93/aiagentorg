---
name: review-work
description: "Manager skill: Review a subordinate's completed task. Read deliverables, evaluate against acceptance criteria, approve or request revisions via department thread."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[agent-name] [task-id] — or omit to review latest completed tasks"
---

# Review Subordinate Work

## Step 1: Find completed tasks to review
- If `$ARGUMENTS` specifies agent and task ID: review that specific task
- If only agent specified: list all tasks in their `org/agents/{agent}/tasks/done/` from today
- If omitted: scan all direct subordinates' `tasks/done/` for recently completed tasks

Present found tasks:
```
| Task ID | Agent | Title | Completed | Initiative |
```

## Step 2: Read the completed task
1. Read the task file in `org/agents/{subordinate}/tasks/done/{task-id}.md`
2. Read the **Results** section carefully
3. If the task references deliverables (reports/, specific files), read those too
4. Read the **Acceptance Criteria** checklist

## Step 3: Evaluate against acceptance criteria
For each acceptance criterion:
- Is it met? (fully / partially / not at all)
- Quality assessment (exceeds expectations / meets / below)

Decision:
- **All criteria met + quality acceptable:** APPROVED
- **Some criteria missing or quality insufficient:** REVISIONS NEEDED

## Step 4: Provide feedback via thread
Find or create a thread in the subordinate's department folder.
Append review message:

```
---
### [MSG-{YYYYMMDD}-{HHMMSS}-{reviewer}] {TIMESTAMP} — {EMOJI} {REVIEWER} → {EMOJI} {SUBORDINATE} [discussion]

**REVIEW: {task-title}** (task-{ID})
**Status: APPROVED** / **REVISIONS NEEDED**

### Feedback
{What was done well}
{What needs improvement — be specific}
{If revisions needed: exact changes required, with references}

### Next Steps
{If approved: any follow-up tasks?}
{If revisions: deadline for revised version}
```

Send notification to subordinate's inbox.

## Step 5: If revisions needed
1. Move the task file BACK from `tasks/done/` to `tasks/active/`
2. Edit task frontmatter: `status: active`, clear `completed` date
3. Append revision notes to the task body under a new `## Revision Notes` section

## Step 6: If approved
The task stays in `tasks/done/`. Optionally:
- If this unblocks another task, note it
- If this completes an initiative milestone, report upward

## Confirm
"Review complete for @{subordinate} task {id}: {APPROVED / REVISIONS NEEDED}"
