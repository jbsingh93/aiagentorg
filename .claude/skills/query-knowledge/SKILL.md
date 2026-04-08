---
name: query-knowledge
description: "Query the org-wide knowledge base. Reads the index, identifies relevant articles, and synthesizes an answer with citations. Optionally files the answer as a Q&A article for future reference."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "<question> [--file-back] (optional — save answer as Q&A article)"
---

# Query Knowledge — Knowledge Base Query Engine

This skill queries the org-wide knowledge base to answer questions by reading and synthesizing information from compiled knowledge articles.

## How It Works

At the scale of an org knowledge base (50-500 articles), LLM judgment outperforms vector similarity for selecting relevant articles. The approach:

1. Read the full index to understand what knowledge is available
2. Identify 3-10 articles relevant to the question
3. Read those articles in full
4. Synthesize a comprehensive answer with citations
5. Optionally file the answer as a Q&A article

No vector database, no RAG infrastructure — just markdown files and reasoning.

## Execution

### Step 1: Parse the Question

The question is in `$ARGUMENTS`. If `--file-back` is present, the answer will be saved.

### Step 2: Read the Index

```
Read org/knowledge/index.md
```

Scan the index table to understand all available articles and their summaries.

### Step 3: Identify Relevant Articles

Based on the question and the index summaries, identify 3-10 articles that are likely to contain relevant information. Consider:
- Direct topic matches (question mentions SEO → read SEO articles)
- Related concepts (question about marketing ROI → read strategy + budget articles)
- Connection articles (cross-cutting insights that link relevant concepts)
- Q&A articles (previously answered similar questions)

### Step 4: Read Selected Articles

Read each selected article in full:
```
Read org/knowledge/concepts/{slug}.md
Read org/knowledge/connections/{slug}.md
```

### Step 5: Synthesize Answer

Produce a clear, thorough answer that:
- **Directly addresses the question**
- **Cites sources** using markdown links: `[Article Title](concepts/slug.md)`
- **Distinguishes facts from inferences** — if you're connecting dots across articles, say so
- **Acknowledges gaps** — if the knowledge base doesn't fully cover the topic, say so honestly
- **Uses the org's language** as configured in `org/config.md`

### Step 6: File Back (Optional)

If `--file-back` was specified, save the answer:

1. Create a Q&A article at `org/knowledge/qa/{slugified-question}.md`:

```markdown
---
title: {Question as title}
question: "{The original question}"
consulted:
  - concepts/{article-1}
  - concepts/{article-2}
filed: {YYYY-MM-DD}
---

# {Question}

{The synthesized answer with citations}
```

2. Update `org/knowledge/index.md` with a new row for this Q&A article
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

- **Check the index first** before running a full query — your answer might be in a single article
- **Use Grep for keyword searches**: `grep -rl "keyword" org/knowledge/concepts/` to find articles quickly
- **Q&A articles are reusable** — check `org/knowledge/qa/` before asking a question that may have been answered before

## Important Rules

- **Never modify** concept or connection articles during a query — queries are read-only
- **File-back answers** must cite at least one source article
- **If knowledge base is empty**, say so clearly — don't fabricate knowledge
- **Follow master-gpt-prompter principles** when synthesizing answers
