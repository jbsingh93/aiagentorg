# Screenshot Analysis — User's AI Agent Organisation Diagram

**Source:** `c:\Users\julia\Downloads\Skaermbillede 2026-03-30 225813.png`
**Language:** Danish
**Type:** High-level architectural diagram of an AI agent organisation

---

## Diagram Structure

### Top Layer: Masterboard (Human Governance)

```
┌──────────────────────────────────────────────────────┐
│                    MASTERBOARD                         │
│                                                        │
│  ┌─────────────────────────────────────┐              │
│  │  Venn diagram of overlapping        │   "Dynamisk  │
│  │  concerns:                          │   governance" │
│  │  - CEO/Strategy                     │              │
│  │  - Operations                       │   "Oversigt   │
│  │  - Workstreams/Workflow             │   over alle   │
│  │                                     │   aktiviteter │
│  └─────────────────────────────────────┘   for at      │
│                                            folge sig   │
│                                            selv"       │
└──────────────────────────────────────────────────────┘
```

**Translation:** "Dynamic governance" — "Overview of all activities to follow itself"

### Middle Layer: CEO Agent

The CEO Agent sits directly below the Masterboard, receiving strategic direction and reporting upward.

### Department Manager Layer

Seven department managers branch out from the CEO:

```
                          CEO Agent
                              │
        ┌──────┬──────┬──────┼──────┬──────┬──────┐
        │      │      │      │      │      │      │
        ▼      ▼      ▼      ▼      ▼      ▼      ▼
   Post/    Kreativ  Produk- Finance CRM/   IT/   Marketing
   Sales    Manager  tions   Manager Kunde  Tech   Manager
   Manager          Manager         Manager Manager
```

### Worker Agent Layer

Each manager has 2-3 specialist worker agents:

**Post/Sales Manager:**
- Sales agent ("Belle agent")
- Webshop agent

**Creative Manager (Kreativ Manager):**
- Content production agent ("Indholdsprodukt agent")
- Video production agent ("Videoprodukt agent")

**Production Manager (Produktions Manager):**
- Production agent
- Quality agent
- Supply chain agent

**Finance Manager:**
- Accounting agent
- Budget agent

**CRM/Customer Manager (CRM/Kunde Manager):**
- CRM agent
- Support/customer agent ("Kundekontakt agent")

**IT/Tech Manager:**
- Dev agent
- Infrastructure agent

**Marketing Manager:**
- SEO agent
- Social media agent
- PR/Brand agent

### Right Sidebar: Agent Chat / Messaging

```
┌──────────────────────┐
│  Agent chat /         │
│  messaging            │
│                       │
│  - Inter-agent        │
│    communication      │
│  - Cross-department   │
│    coordination       │
│  - Message history    │
│  - Thread tracking    │
│                       │
└──────────────────────┘
```

---

## Complete Org Tree (Reconstructed)

```
MASTERBOARD (Human Governance)
├── Dynamic Governance
│   ├── Activity oversight
│   └── Workstream visibility
│
└── CEO Agent
    ├── Post/Sales Manager
    │   ├── Sales Agent
    │   └── Webshop Agent
    │
    ├── Creative Manager
    │   ├── Content Production Agent
    │   └── Video Production Agent
    │
    ├── Production Manager
    │   ├── Production Agent
    │   ├── Quality Agent
    │   └── Supply Chain Agent
    │
    ├── Finance Manager
    │   ├── Accounting Agent
    │   └── Budget Agent
    │
    ├── CRM/Customer Manager
    │   ├── CRM Agent
    │   └── Customer Support Agent
    │
    ├── IT/Tech Manager
    │   ├── Dev Agent
    │   └── Infrastructure Agent
    │
    └── Marketing Manager
        ├── SEO Agent
        ├── Social Media Agent
        └── PR/Brand Agent
```

**Total:** 1 Board + 1 CEO + 7 Managers + ~17 Workers = ~26 entities

---

## Key Design Insights from Screenshot

1. **Tree hierarchy** — strict reporting lines, no matrix structure
2. **Department-based** — each manager owns a functional domain
3. **2-3 workers per manager** — manageable span of control
4. **Agent messaging is a first-class feature** — dedicated panel in the UI
5. **Governance sits above everything** — dynamic oversight of all activities
6. **Dashboard visibility** — the board can see everything happening across all departments
7. **Danish labels** — user is Danish-speaking, system should support multilingual

---

## How This Maps to OrgAgent (Final Plan)

| Screenshot Element | OrgAgent Implementation |
|-------------------|------------------------|
| Masterboard | Human board with GUI dashboard + CLI |
| Dynamic governance | Hooks (audit, budget, approval gates) |
| Activity overview | GUI dashboard with all 8 views |
| CEO Agent | `.claude/agents/ceo.md` + workspace |
| Department Managers | Dynamically created by CAO |
| Worker Agents | Dynamically created by CAO |
| Agent chat/messaging | `/message` skill + inbox/outbox folders |

**Note:** The final plan differs from the screenshot in one key way — the screenshot shows a static, pre-built org, but the user explicitly wants a DYNAMIC system where only CEO + CAO exist initially and all other agents are created on-demand by the CAO.
