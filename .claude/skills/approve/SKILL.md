---
name: approve
description: "Board approval workflow — list, approve, or reject pending proposals. Handles hire, fire, reconfigure, escalation, budget, and strategy proposals."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[approve|reject] [proposal-id] [reason] — or omit to list pending"
---

# Board Approval Workflow

## Step 1: List pending proposals
Read all files in `org/board/approvals/` where frontmatter `status: pending`.
For each, display:
```
| ID | Type | Proposed By | Date | Summary |
```

If no pending proposals: "No pending proposals."

## Step 2: Process approval/rejection
If `$ARGUMENTS` includes "approve" or "reject":

### Approve
1. Find the matching proposal file by ID (or partial match)
2. Read the proposal fully — display a summary to the user
3. Update frontmatter:
   - `status: approved`
   - `decided_by: board`
   - `decided_date: {NOW_ISO8601}`
4. Move file from `org/board/approvals/` to `org/board/decisions/`
5. Log to audit trail (automatic via hook)
6. Send thread message in `org/threads/executive/` announcing the decision
7. Send notification to the proposer's inbox

### Reject
1. Find the matching proposal file
2. Read and display summary
3. If no reason in `$ARGUMENTS`, ask: "Why are you rejecting this?"
4. Update frontmatter:
   - `status: rejected`
   - `decided_by: board`
   - `decided_date: {NOW_ISO8601}`
   - `decision_reason: {REASON}`
5. Move file to `org/board/decisions/`
6. Log to audit trail
7. Send thread message in `org/threads/executive/` with rejection reason
8. Send notification to the proposer's inbox

## Step 3: Interactive mode
If no arguments provided:
1. List all pending proposals
2. For each, show a brief summary
3. Ask the user: "Which proposal would you like to review? (Enter ID, or 'approve/reject ID')"
4. Process their response

## Confirm
"Proposal {ID} {approved/rejected}. Decision archived to org/board/decisions/."
