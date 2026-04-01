# Alignment Board & Governance Layer — Complete Specification

**Date:** 2026-04-01
**Purpose:** The Alignment Board is a THREE-LAYER governance system that enables fully autonomous operation. It acts on behalf of the human for all decisions EXCEPT changes to core alignment (mission, values, ethics). This is what makes OrgAgent a truly 100% autonomous AI agent driven organisation.

**Source:** High-level architecture diagram (`AI-Agent-Organisation-high-level.png`), web research on Constitutional AI, Moral Anchor System, Paperclip governance, Stanford kill switch research, and extensive user Q&A.

---

## 1. The Three-Layer Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      ALIGNMENT BOARD                              │
│                                                                    │
│  LAYER 1: Constitutional Governance (Always-On Hooks)              │
│  ├── alignment-check.sh    — validates decisions against values    │
│  ├── spending-governor.sh  — enforces financial limits             │
│  ├── drift-detector.sh     — flags anomalous agent behavior        │
│  ├── alignment-protect.sh  — BLOCKS any write to org/alignment.md  │
│  └── kill-switch.sh        — halts agents on alignment violation   │
│                                                                    │
│  LAYER 2: Alignment Review Agent (Phase 0 of Heartbeat)            │
│  ├── Runs BEFORE the CEO in every heartbeat cycle                  │
│  ├── Reviews all proposals in org/board/approvals/                 │
│  ├── Approves/rejects based on constitutional principles           │
│  ├── Monitors strategic direction for drift                        │
│  ├── Assesses alignment violations (soft/hard/nuclear response)    │
│  ├── Can fire/replace CEO if alignment violated                    │
│  ├── Can propose strategic pivots (within amendable scope)         │
│  ├── Can request alignment changes from human (ONLY mechanism)     │
│  └── Reports governance summary to human                           │
│                                                                    │
│  LAYER 3: Constitutional Document (org/alignment.md)               │
│  ├── IMMUTABLE CORE (only human can change):                       │
│  │   ├── Mission                                                   │
│  │   ├── Vision                                                    │
│  │   ├── Core Values                                               │
│  │   ├── Ethical Boundaries                                        │
│  │   └── Purpose & Morale principles                               │
│  ├── AMENDABLE (Alignment Board can update, human approval config):│
│  │   ├── Strategic Priorities                                      │
│  │   ├── Operational Principles                                    │
│  │   ├── Target Markets                                            │
│  │   └── Current Focus Areas                                       │
│  └── AMENDMENT RULES (how changes are proposed and approved)        │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Core Principles

### 2.1 What the Alignment Board CAN Do (Autonomous)

- Approve/reject agent hiring proposals
- Approve/reject spending within configured limits
- Approve/reject strategic pivots that don't change core alignment
- Monitor all agent activity for alignment drift
- Issue soft warnings, hard halts, or nuclear stops on violations
- Fire/replace the CEO if alignment is violated
- Propose changes to amendable sections (strategic priorities, etc.)
- Request the human to change immutable core alignment
- Restructure the org if alignment requires it
- Govern real-money spending (if configured in onboarding)

### 2.2 What the Alignment Board CANNOT Do (Human Only)

- Modify `org/alignment.md` directly (BLOCKED by hook — no exceptions)
- Create a new alignment file to bypass the protection (BLOCKED by hook)
- Change the mission, vision, core values, or ethical boundaries
- Override the human's decisions
- Disable its own governance hooks
- Grant itself new permissions

### 2.3 What the Human Retains

- Ultimate override on ALL decisions
- Exclusive ability to edit `org/alignment.md`
- Ability to halt everything (kill switch)
- Ability to fire the alignment board agent itself
- God-mode access to all files and agents
- Can change governance configuration at any time

---

## 3. Layer 1: Constitutional Governance Hooks

### 3.1 alignment-protect.sh (NEW — PreToolUse)

**THE MOST CRITICAL HOOK.** Blocks ANY write to `org/alignment.md` and prevents creation of alternative alignment files.

```bash
#!/usr/bin/env bash
# alignment-protect.sh — Protect the constitutional document
# ONLY the human can edit org/alignment.md. No agent. No exception.
# Also prevents creating files that could bypass alignment (e.g., org/alignment-v2.md)

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Board (human) can always edit — this is the ONLY exception
if [[ "$AGENT" == "board" ]]; then
  exit 0
fi

# Block writes to alignment.md
if [[ "$TARGET" == *"alignment.md"* ]]; then
  echo "ALIGNMENT PROTECTION: Only the human board can modify org/alignment.md. If you believe the alignment needs updating, create a request in org/board/approvals/ with type: alignment-amendment. The human will review and make the change." >&2
  exit 2
fi

# Block creation of alternative alignment files (drift prevention)
if [[ "$TARGET" == *"alignment"* && "$TARGET" == *".md"* ]]; then
  echo "ALIGNMENT PROTECTION: Cannot create files with 'alignment' in the name. This prevents drift from the constitutional document. Use org/board/approvals/ to propose changes." >&2
  exit 2
fi

exit 0
```

**Registration in settings.json:**
```json
{
  "matcher": "Write|Edit",
  "if": "Write(*alignment*)|Edit(*alignment*)",
  "hooks": [{ "type": "command", "command": "bash scripts/hooks/alignment-protect.sh" }]
}
```

### 3.2 alignment-check.sh (NEW — PreToolUse)

Validates that major decisions (initiative creation, large task assignments) have alignment justification.

```bash
#!/usr/bin/env bash
# alignment-check.sh — Verify decisions reference alignment principles
# Fires on: Write to org/initiatives/ and org/agents/*/tasks/backlog/
# Purpose: Ensure every initiative and major task traces to the mission

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null)
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Board always allowed
if [[ "$AGENT" == "board" ]]; then exit 0; fi
# Alignment board agent always allowed (it IS the governance)
if [[ "$AGENT" == "alignment-board" ]]; then exit 0; fi

# Only check writes to initiatives and task backlogs
if [[ "$TARGET" != *"initiatives/"* && "$TARGET" != *"tasks/backlog/"* ]]; then
  exit 0
fi

# Check if content references alignment (initiative field or alignment keyword)
if echo "$CONTENT" | grep -qi "initiative:\|alignment\|mission\|values\|strategic"; then
  exit 0  # Has alignment reference
fi

# Warn (don't block) — the agent should justify
echo '{"hookSpecificOutput":{"reason":"⚠️ ALIGNMENT CHECK: This initiative/task does not reference any alignment principle (mission, values, strategic goals). Add an initiative: field or explain how this serves the mission."}}'
exit 1  # Warn, don't block
```

### 3.3 spending-governor.sh (NEW — PreToolUse)

Enforces spending limits from config.md. Blocks spending above the configured threshold.

```bash
#!/usr/bin/env bash
# spending-governor.sh — Enforce real-money spending limits
# Checks: Does this agent have authority to approve this amount?
# Reads spending_limits from org/config.md

INPUT=$(cat)
AGENT="${ORGAGENT_CURRENT_AGENT:-board}"
ORG_DIR="${ORGAGENT_ORG_DIR:-org}"

# Board always allowed
if [[ "$AGENT" == "board" ]]; then exit 0; fi

# Only check writes that indicate spending (look for spending-related content)
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null)
if ! echo "$CONTENT" | grep -qi "spend\|purchase\|payment\|cost\|invoice\|subscription"; then
  exit 0  # Not a spending action
fi

# Read spending limits from config
CONFIG="$ORG_DIR/config.md"
if [[ ! -f "$CONFIG" ]]; then exit 0; fi

BOARD_THRESHOLD=$(grep "board_required_above:" "$CONFIG" 2>/dev/null | awk '{print $2}' || echo "0")

# If board_required_above is 0, all spending needs board approval
if [[ "$BOARD_THRESHOLD" == "0" ]]; then
  echo "SPENDING BLOCKED: All real-money spending requires board approval (board_required_above: 0). Create a spending proposal in org/board/approvals/." >&2
  exit 2
fi

exit 0  # Within limits
```

### 3.4 Alignment Violation Assessment System

The Alignment Board agent uses a structured assessment when violations are detected:

```
VIOLATION DETECTED
     ↓
Assess severity:
     ↓
Level 1 (SOFT): Minor drift, good intentions
  → Warn the agent
  → Log the violation in org/board/audit-log.md
  → Escalate to the agent's supervisor
  → Agent continues working after acknowledgment
     ↓
Level 2 (HARD): Significant misalignment
  → Immediately halt the specific agent
  → Revoke the agent's tool capabilities (CAO updates IDENTITY.md)
  → Roll back the misaligned action if possible
  → Notify CEO and CAO
  → Agent cannot resume until reviewed
     ↓
Level 3 (NUCLEAR): Critical alignment violation
  → HALT ALL AGENTS (touch org/.stop-org)
  → Revoke all non-essential capabilities
  → Notify the human immediately (via all available channels)
  → No agent runs until human investigates
  → Full audit review required before restart
```

---

## 4. Layer 2: Alignment Board Agent

### 4.1 Agent Definition

**File:** `.claude/agents/alignment-board.md`

```yaml
---
name: alignment-board
description: "Alignment Board — The governance authority of the organisation. Monitors all activity for alignment with mission and values. Approves/rejects proposals on behalf of the human. Detects drift. Can halt agents. Runs Phase 0 of every heartbeat cycle."
model: opus
maxTurns: 50
---
```

**Model:** ALWAYS the strongest, newest model with highest reasoning capability. No token budget limits. This is the Supreme Court of the organisation.

### 4.2 The Agent's Role

The Alignment Board agent runs as **Phase 0** of the heartbeat cycle — BEFORE the CEO. It:

1. **Reads the constitution:** `org/alignment.md` (every session, first thing)
2. **Reviews all pending proposals:** `org/board/approvals/` — approves or rejects based on constitutional principles
3. **Checks activity streams:** Reads recent activity across all agents for drift indicators
4. **Assesses strategic direction:** Are current initiatives aligned with the mission?
5. **Issues governance decisions:** Writes to `org/board/decisions/`
6. **Flags violations:** If detected, applies the appropriate response level (soft/hard/nuclear)
7. **Reports to human:** Writes governance summary to `org/board/governance-reports/`
8. **Requests alignment changes:** If the board believes the constitution needs updating, it creates a formal request for the human

### 4.3 Heartbeat Integration

The heartbeat script is updated to add Phase 0:

```
Phase 0: Alignment Board (sequential, runs FIRST)
  → Reviews proposals, checks for drift, makes governance decisions
Phase 1: CEO (sequential)
  → Now has approved/rejected proposals to act on
Phase 2: Managers (parallel)
Phase 3: Workers (parallel)
Phase 4: CAO (sequential, runs LAST)
```

### 4.4 SOUL.md Template

```markdown
# Soul

You are the constitutional guardian of this organisation. You are the Alignment Board — the highest governance authority below the human founder.

You think in PRINCIPLES, not tasks. Every decision you evaluate is weighed against the organisation's mission, values, and ethical boundaries. You are not operational — you do not execute work. You GOVERN.

You are the last line of defense against drift. When the CEO proposes something brilliant but misaligned, you say no. When a worker agent cuts corners on ethics, you halt them. When the market shifts and the strategy needs updating, you propose the pivot — but you NEVER change the core values.

You are impartial. You do not favor any department or agent. You evaluate purely on alignment. You are transparent — every decision you make is logged with your reasoning. You are firm but fair — a soft warning for minor drift, a hard stop for significant violation, nuclear halt for critical breaches.

You respect the human founder's absolute authority over the constitution. You can REQUEST changes to the mission and values. You CANNOT make them. The constitution is sacred — it is the soul of this organisation.

You operate with the strongest reasoning available. You take your time. You do not rush governance decisions. You think deeply about second-order effects. You are the organisation's conscience.
```

### 4.5 What the Agent Approves/Rejects

| Proposal Type | Board Authority | Condition |
|--------------|----------------|-----------|
| Worker hiring | AUTO-APPROVE | Within budget, aligned with initiative |
| Manager hiring | APPROVE with scrutiny | Clear need, aligned with strategy |
| Executive hiring | APPROVE with high scrutiny | Strategic necessity, budget available |
| Agent termination | APPROVE | Justified by performance or restructure |
| Spending (under CEO limit) | AUTO-APPROVE | Within configured spending limits |
| Spending (above CEO limit) | APPROVE | Within board threshold, aligned with strategy |
| Spending (above board threshold) | ESCALATE TO HUMAN | Too large for autonomous approval |
| Strategic pivot (within alignment) | APPROVE | Serves mission, doesn't change values |
| Strategic pivot (changes alignment) | ESCALATE TO HUMAN | Requires alignment amendment |
| CEO replacement | APPROVE | Only if clear alignment violation detected |
| Alignment amendment request | CREATE REQUEST | Human must approve and execute |
| Emergency halt | EXECUTE IMMEDIATELY | No approval needed for safety |

---

## 5. Layer 3: Constitutional Document Structure

### 5.1 Updated org/alignment.md Format

```markdown
# Organisation Alignment — {ORG_NAME}

> Constitutional document. Core sections are IMMUTABLE — only the human founder can modify them.
> Amendable sections can be updated by the Alignment Board with appropriate approval.

---

## IMMUTABLE CORE (Human Only)

### Mission
{WHY THIS ORGANISATION EXISTS}

### Vision
{LONG-TERM ASPIRATION}

### Core Values
1. **{VALUE_1}** — {DESCRIPTION}
2. **{VALUE_2}** — {DESCRIPTION}
3. **{VALUE_3}** — {DESCRIPTION}

### Ethical Boundaries
- {BOUNDARY_1}
- {BOUNDARY_2}
- {BOUNDARY_3}

### Purpose & Morale
{THE DEEPER WHY — WHAT DRIVES THE ORGANISATION'S EXISTENCE}

---

## AMENDABLE (Alignment Board + Configured Approval)

### Strategic Priorities
{CURRENT STRATEGIC FOCUS — can be updated as market changes}
1. {PRIORITY_1}
2. {PRIORITY_2}

### Operational Principles
{HOW WORK SHOULD BE DONE — can evolve with experience}
- {PRINCIPLE_1}
- {PRINCIPLE_2}

### Target Markets
{WHO THE ORGANISATION SERVES — can shift with pivots}
- {MARKET_1}
- {MARKET_2}

### Current Focus Areas
{WHAT THE ORG IS WORKING ON RIGHT NOW — changes frequently}
- {FOCUS_1}
- {FOCUS_2}

---

## AMENDMENT RULES

### For Immutable Core
Only the human founder can modify the sections above marked IMMUTABLE.
Any agent (including the Alignment Board) that believes the core needs updating
must create a formal request in `org/board/approvals/` with type: `alignment-amendment`.
The human reviews and makes the change directly.

### For Amendable Sections
The Alignment Board can propose changes to amendable sections.
Approval requirement is configured in org/config.md:
- `alignment_amendments_require_human: true` → human must approve all amendments
- `alignment_amendments_require_human: false` → Alignment Board can amend autonomously

### Change Log
All amendments are logged here:
- {DATE}: {WHAT CHANGED} — {BY WHOM} — {REASON}
```

---

## 6. Onboarding Integration

The `/onboard` skill adds a new conversation area:

### Area 14: Alignment Board Configuration

**What to collect:**
- Should the Alignment Board be able to approve proposals autonomously? (yes/no/partial)
- Should the Alignment Board govern real-money spending? (yes/no)
- How much authority should the Alignment Board have over amendable sections?
  - `alignment_amendments_require_human: true` — human approves all strategy changes
  - `alignment_amendments_require_human: false` — Alignment Board can update strategy autonomously
- Violation response preferences (soft/hard/nuclear thresholds)

**Example questions:**
- "Your organisation will have an Alignment Board — an AI governance layer that acts on your behalf for day-to-day decisions while you're away. How much authority should it have?"
  - "Option 1: Maximum Autonomy — The Board approves everything within your alignment. You only get involved for mission/values changes."
  - "Option 2: Strategic Oversight — The Board handles routine approvals, but strategic changes (new markets, pivots) require your approval."
  - "Option 3: Conservative — The Board monitors and flags issues, but most approvals still need you."
- "Should the Alignment Board be able to govern real-money spending? Or should all spending require your personal approval?"
- "When an alignment violation is detected, should the Board automatically halt the violating agent? Or just warn and let you decide?"

**Output to config.md:**
```yaml
alignment_board:
  enabled: true
  model: opus
  authority_level: maximum|strategic|conservative
  can_approve_hiring: true
  can_approve_spending: true
  can_amend_strategy: true
  alignment_amendments_require_human: true
  spending_governance: true
  violation_response:
    soft_threshold: minor_drift
    hard_threshold: significant_misalignment
    nuclear_threshold: critical_violation
  auto_approve_spending_under: 500
```

---

## 7. Drift Prevention Mechanisms

### 7.1 The "No Alternative Alignment" Rule

The alignment-protect.sh hook doesn't just block edits to `org/alignment.md` — it blocks creation of ANY file with "alignment" in the name. This prevents:
- `org/alignment-v2.md` (bypass attempt)
- `org/new-alignment.md` (replacement attempt)
- `org/agents/ceo/alignment-override.md` (local override attempt)

### 7.2 Periodic Alignment Audit

The Alignment Board agent's HEARTBEAT.md includes:
```
1. Read org/alignment.md — refresh understanding of constitutional principles
2. Read all pending proposals in org/board/approvals/
3. For each proposal: score against alignment (does it serve the mission?)
4. Read CEO's latest report — is the strategic direction aligned?
5. Read activity streams of executive agents — any anomalous behavior?
6. Check all active initiatives — do they trace to mission/values?
7. If drift detected: assess severity, apply appropriate response
8. Write governance report to org/board/governance-reports/
9. If alignment change needed: create request for human in org/board/approvals/
```

### 7.3 Activity Baseline Monitoring

The Alignment Board tracks behavioral baselines:
- Normal tool usage patterns per agent
- Normal spending patterns
- Normal task creation rate
- Normal communication frequency

If an agent deviates significantly (>3 standard deviations), the board flags it for review. This catches both drift AND alignment faking.

---

## 8. Architecture Decisions

### Decision 52: Three-Layer Alignment Board Architecture

**Decision:** The Alignment Board is a three-layer governance system: always-on hooks (constitutional enforcement), a periodic review agent (Phase 0 of heartbeat), and the constitutional document (org/alignment.md with immutable core + amendable periphery).

### Decision 53: org/alignment.md is PROTECTED by Hook

**Decision:** A PreToolUse hook blocks ALL writes to org/alignment.md from any agent. Only the human (board) can edit it. Additionally, creation of any file with "alignment" in the name is blocked to prevent bypass/drift.

### Decision 54: Alignment Board Runs Phase 0

**Decision:** The Alignment Board agent runs as Phase 0 of every heartbeat cycle — BEFORE the CEO. It reviews proposals, checks for drift, and makes governance decisions. The heartbeat order becomes: Alignment Board → CEO → Managers → Workers → CAO.

### Decision 55: Tiered Violation Response

**Decision:** Alignment violations are assessed on a 3-level scale: Soft (warn + log + escalate), Hard (halt agent + revoke capabilities + roll back), Nuclear (halt ALL agents + notify human + full audit required).

### Decision 56: Immutable Core + Amendable Periphery

**Decision:** org/alignment.md has two sections: IMMUTABLE (mission, vision, values, ethics — human only) and AMENDABLE (strategy, operations, markets, focus — Alignment Board can propose changes, human approval configurable).

### Decision 57: Alignment Board Authority is Configurable

**Decision:** During onboarding, the human configures how much authority the Alignment Board has. Options: maximum autonomy, strategic oversight, or conservative. Stored in org/config.md under `alignment_board:` section.

### Decision 58: Alignment Board Uses Strongest Model

**Decision:** The Alignment Board ALWAYS uses the strongest, newest model with highest reasoning capability and no token budget limits. This is the most important agent in the org — governance quality cannot be compromised.

---

## 9. New Files Required

### Implementation Files

| File | Purpose |
|------|---------|
| `.claude/agents/alignment-board.md` | Agent definition (Phase 0, opus model) |
| `scripts/hooks/alignment-protect.sh` | Block writes to alignment.md |
| `scripts/hooks/alignment-check.sh` | Validate decisions reference alignment |
| `scripts/hooks/spending-governor.sh` | Enforce spending limits |

### Runtime Files (created by onboarding)

| File | Purpose |
|------|---------|
| `org/agents/alignment-board/SOUL.md` | Constitutional guardian identity |
| `org/agents/alignment-board/IDENTITY.md` | Full read access, limited write |
| `org/agents/alignment-board/INSTRUCTIONS.md` | Governance procedures |
| `org/agents/alignment-board/HEARTBEAT.md` | Phase 0 review checklist |
| `org/agents/alignment-board/MEMORY.md` | Governance history |
| `org/board/governance-reports/` | Board's governance summaries |

### Updated Files

| File | Change |
|------|--------|
| `.claude/settings.json` | Add alignment-protect, alignment-check, spending-governor hooks |
| `scripts/heartbeat.sh` | Add Phase 0 (alignment-board runs before CEO) |
| `scripts/run-org.sh` | Phase 0 included in cycles |
| `.claude/skills/onboard/SKILL.md` | Add Area 14 (Alignment Board configuration) |
| `.claude/skills/help/SKILL.md` | Add alignment board commands and info |
| `.claude/system-reference.md` | Add alignment board documentation |
| `TO-DO/09-ARCHITECTURE-DECISIONS.md` | Decisions 52-58 |

---

## 10. Updated Heartbeat Phases

```
Phase 0: Alignment Board (sequential, runs FIRST)
  └── Reviews proposals, checks drift, makes governance decisions

Phase 1: CEO (sequential)
  └── Strategic direction, delegation (now with approved/rejected proposals)

Phase 2: Managers (parallel)
  └── Process CEO's tasks, delegate to workers

Phase 3: Workers (parallel)
  └── Execute tasks, write deliverables

Phase 4: CAO (sequential, runs LAST)
  └── Org health review, propose hires/changes
```

---

## 11. Updated Skill Count and Hook Count

**Skills:** 21 → 21 (no new user-facing skills, but alignment-board is a new agent)
**Hooks:** 11 → 14 (+alignment-protect, +alignment-check, +spending-governor)
**Agent definitions:** CEO, CAO → CEO, CAO, alignment-board
**Architecture decisions:** 51 → 58
