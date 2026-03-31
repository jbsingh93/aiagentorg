# Skill Library System — Dynamic Skill Creation, Sharing & Registry

**Date:** 2026-03-31
**Purpose:** Enable CAO and supervisors to create custom skills (reusable workflows) for agents, share them across the organisation, and maintain a searchable registry.

---

## 1. What This System Does

In a real company, employees develop standard operating procedures (SOPs) and share them. OrgAgent mirrors this:

1. **Create** — CAO or a supervisor designs a skill for an agent (a reusable workflow)
2. **Register** — The skill is added to the org's skill registry with metadata
3. **Share** — Skills can be shared with other agents or departments
4. **Discover** — Agents can browse the registry to find skills they can use
5. **Version** — Skills evolve over time; changes are tracked
6. **Permission** — Not all agents can use all skills; access is controlled

---

## 2. Directory Structure

Custom skills live in `org/skills/` (runtime state, per-org). They are SEPARATE from the system skills in `.claude/skills/` (which are part of the OrgAgent template).

```
org/skills/                              # The skill library
├── registry.md                          # Master index of all custom skills
│
├── shared/                              # Available to all agents
│   ├── google-cloud-setup/
│   │   ├── SKILL.md                     # The skill definition
│   │   └── references/                  # Supporting docs if needed
│   └── data-export-workflow/
│       └── SKILL.md
│
├── marketing/                           # Marketing department skills
│   ├── content-calendar-generator/
│   │   └── SKILL.md
│   └── seo-audit-workflow/
│       └── SKILL.md
│
├── sales/                               # Sales department skills
│   └── lead-qualification/
│       └── SKILL.md
│
└── agent-specific/                      # Single-agent skills
    └── seo-agent/
        └── backlink-analyzer/
            └── SKILL.md
```

### Why `org/skills/` Not `.claude/skills/`

| Location | Purpose | Discovery |
|----------|---------|-----------|
| `.claude/skills/` | System skills (OrgAgent template) | Auto-discovered by Claude Code |
| `org/skills/` | Custom org skills (created at runtime) | Discovered via registry + agent INSTRUCTIONS |

Custom skills live in `org/` because:
1. They're runtime state (created after onboarding)
2. They follow the "all runtime in org/" principle
3. They're org-specific (different orgs have different skills)
4. They're managed by the CAO (who works in org/)

### How Agents Discover and Use Custom Skills

Since `org/skills/` isn't auto-discovered by Claude Code, agents access them by:
1. Reading the registry (`org/skills/registry.md`) to find available skills
2. Reading the SKILL.md file directly with the Read tool
3. Following the instructions in the SKILL.md

This is a **manual invocation** pattern — the agent reads the skill's instructions and executes them, rather than Claude Code auto-loading them. This is intentional:
- It keeps the system skills (`.claude/skills/`) clean
- It gives agents explicit control over when they use a custom skill
- It works with the existing permission system (agents can only read skills they have access to)

---

## 3. Skill Registry Format

**File:** `org/skills/registry.md`

```markdown
# Skill Library — {ORG_NAME}

> Last updated: 2026-04-15T10:00:00
> Total skills: 5

## Shared Skills

| Skill | Created By | Date | Description | Used By |
|-------|-----------|------|-------------|---------|
| [google-cloud-setup](shared/google-cloud-setup/SKILL.md) | cao | 2026-04-01 | Set up a Google Cloud account and obtain API credentials via browser | ceo, seo-agent |
| [data-export-workflow](shared/data-export-workflow/SKILL.md) | cao | 2026-04-05 | Export data from any web service to markdown files | all |

## Department Skills

### Marketing
| Skill | Created By | Date | Description | Used By |
|-------|-----------|------|-------------|---------|
| [content-calendar-generator](marketing/content-calendar-generator/SKILL.md) | marketing-manager | 2026-04-10 | Generate a quarterly content calendar from keyword data | marketing-manager, content-writer |
| [seo-audit-workflow](marketing/seo-audit-workflow/SKILL.md) | cao | 2026-04-12 | Comprehensive SEO audit of a website using WebSearch + browser | seo-agent |

### Sales
| Skill | Created By | Date | Description | Used By |
|-------|-----------|------|-------------|---------|
| [lead-qualification](sales/lead-qualification/SKILL.md) | sales-manager | 2026-04-15 | Qualify a lead using CRM data and web research | sales-agent |

## Agent-Specific Skills

| Skill | Agent | Created By | Date | Description |
|-------|-------|-----------|------|-------------|
| [backlink-analyzer](agent-specific/seo-agent/backlink-analyzer/SKILL.md) | seo-agent | cao | 2026-04-08 | Analyze backlink profile of a domain using browser + WebSearch |
```

---

## 4. Custom Skill File Format

Each custom skill follows the same format as system skills but with additional metadata:

```markdown
---
name: google-cloud-setup
description: "Set up a Google Cloud account and obtain API credentials (OAuth, service account keys). Uses browser automation for web UI steps that have no CLI equivalent."
created_by: cao
created_date: 2026-04-01
last_modified: 2026-04-01
version: 1.0
scope: shared
department: 
access:
  - all
required_tools:
  - Read
  - Write
  - Bash
  - mcp__playwright__goto
  - mcp__playwright__click
  - mcp__playwright__fill
  - mcp__playwright__snapshot
tags:
  - browser
  - google-cloud
  - api-credentials
  - setup
---

# Google Cloud Setup Workflow

## Purpose
Set up a Google Cloud Platform account and obtain API credentials for use by the organisation's agents. This skill automates the web UI steps that cannot be done via CLI.

## Prerequisites
- Browser tools (Playwright MCP) must be available
- An email address for the Google account
- Organisation's billing information (if enabling paid APIs)

## Steps

### Step 1: Navigate to Google Cloud Console
...

### Step 2: Create a new project
...

### Step 3: Enable required APIs
...

### Step 4: Create credentials
...

### Step 5: Store credentials securely
Write credentials to `org/agents/{requesting-agent}/credentials/google-cloud.md`
(This path must be in the agent's access_write list)

## Output
- Google Cloud project ID
- OAuth client ID and secret (or service account key)
- Stored at: org/agents/{agent}/credentials/

## Error Handling
- If CAPTCHA encountered: escalate to supervisor
- If billing required: escalate to board for approval
- If API quota error: wait and retry after 60 seconds
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Kebab-case skill name |
| `description` | string | What the skill does |
| `created_by` | string | Agent ID who created it |
| `created_date` | date | When created |
| `last_modified` | date | Last update |
| `version` | string | Semantic version |
| `scope` | enum | `shared`, `department`, `agent-specific` |
| `department` | string | Department name (if scope is department) |
| `access` | array | Agent IDs or "all" |
| `required_tools` | array | Tools needed to execute this skill |
| `tags` | array | Searchable tags |

---

## 5. The `/create-skill` Skill

A meta-skill that CAO or supervisors use to create new custom skills.

**File:** `.claude/skills/create-skill/SKILL.md`

```yaml
---
name: create-skill
description: "Create a new custom skill for the organisation. Designs the workflow, writes the SKILL.md, registers it in the skill library, and assigns access permissions. CAO and supervisors only."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
argument-hint: "[skill-name] [description] — or omit for interactive"
---

# Create Custom Skill

**Access:** CAO and supervisors (managers+) can create skills.

**CRITICAL:** Before writing the skill, read `.claude/skills/master-gpt-prompter/SKILL.md`. 
Custom skills are LLM prompts — they must be maximally potent.

## Step 1: Define the skill
If `$ARGUMENTS` provided, use as starting point.
If not, ask:
- What should this skill do? (workflow description)
- Who is it for? (specific agent, department, or all)
- What tools does it need? (browser, web search, bash, etc.)
- Is this a one-time setup or a repeatable workflow?

## Step 2: Determine scope and access
- **Shared** (`org/skills/shared/`): Available to all agents
- **Department** (`org/skills/{dept}/`): Available to a department
- **Agent-specific** (`org/skills/agent-specific/{agent}/`): One agent only

## Step 3: Design the workflow
Following master-gpt-prompter principles:
1. Break the workflow into clear, numbered steps
2. For each step: specify the tool, the action, and the expected result
3. Include error handling for each step
4. Specify the output format
5. Include prerequisites (what tools/access the agent needs)

## Step 4: Write the skill file
Create `org/skills/{scope}/{skill-name}/SKILL.md` with:
- Full frontmatter (name, description, created_by, version, scope, access, required_tools, tags)
- Detailed step-by-step workflow following master-gpt-prompter principles
- Error handling
- Output specification

## Step 5: Update the registry
Append a new row to `org/skills/registry.md` in the appropriate section (Shared/Department/Agent-Specific).

## Step 6: Notify
- If for a specific agent: send thread message + notification
- If for a department: send thread message to department channel
- If shared: send broadcast notification

## Step 7: Update agent INSTRUCTIONS
If the skill is for a specific agent or department:
- Add to the agent's INSTRUCTIONS.md: "You have access to custom skill: [name]. Read it at org/skills/{path}/SKILL.md when you need to [description]."
- This ensures the agent knows the skill exists

## Confirm
"Skill '{name}' created at org/skills/{path}/SKILL.md. Access: {who}. Registered in library."
```

---

## 6. How Agents Use Custom Skills

### Discovery
Agents find skills through:
1. **Their INSTRUCTIONS.md** — lists skills assigned to them during creation or reconfiguration
2. **The registry** — `org/skills/registry.md` (if they have read access to `org/skills/`)
3. **Thread messages** — when a new skill is created and they're notified

### Execution
When an agent needs to use a custom skill:
1. Read the skill's SKILL.md from `org/skills/{path}/SKILL.md`
2. Verify they have the required tools (check IDENTITY.md)
3. Follow the steps in the skill
4. Log the skill execution in their activity stream
5. Report results in the relevant thread

### Example: SEO Agent using backlink-analyzer skill
```
SEO Agent heartbeat:
1. Read task: "Analyze competitor backlinks"
2. Check INSTRUCTIONS.md → "Custom skill available: backlink-analyzer"
3. Read org/skills/agent-specific/seo-agent/backlink-analyzer/SKILL.md
4. Follow the steps (use WebSearch, browser tools, etc.)
5. Write results to reports/
6. Report in thread
```

---

## 7. Skill Versioning

Skills evolve. When a skill is updated:
1. Increment the `version` field in frontmatter
2. Update `last_modified` date
3. Add a changelog entry at the bottom of SKILL.md:
   ```markdown
   ## Changelog
   - v1.1 (2026-04-15): Added error handling for rate limits
   - v1.0 (2026-04-01): Initial version
   ```
4. Notify all agents in the `access` list about the update

---

## 8. Skill Sharing Workflow

When a skill created for one agent could benefit others:

```
Supervisor identifies reusable skill
     ↓
Supervisor (or CAO) runs /create-skill or modifies existing
     ↓
Changes scope: agent-specific → department or shared
     ↓
Moves skill file to new location (org/skills/shared/ or org/skills/{dept}/)
     ↓
Updates registry.md with new access list
     ↓
Notifies newly-authorized agents via thread
     ↓
Updates each agent's INSTRUCTIONS.md to reference the skill
```

---

## 9. Integration with Permissions

Custom skills respect the data access system:
- An agent can only READ skills in directories listed in their `access_read`
- An agent can only EXECUTE a skill if they have the `required_tools`
- If an agent doesn't have a required tool: they create a tool request to the CAO

**IDENTITY.md access for custom skills:**
```yaml
access_read:
  - org/skills/shared/                    # All shared skills
  - org/skills/marketing/                 # Department skills
  - org/skills/agent-specific/seo-agent/  # Own agent-specific skills
  - org/skills/registry.md                # Skill discovery
```

---

## 10. Onboarding Integration

During `/onboard`, the bootstrap creates:
```bash
mkdir -p org/skills/shared org/skills/agent-specific
```

And creates an empty registry:
```markdown
# Skill Library — {ORG_NAME}

> Last updated: {NOW}
> Total skills: 0

No custom skills yet. Use /create-skill to add workflows to the library.
```

---

## 11. Architecture Decisions

### Decision 42: Custom Skill Library in org/skills/

**Decision:** Custom skills live in `org/skills/` (not `.claude/skills/`). They are discovered via registry, not Claude Code auto-discovery.

**Reasoning:**
- Runtime state belongs in `org/`
- Different orgs have different skills
- Explicit discovery (read registry → read skill) is more controlled than auto-loading
- Keeps `.claude/skills/` clean (only system skills)

### Decision 43: /create-skill Meta-Skill

**Decision:** A dedicated `/create-skill` skill enables CAO and supervisors to create custom skills following master-gpt-prompter principles.

**Access:** CAO and managers+ (not workers — they USE skills, they don't CREATE them).

### Decision 44: Skill Access via IDENTITY.md

**Decision:** Access to custom skills is controlled by the `access_read` list in IDENTITY.md, just like all other file access. Plus the `access` field in the skill's frontmatter documents who should use it.

---

## 12. Updated Skill Count

This adds 2 new system skills:

| # | Skill | Purpose |
|---|-------|---------|
| 19 | **browser** | Browser automation via Playwright (MCP/CLI) |
| 20 | **create-skill** | Create custom skills for the skill library |

**Total system skills: 20** (was 18)
