---
name: create-skill
description: "Create a new custom skill (reusable workflow) for the organisation's skill library. Designs the workflow following master-gpt-prompter principles, writes the SKILL.md, registers it in org/skills/registry.md, and assigns access permissions. For CAO and supervisors (managers+) only."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[skill-name] [description] — or omit for interactive"
---

# Create Custom Skill for the Organisation

**Access:** CAO and supervisors (managers+) can create skills. Workers use skills, they don't create them.

**CRITICAL:** Before writing the skill, read `.claude/skills/master-gpt-prompter/SKILL.md` and its references. Custom skills are LLM prompts — they must be maximally potent, following all 15 principles of the master-gpt-prompter.

## Step 1: Define the skill

If `$ARGUMENTS` provided, use as starting point.
If not, ask the user:
- **What should this skill do?** (detailed workflow description)
- **Who is it for?** (specific agent, a department, or all agents)
- **What tools does it need?** (browser, web search, bash, specific MCP tools, etc.)
- **Is it a one-time setup or a repeatable workflow?**
- **What is the expected output?** (file, report, data, configuration, etc.)

## Step 2: Determine scope and location

| Scope | Directory | Who Can Use |
|-------|-----------|-------------|
| **Shared** | `org/skills/shared/{name}/` | All agents in the org |
| **Department** | `org/skills/{dept}/{name}/` | Agents in that department |
| **Agent-specific** | `org/skills/agent-specific/{agent}/{name}/` | One specific agent |

Create the directory:
```bash
mkdir -p org/skills/{scope}/{skill-name}
```

## Step 3: Design the workflow

Read `.claude/skills/master-gpt-prompter/SKILL.md` and apply its principles.

For each step in the workflow, define:
1. **What tool to use** (Read, Write, Bash, browser, WebSearch, etc.)
2. **What action to take** (navigate to URL, fill form, run command, etc.)
3. **What the expected result is** (file created, data extracted, etc.)
4. **What to do if it fails** (retry, escalate, alternative approach)

Include:
- **Prerequisites** — what tools/access/data the agent needs before starting
- **Step-by-step instructions** — numbered, unambiguous, with exact tool calls
- **Output specification** — what files/data the skill produces
- **Error handling** — what to do for each failure mode
- **Verification** — how to confirm the skill completed successfully

## Step 4: Write the skill file

Write to `org/skills/{scope}/{skill-name}/SKILL.md`:

```markdown
---
name: {SKILL_NAME}
description: "{DESCRIPTION}"
created_by: {YOUR_AGENT_ID}
created_date: {NOW_DATE}
last_modified: {NOW_DATE}
version: 1.0
scope: {shared|department|agent-specific}
department: {DEPT_OR_EMPTY}
access:
  - {AGENT_IDS_OR_ALL}
required_tools:
  - {TOOL_1}
  - {TOOL_2}
tags:
  - {TAG_1}
  - {TAG_2}
---

# {Skill Title}

## Purpose
{What this skill does and when to use it}

## Prerequisites
{What the agent needs before starting}

## Steps

### Step 1: {Step title}
{Detailed instructions with exact tool calls}

### Step 2: {Step title}
...

## Output
{What the skill produces, where files are stored}

## Error Handling
{What to do for each failure mode}

## Changelog
- v1.0 ({DATE}): Initial version
```

## Step 5: Update the registry

Read `org/skills/registry.md` and append a new row in the appropriate section:

```markdown
| [{name}]({path}/SKILL.md) | {created_by} | {date} | {description} | {who_can_use} |
```

If the section doesn't exist yet (first skill for a department), create it.

Update the header: increment total skills count, update last_updated date.

## Step 6: Notify relevant agents

Based on the skill's scope:
- **Agent-specific:** Send thread message + notification to that agent
- **Department:** Send thread message to the department channel
- **Shared:** Send broadcast or message to all managers

Include in the notification:
- Skill name and what it does
- Where to find it: `org/skills/{path}/SKILL.md`
- What tools are required
- How to use it: "Read the skill file and follow the steps"

## Step 7: Update agent INSTRUCTIONS (if agent-specific or department)

If the skill is assigned to specific agents:
- Edit their `org/agents/{name}/INSTRUCTIONS.md`
- Add under a "## Available Custom Skills" section:
  ```
  - **{skill-name}**: {description}. Read: `org/skills/{path}/SKILL.md`
  ```
- This ensures the agent knows the skill exists during heartbeat

## Step 8: Update agent access (if needed)

If the skill is in a directory the agent can't read:
- Update their IDENTITY.md `access_read` to include the skill path
- E.g., add `org/skills/shared/` or `org/skills/{dept}/`

## Confirm

"Custom skill '{name}' created at org/skills/{path}/SKILL.md.
Scope: {scope}. Access: {who}. Required tools: {tools}.
Registered in org/skills/registry.md. {Notification sent to N agents}."
