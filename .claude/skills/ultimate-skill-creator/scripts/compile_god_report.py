#!/usr/bin/env python3
"""Compile multiple research outputs into a unified God Report.

Pure file I/O script (no API calls). Reads research markdown files, merges them
using a template, deduplicates URLs, and outputs a structured GOD_REPORT.md.
"""

import argparse
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


def extract_urls(text):
    """Extract all URLs from text — both markdown links and bare URLs.

    Returns a list of unique URLs preserving first-seen order.
    """
    urls = []
    seen = set()

    # Markdown links: [text](url)
    for match in re.finditer(r'\[([^\]]*)\]\(([^)]+)\)', text):
        url = match.group(2).strip()
        if url not in seen:
            seen.add(url)
            urls.append((match.group(1).strip(), url))

    # Bare URLs not already captured inside markdown links
    for match in re.finditer(r'(?<!\()https?://[^\s\)>\]]+', text):
        url = match.group(0).strip().rstrip('.,;:')
        if url not in seen:
            seen.add(url)
            urls.append(("", url))

    return urls


def count_words(text):
    """Count words in text."""
    return len(text.split())


def load_template(template_path):
    """Load the God Report template from disk.

    Args:
        template_path: Path to the template markdown file.

    Returns:
        Template string content.

    Raises:
        FileNotFoundError: If template does not exist.
    """
    if not template_path.exists():
        raise FileNotFoundError(f"Template not found: {template_path}")
    return template_path.read_text(encoding="utf-8")


def discover_research_files(research_dir):
    """Find all research_*.md files in a directory, sorted by name.

    Args:
        research_dir: Path to the directory to scan.

    Returns:
        List of Path objects.
    """
    files = sorted(research_dir.glob("research_*.md"))
    return files


def derive_source_label(filepath):
    """Derive a human-readable source label from a research filename.

    Examples:
        research_gemini.md   -> "Gemini"
        research_perplexity.md -> "Perplexity"
        research_claude.md   -> "Claude"
    """
    stem = filepath.stem  # e.g. "research_gemini"
    parts = stem.split("_", 1)
    if len(parts) > 1:
        return parts[1].replace("_", " ").title()
    return stem.title()


def compile_report(topic, research_files, template_path, start_time):
    """Compile the God Report from research files and template.

    Args:
        topic: Research topic string.
        research_files: List of Path objects pointing to research markdown files.
        template_path: Path to the god-report-template.md.
        start_time: Timestamp when compilation started.

    Returns:
        Compiled report string.
    """
    template = load_template(template_path)

    all_urls = []
    seen_urls = set()
    research_sections = []
    total_word_count = 0

    for filepath in research_files:
        if not filepath.exists():
            print(f"[WARNING] Research file not found, skipping: {filepath}", file=sys.stderr)
            continue

        content = filepath.read_text(encoding="utf-8")
        label = derive_source_label(filepath)
        words = count_words(content)
        total_word_count += words

        # Build section
        section = f"## Research: {label}\n"
        section += f"*Source file: `{filepath.name}` | {words:,} words*\n\n"
        section += content.strip()
        research_sections.append(section)

        # Collect URLs for deduplication
        for link_text, url in extract_urls(content):
            if url not in seen_urls:
                seen_urls.add(url)
                all_urls.append((link_text, url, label))

    # Build unified source list
    if all_urls:
        source_lines = []
        for i, (link_text, url, origin) in enumerate(all_urls, 1):
            display = link_text if link_text else url
            source_lines.append(f"{i}. [{display}]({url}) *(from {origin})*")
        unified_sources = "\n".join(source_lines)
    else:
        unified_sources = "*No sources found.*"

    duration = round(time.time() - start_time, 2)
    date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # Fill template placeholders
    report = template.replace("{topic}", topic)
    report = report.replace("{date}", date_str)
    report = report.replace("{source_count}", str(len(research_files)))
    report = report.replace("{word_count}", f"{total_word_count:,}")
    report = report.replace("{executive_summary_placeholder}",
                            "*Executive summary to be written after review of all research.*")
    report = report.replace("{research_sections}", "\n\n---\n\n".join(research_sections))
    report = report.replace("{unified_sources}", unified_sources)
    report = report.replace("{duration}", f"{duration}s")

    return report, total_word_count


def main():
    parser = argparse.ArgumentParser(
        description="Compile research outputs into a unified God Report."
    )
    parser.add_argument(
        "--research-dir", required=True,
        help="Directory containing research_*.md files.",
    )
    parser.add_argument(
        "--output", required=True,
        help="Output path for the compiled GOD_REPORT.md.",
    )
    parser.add_argument(
        "--topic", required=True,
        help="Research topic for the report header.",
    )
    parser.add_argument(
        "--files", nargs="*", default=None,
        help="Specific research files to include (instead of auto-discovery).",
    )
    args = parser.parse_args()

    start_time = time.time()

    research_dir = Path(args.research_dir).resolve()
    output_path = Path(args.output).resolve()

    # Template lives at <script_parent_parent>/references/god-report-template.md
    script_dir = Path(__file__).resolve().parent
    template_path = script_dir.parent / "references" / "god-report-template.md"

    # Determine which files to include
    if args.files:
        research_files = [Path(f).resolve() for f in args.files]
    else:
        if not research_dir.exists():
            print(f"[ERROR] Research directory not found: {research_dir}", file=sys.stderr)
            sys.exit(1)
        research_files = discover_research_files(research_dir)

    if not research_files:
        print("[ERROR] No research files found.", file=sys.stderr)
        sys.exit(1)

    print(f"=== God Report Compiler ===")
    print(f"Topic: {args.topic}")
    print(f"Research files: {len(research_files)}")
    for f in research_files:
        print(f"  - {f.name}")
    print()

    report, total_words = compile_report(
        topic=args.topic,
        research_files=research_files,
        template_path=template_path,
        start_time=start_time,
    )

    # Write output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(report, encoding="utf-8")

    duration = round(time.time() - start_time, 2)
    print(f"[DONE] God Report written to: {output_path}")
    print(f"  Total words: {total_words:,}")
    print(f"  Duration: {duration}s")


if __name__ == "__main__":
    main()
