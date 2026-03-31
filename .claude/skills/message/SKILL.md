---
name: message
description: "Send an inter-agent message via thread. Validates chain-of-command before delivery. Determines message type, finds or creates thread, appends greppable message block, sends inbox notification."
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "[from] [to] [message-text] — or omit for interactive mode"
---

# Send Inter-Agent Message

## Step 1: Determine sender, recipient, and content
If `$ARGUMENTS` provided: parse from, to, and message.
If not, ask the user:
- Who is sending? (agent ID or "board")
- Who is receiving? (agent ID)
- What is the message?
- What type? (directive / report / request / escalation / discussion / notification)

## Step 2: Validate chain-of-command
1. Read `org/orgchart.md` to determine relationships
2. Determine sender's position, supervisor, and direct reports
3. Determine recipient's position, supervisor, and direct reports
4. Check if the message route is ALLOWED:
   - **Downward to direct reports:** ALLOWED
   - **Upward to direct supervisor:** ALLOWED
   - **Lateral to same-department peers:** ALLOWED
   - **CAO to anyone:** ALLOWED (workforce management authority)
   - **CEO to any manager:** ALLOWED
   - **Board to anyone:** ALLOWED
   - **Cross-department managers:** ALLOWED (note as cross-dept type)
   - **Worker to non-supervisor:** BLOCKED
   - **Skip-level (worker to CEO):** BLOCKED
5. If BLOCKED: explain why and suggest the correct route.
   Example: "@seo-agent cannot message @ceo directly. Send to @marketing-manager, who can escalate to CEO."

## Step 3: Determine message type
Based on content and direction:
- Superior → subordinate: `directive` or `notification`
- Subordinate → superior: `report`, `request`, or `escalation`
- Peer → peer: `discussion`
- Board → anyone: `board-directive`
- Cross-department: `cross-dept`

## Step 4: Find or create thread
1. Check existing threads in `org/threads/{department}/` for a matching topic
2. If existing thread found: use it
3. If new topic: create `org/threads/{department}/thread-{topic-slug}-{YYYYMMDD}.md`:
   ```markdown
   ---
   thread_id: thread-{topic-slug}-{YYYYMMDD}
   topic: {TOPIC_TITLE}
   department: {DEPARTMENT}
   participants:
     - {SENDER}
     - {RECIPIENT}
   status: active
   created: {NOW_ISO8601}
   last_activity: {NOW_ISO8601}
   message_count: 0
   ---

   # Thread: {TOPIC_TITLE}
   ```
4. Update `org/threads/index.md` if a new thread was created

## Step 5: Append message to thread
Append to the thread file:
```
---
### [MSG-{YYYYMMDD}-{HHMMSS}-{sender}] {TIMESTAMP} — {EMOJI} {SENDER_TITLE} → {EMOJI} {RECIPIENT_TITLE} [{type}]

{MESSAGE_BODY}
```

Update thread frontmatter: increment `message_count`, update `last_activity`, add recipient to `participants` if not already listed.

## Step 6: Send notification
Write to `org/agents/{recipient}/inbox/notif-{YYYYMMDD}-{HHMMSS}-{sender}.md`:
```markdown
---
type: thread-notification
thread_id: {THREAD_ID}
thread_path: {THREAD_FILE_PATH}
msg_id: MSG-{YYYYMMDD}-{HHMMSS}-{sender}
from: {SENDER}
timestamp: {NOW_ISO8601}
read: false
subject: "New {type} in: {THREAD_TOPIC}"
---
```

## Step 7: Confirm
"Message sent from @{sender} to @{recipient} in thread '{topic}': {subject_summary}"
