# Phase 3: Core Agent Definitions

**Objective:** Create CEO and CAO agent definition files that Claude Code uses for `claude --agent`.
**Files to create:** 2
**Depends on:** Phase 1 (settings.json, rules must exist)
**Can run in parallel with:** Phase 2 (skills) and Phase 4 (scripts)
**Estimated effort:** 1-2 hours

**CRITICAL:** Read `.claude/skills/master-gpt-prompter/SKILL.md` before writing these. The agent definition body IS a prompt.

---

## Task 3.1: `.claude/agents/ceo.md` — CEO Agent Definition

- [ ] **Create file:** `.claude/agents/ceo.md`
- **Spec:** `TO-DO/14-ONBOARDING-SKILL-FULL-SPEC.md` → Step 2.12 (agent definition template)
- **Also:** `TO-DO/01-MASTER-PLAN.md` → Section 3 (lines 189-247)
- **Key content:**
  - Frontmatter: `name: ceo`, `description`, `model: opus`, `maxTurns: 50`
  - Body: initialization instructions pointing to workspace files
  - Context loading order: alignment → config → SOUL → IDENTITY → INSTRUCTIONS → MEMORY → orgchart → custom-rules
  - Execution: follow INSTRUCTIONS.md, if heartbeat follow HEARTBEAT.md
  - Output: log to activity/memory, write to reports/
  - All content in configured language
- **Note:** This is a TEMPLATE — it references `{ORG_NAME}` etc. which the `/onboard` skill fills in at runtime. For the template version, use literal placeholder text or generic references.
- **Dependencies:** Phase 1
- **Verify:** `claude --agent ceo` doesn't error (though it won't work fully without org/ created by /onboard)

---

## Task 3.2: `.claude/agents/cao.md` — CAO Agent Definition

- [ ] **Create file:** `.claude/agents/cao.md`
- **Spec:** `TO-DO/14-ONBOARDING-SKILL-FULL-SPEC.md` → Step 2.12 (agent definition template)
- **Also:** `TO-DO/01-MASTER-PLAN.md` → Section 4 (lines 249-331)
- **Key content:**
  - Frontmatter: `name: cao`, `description`, `model: opus`, `maxTurns: 50`
  - Body: initialization instructions + workforce management context
  - Context loading: includes budgets/overview.md and master-gpt-prompter reference
  - Must reference: "Read `.claude/skills/master-gpt-prompter/SKILL.md` before creating any agent"
  - Execution: follow INSTRUCTIONS.md, if heartbeat follow HEARTBEAT.md
- **Dependencies:** Phase 1
- **Verify:** `claude --agent cao` doesn't error

---

## Important Note: Agent Definitions vs Workspace Files

The agent definition files (`.claude/agents/*.md`) are TEMPLATES that tell Claude how to initialize as that agent. They point to workspace files in `org/agents/*/`.

The actual workspace files (SOUL.md, IDENTITY.md, INSTRUCTIONS.md, etc.) are NOT created during implementation — they are created at RUNTIME by the `/onboard` skill.

**What we create now:** `.claude/agents/ceo.md` and `.claude/agents/cao.md` (definitions)
**What /onboard creates later:** `org/agents/ceo/SOUL.md`, `org/agents/ceo/IDENTITY.md`, etc.

However, the CONTENT of those workspace files is specified in:
- CEO workspace: `TO-DO/14-ONBOARDING-SKILL-FULL-SPEC.md` → Steps 2.10 (full SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY templates)
- CAO workspace: `TO-DO/14-ONBOARDING-SKILL-FULL-SPEC.md` → Steps 2.11 (full SOUL, IDENTITY, INSTRUCTIONS, HEARTBEAT, MEMORY templates)

The onboarding skill reads these templates and fills in the placeholders with data from the alignment conversation.

---

## Phase 3 Verification

```bash
# Agent definitions exist
for f in .claude/agents/ceo.md .claude/agents/cao.md; do
  if [ -f "$f" ]; then echo "OK: $f"; else echo "MISSING: $f"; fi
done

# Frontmatter is valid (has name and model)
for f in .claude/agents/ceo.md .claude/agents/cao.md; do
  echo "--- $f ---"
  head -6 "$f"
done
```
