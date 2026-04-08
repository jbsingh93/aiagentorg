---
name: query-knowledge
description: "Query the org-wide knowledge base using 3-tier progressive disclosure. Scans index keywords/descriptions, reads article TOCs to confirm relevance, then reads full content only for confirmed matches. Optionally files the answer as a Q&A article."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "<question> [--file-back] (optional — save answer as Q&A article)"
---

# Query Knowledge — 3-Tier Progressive Disclosure Retrieval

This skill queries the org-wide knowledge base using the same progressive disclosure pattern that Claude Code uses for skill loading — cheap metadata first, expensive content only when confirmed relevant.

## The 3 Tiers

| Tier | What | Cost | Purpose |
|------|------|------|---------|
| **1. Index Scan** | Title + Keywords + Description | ~100 tokens/article | Shortlist candidates by keyword/topic match |
| **2. TOC Scan** | Frontmatter + Table of Contents | ~30-50 tokens/article | Confirm relevance, identify target sections |
| **3. Full Read** | Complete article content | Full article | Read confirmed matches, synthesize answer |

## Execution

### Step 1: Parse the Question

The question is in `$ARGUMENTS`. If `--file-back` is present, the answer will be saved.

### Step 2: TIER 1 — Scan Index (Title + Keywords + Description)

```
Read org/knowledge/index.md
```

Scan the three index tables (Concepts, Connections, Q&A). For each article:
- Check if any **keywords** in the Keywords column overlap with terms in the question (including synonyms and related concepts)
- Check if the **description** addresses the question's topic
- Check if the **title** is directly relevant
- For connections: check if the **Connects** column links concepts relevant to the question

**Shortlist 5-15 candidate articles.** Err on the side of including borderline matches — Tier 2 is cheap and will filter further. Note WHY each candidate was shortlisted (which keywords matched).

### Step 3: TIER 2 — Read TOC of Candidates

For each shortlisted article, read ONLY the frontmatter and Table of Contents — NOT the full article. The first ~25-30 lines contain everything needed:

```
Read org/knowledge/concepts/{slug}.md (limit: 30)
```

From the Table of Contents, evaluate:
- Do the section titles address the question?
- Which specific sections would contain the answer?
- Does the full `description` in frontmatter confirm relevance?

**Narrow to 3-7 confirmed articles.** For each, note which sections are relevant. Drop articles whose TOC shows no relevant sections.

### Step 4: TIER 3 — Read Full Content of Confirmed Matches

Read confirmed articles in full:

```
Read org/knowledge/concepts/{slug}.md
Read org/knowledge/connections/{slug}.md
```

If only specific sections are needed and the article is long (50+ lines), use offset/limit to read just the relevant sections identified in Tier 2.

### Step 5: Synthesize Answer

Produce a clear, thorough answer that:
- **Directly addresses the question**
- **Cites sources** using markdown links: `[Article Title](concepts/slug.md)`
- **References specific sections** when relevant: "According to the [Timeline and Milestones section](concepts/q2-seo-strategy.md)..."
- **Distinguishes facts from inferences** — if you're connecting dots across articles, say so
- **Acknowledges gaps** — if the knowledge base doesn't fully cover the topic, say so honestly
- **Uses the org's language** as configured in `org/config.md`

### Step 6: File Back (Optional)

If `--file-back` was specified, save the answer as a Q&A article:

1. Create a Q&A article at `org/knowledge/qa/{slugified-question}.md`:

```markdown
---
title: {Question as title}
keywords: [{5-10 relevant keywords}]
description: "{One-sentence answer summary, <200 chars}"
question: "{The original question}"
consulted:
  - concepts/{article-1}.md
  - concepts/{article-2}.md
filed: {YYYY-MM-DD}
---

# {Question}

## Table of Contents
1. [Answer](#answer) — {one-line annotation}
2. [Sources Consulted](#sources-consulted) — Articles referenced

## Answer
{The synthesized answer with citations}

## Sources Consulted
- [{Article 1}](concepts/{slug-1}.md) — {what this article contributed}
- [{Article 2}](concepts/{slug-2}.md) — {what this article contributed}
```

2. Update `org/knowledge/index.md` — add a row to the Q&A table
3. Append to `org/knowledge/log.md`:
   ```
   ## [{timestamp}] Query (filed)
   - Question: {question}
   - Consulted: {list of articles}
   - Filed to: qa/{slug}.md
   ```

## Access Control

- **All agents** with `org/knowledge/` in their `access_read` can use this skill
- **Only board/CAO** can use `--file-back` (creates files in the knowledge base)
- The existing `data-access-check.sh` hook enforces read access to knowledge articles

## Tips for Agents

- **Tier 1 is often enough** — scanning the index keywords and descriptions may directly answer simple factual questions without reading any articles
- **Use Grep for keyword searches**: `Grep "keyword" org/knowledge/index.md` to quickly find matching articles in the index
- **Q&A articles are reusable** — check the Q&A table in the index before asking a question that may have been answered before
- **Check the index first** before running a full query — your answer might be in a single article

## Important Rules

- **Never modify** concept or connection articles during a query — queries are read-only
- **File-back answers** must cite at least one source article and include keywords + description + TOC
- **If knowledge base is empty**, say so clearly — don't fabricate knowledge
- **Follow master-gpt-prompter principles** when synthesizing answers
- **Always use the 3-tier process** — never skip to reading full articles without scanning the index first
