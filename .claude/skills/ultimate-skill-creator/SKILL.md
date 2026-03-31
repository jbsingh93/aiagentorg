---
name: ultimate-skill-creator
description: "Create world-class Claude Code skills by first conducting exhaustive multi-source deep research on any topic. Use when: (1) Creating a skill about a domain you need deep expertise in, (2) User wants a research-backed skill with comprehensive knowledge, (3) Building skills that require practitioner insights, SOTA techniques, or real-world data, (4) User says 'create a skill about X' and X requires deep understanding beyond general knowledge, (5) Any skill creation task where quality depends on thorough domain research first."
---

# Ultimate Skill Creator

Create world-class Claude Code skills by first becoming a domain expert through exhaustive multi-source deep research.

**Core insight**: To make a truly great skill about a subject, you first need deep expertise from multiple angles and real-world sources — not just general knowledge.

## Prerequisites

| Variable | Required By | Get From |
|----------|------------|----------|
| `GEMINI_API_KEY` | Gemini Deep Research | https://aistudio.google.com/app/apikey |
| `PERPLEXITY_API_KEY` | Perplexity Deep Research | https://www.perplexity.ai/settings/api |

Both are optional — the skill degrades gracefully if one or both APIs are unavailable.

## Output Directory

All artifacts are saved to: `ultimate-skill-output/{skill-name}_{YYYYMMDD_HHMMSS}/`

Create this directory at the start of the workflow.

---

## Phase 1: Topic Analysis

Understand what skill the user wants and plan the research strategy.

1. Clarify the skill's purpose, target users, and key capabilities with the user.
2. Identify **3 distinct research angles** that together would give comprehensive domain mastery. Choose angles that minimize overlap and maximize coverage. Examples:
   - **Technical implementation** — APIs, libraries, code patterns, architecture decisions
   - **Practitioner experience** — Real-world usage, gotchas, lessons learned, community wisdom
   - **Competitive landscape / SOTA** — Current best approaches, recent papers, emerging trends
3. Present the 3 angles to the user for approval before proceeding.
4. Create the output directory: `ultimate-skill-output/{skill-name}_{YYYYMMDD_HHMMSS}/`

---

## Phase 2: Research Prompt Optimization

For each of the 3 research angles, craft an optimized deep research prompt.

### For each angle (repeat 3 times):

**Step 2a — Draft the research prompt:**
Write a detailed research prompt that:
- Focuses on Reddit, Twitter/X, HN, GitHub, arxiv, peer-reviewed papers, StackOverflow
- Explicitly excludes AI-generated blog spam and low-quality content farms
- Requests specific examples, data points, practitioner quotes, code snippets
- Asks for contradictions and debates in the field
- Specifies the output should be comprehensive with inline citations

**Step 2b — Optimize the prompt using master-gpt-prompter:**

Before optimizing, always prefix your work with:
> *"THIS IS FOR A REASONING MODEL AND A DEEP RESEARCH MODEL. Please do extensive research on how to prompt for deep research as well!"*

Then **read and follow** the nested skill instructions inline:

1. Read `nested-skills/master-gpt-prompter/INSTRUCTION.md` for the full workflow
2. Perform web searches for SOTA models and deep research prompting techniques
3. Read the relevant reference files from `nested-skills/master-gpt-prompter/references/`:
   - `HOW-TO-MAKE-PROMPTS-FOR-AI-agents.md`
   - `PROMPT-ENGINEERING-FOR-REASONING-MODELS.md`
   - `PROMPT-ENGINEERING-FRAMWORKS.md`
   - `Prompt-Engineering-Guide.md`
   - `The-Ultimate-Guide-to-Prompt-Engineering-for-Large-Language-Models.md`
   - `NEWEST-MODELS-AND-Prompt-Engineering-Guide-Update-Request.md`
4. Analyze and optimize the research prompt using the techniques learned

**Do NOT invoke master-gpt-prompter via the Skill tool** — read and execute its instructions inline.

**Step 2c — Save the optimized prompt:**
Save each optimized prompt to `{output_dir}/prompt_{N}_{angle_slug}.md` (e.g., `prompt_1_technical_implementation.md`)

---

## Phase 3: Execute Deep Research

Run 3 research tracks concurrently. Tracks A+B use external APIs; Track C uses your native capabilities.

### Check API availability first:
```python
import os
has_gemini = bool(os.environ.get("GEMINI_API_KEY"))
has_perplexity = bool(os.environ.get("PERPLEXITY_API_KEY"))
```

Inform the user which tracks will run based on available API keys.

### Track A — Gemini Deep Research (Angle 1)

Run the Gemini deep research script:
```bash
python scripts/deep_research_gemini.py \
  --prompt-file "{output_dir}/prompt_1_{angle}.md" \
  --output "{output_dir}/research_gemini.md" \
  --json
```
- This is async with polling — takes 5-20 minutes
- The script handles all polling internally

### Track B — Perplexity Deep Research (Angle 2)

Run the Perplexity deep research script:
```bash
python scripts/deep_research_perplexity.py \
  --prompt-file "{output_dir}/prompt_2_{angle}.md" \
  --output "{output_dir}/research_perplexity.md" \
  --json
```
- Synchronous but can take several minutes

### Track C — Claude Native Research (Angle 3)

While Tracks A+B run, perform the 3rd research angle yourself using native tools:

1. **WebSearch** — Perform 8-12 targeted web searches covering the angle's sub-topics. Focus queries on:
   - `site:reddit.com {topic}` for practitioner discussions
   - `site:news.ycombinator.com {topic}` for technical debates
   - `site:github.com {topic}` for code patterns and implementations
   - `site:arxiv.org {topic}` for academic papers
   - `site:stackoverflow.com {topic}` for common problems and solutions
   - General queries for recent developments and SOTA

2. **WebFetch** — Deep-read the 5-8 most promising results for detailed content extraction.

3. **Synthesize** — Compile findings into a comprehensive research report with:
   - Key findings organized by sub-topic
   - Direct quotes and specific data points
   - Source URLs for every claim
   - Contradictions and open debates noted

4. **Save** — Write the report to `{output_dir}/research_claude.md`

### Parallel Execution Strategy

Use `scripts/run_all_research.py` to launch Tracks A+B in parallel:
```bash
python scripts/run_all_research.py \
  --prompt1 "{output_dir}/prompt_1_{angle}.md" \
  --prompt2 "{output_dir}/prompt_2_{angle}.md" \
  --output-dir "{output_dir}"
```

Run Track C inline in your own turn while `run_all_research.py` executes in the background. This maximizes parallelism — all 3 research tracks proceed simultaneously.

**Total research time**: 5-20 minutes typically.

### Graceful Degradation

| Scenario | Action |
|----------|--------|
| 1 of 3 tracks fails | Proceed with 2 successful tracks |
| 2 of 3 tracks fail | Proceed with 1 track + supplement with 4-6 additional WebSearch queries |
| All 3 tracks fail | Fall back to manual research: 15-20 WebSearch queries + deep WebFetch reads, compile manually |
| Missing GEMINI_API_KEY | Skip Track A, run only Tracks B+C |
| Missing PERPLEXITY_API_KEY | Skip Track B, run only Tracks A+C |
| Both API keys missing | Run only Track C with expanded scope (15+ searches) |

---

## Phase 4: Compile God Report

Merge all research outputs into a single comprehensive God Report.

Run the compilation script:
```bash
python scripts/compile_god_report.py \
  --research-dir "{output_dir}" \
  --output "{output_dir}/GOD_REPORT.md" \
  --topic "{skill_topic}"
```

The script:
- Reads all `research_*.md` files from the output directory
- Merges them using the template from `references/god-report-template.md`
- Organizes content by **theme**, not by source
- Deduplicates URLs across all sources
- Reports total word count

After compilation, **review the God Report** for quality:
- Verify it contains substantive findings from multiple sources
- Check that key themes are represented
- Note any gaps that need supplemental research
- If the report feels thin (< 3000 words), supplement with additional WebSearch research

---

## Phase 5: Create the Skill

Use the God Report as the knowledge foundation to create a world-class skill.

**Read and follow** the nested skill-creator instructions inline:

1. Read `nested-skills/skill-creator/INSTRUCTION.md` for the full skill creation workflow
2. Read `nested-skills/skill-creator/references/workflows.md` for workflow patterns
3. Read `nested-skills/skill-creator/references/output-patterns.md` for output patterns

**Execute the skill-creator workflow inline** (do NOT invoke via Skill tool):

1. **Understand** — The God Report provides the domain expertise. Identify what the skill needs to do and how it should work based on the research findings.

2. **Plan** — Design the skill structure: what goes in SKILL.md vs references vs scripts vs assets. Use the progressive disclosure patterns from the skill-creator references.

3. **Initialize** — Run the init script:
   ```bash
   python nested-skills/skill-creator/scripts/init_skill.py {skill-name} --path {output_dir}
   ```

4. **Edit** — Implement the skill contents using God Report knowledge:
   - Write SKILL.md with comprehensive workflow instructions
   - Create reference files for detailed domain knowledge
   - Write scripts for any deterministic operations
   - Include specific examples, data points, and practitioner insights from the research

5. **Package** — Package the completed skill:
   ```bash
   python nested-skills/skill-creator/scripts/package_skill.py {output_dir}/{skill-name}
   ```

6. **Validate** — Run quick validation:
   ```bash
   python nested-skills/skill-creator/scripts/quick_validate.py {output_dir}/{skill-name}
   ```

7. **Iterate** — Fix any validation issues and re-package.

### Quality Standards for the Created Skill

The God Report gives you deep domain expertise. Use it to ensure the skill:
- Contains **specific, actionable** instructions (not generic advice)
- Includes **real examples and data points** from the research
- References **practitioner insights** and common pitfalls
- Reflects **current SOTA** techniques and tools
- Handles **edge cases** identified in the research
- Uses **progressive disclosure** to manage context efficiently

---

## Notes

- **Timing**: The full workflow takes 15-45 minutes depending on research depth. Inform the user upfront.
- **Cost**: Gemini ~$2-5, Perplexity ~$1-3 per run. Claude's native research is free.
- **All scripts use Python stdlib only** — no pip install needed.
- **Nested skills are fully self-contained** in this skill's directory — no external dependencies.
