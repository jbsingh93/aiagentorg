#!/usr/bin/env python3
"""
Perplexity Deep Research Script

Calls Perplexity's sonar-deep-research model to perform comprehensive,
well-sourced research on a given topic. Reads the research prompt from
a file, sends it to the API, and saves the resulting markdown report
with citations.

Cost reference (sonar-deep-research):
  - Input:    $2  per 1M tokens
  - Output:   $8  per 1M tokens
  - Searches: $5  per 1K searches
  - Context:  128K tokens

Usage:
  python deep_research_perplexity.py --prompt-file prompt.txt --output report.md
  python deep_research_perplexity.py --prompt-file prompt.txt --output report.md --json
  python deep_research_perplexity.py --prompt-file prompt.txt --output report.md --api-key sk-...
"""

import argparse
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API_ENDPOINT = "https://api.perplexity.ai/chat/completions"
MODEL = "sonar-deep-research"
TIMEOUT_SECONDS = 600
MAX_RETRIES = 3
RETRY_DELAYS = [15, 30, 60]

SYSTEM_PROMPT = (
    "You are a deep research assistant. Provide comprehensive, well-sourced "
    "analysis. Focus on primary sources, practitioner experiences, peer-reviewed "
    "papers, and community discussions. Avoid AI-generated blog content."
)


def build_request_body(prompt: str) -> bytes:
    """Build the JSON request body for the Perplexity API."""
    payload = {
        "model": MODEL,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt},
        ],
    }
    return json.dumps(payload).encode("utf-8")


def call_api(api_key: str, prompt: str) -> dict:
    """
    Send the research prompt to Perplexity sonar-deep-research.

    Retries up to MAX_RETRIES times on HTTP 429 (rate limit) with
    exponential backoff delays of 15s, 30s, 60s.

    Returns the parsed JSON response dict.
    """
    body = build_request_body(prompt)
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    # Create SSL context for HTTPS
    ssl_context = ssl.create_default_context()

    req = urllib.request.Request(
        API_ENDPOINT, data=body, headers=headers, method="POST"
    )

    last_error = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            with urllib.request.urlopen(
                req, timeout=TIMEOUT_SECONDS, context=ssl_context
            ) as resp:
                raw = resp.read().decode("utf-8")
                return json.loads(raw)

        except urllib.error.HTTPError as e:
            error_body = ""
            try:
                error_body = e.read().decode("utf-8", errors="replace")
            except Exception:
                pass

            if e.code == 429 and attempt < MAX_RETRIES:
                delay = RETRY_DELAYS[attempt]
                print(
                    f"Rate limited (429). Retrying in {delay}s "
                    f"(attempt {attempt + 1}/{MAX_RETRIES})...",
                    file=sys.stderr,
                )
                time.sleep(delay)
                last_error = e
                # Rebuild the request since the body stream was consumed
                req = urllib.request.Request(
                    API_ENDPOINT, data=body, headers=headers, method="POST"
                )
                continue

            print(
                f"HTTP {e.code} error: {e.reason}\n{error_body}",
                file=sys.stderr,
            )
            sys.exit(1)

        except urllib.error.URLError as e:
            print(f"Network error: {e.reason}", file=sys.stderr)
            sys.exit(1)

        except TimeoutError:
            print(
                f"Request timed out after {TIMEOUT_SECONDS}s. "
                "Deep research can take several minutes; consider retrying.",
                file=sys.stderr,
            )
            sys.exit(1)

    # Exhausted all retries on 429
    print(
        f"Exhausted {MAX_RETRIES} retries due to rate limiting.",
        file=sys.stderr,
    )
    sys.exit(1)


def parse_response(data: dict) -> tuple:
    """
    Extract content, citations, and token usage from the API response.

    Returns (content, citations, usage) where:
      - content: str  (the research report markdown)
      - citations: list[str]  (URLs referenced)
      - usage: dict  (token counts)
    """
    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        print("Unexpected API response structure: missing content.", file=sys.stderr)
        print(f"Response: {json.dumps(data, indent=2)[:2000]}", file=sys.stderr)
        sys.exit(1)

    citations = data.get("citations", [])
    usage = data.get("usage", {})

    return content, citations, usage


def format_report(content: str, citations: list) -> str:
    """
    Combine the research content with a citations section into a
    full markdown report.
    """
    parts = [content.strip()]

    if citations:
        parts.append("\n\n---\n\n## Citations\n")
        for i, url in enumerate(citations, 1):
            parts.append(f"{i}. {url}")

    parts.append("")  # trailing newline
    return "\n".join(parts)


def main():
    parser = argparse.ArgumentParser(
        description="Run deep research via Perplexity sonar-deep-research model.",
        epilog=(
            "Examples:\n"
            "  %(prog)s --prompt-file prompt.txt --output report.md\n"
            "  %(prog)s --prompt-file prompt.txt --output report.md --json\n"
            "  %(prog)s --prompt-file prompt.txt --output report.md --api-key sk-...\n"
            "\n"
            "The research prompt is read from the file specified by --prompt-file.\n"
            "The full report (with citations) is saved to --output.\n"
            "Use --json to also print a JSON summary to stdout."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--prompt-file",
        required=True,
        help="Path to file containing the research prompt.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Path to save the markdown research report.",
    )
    parser.add_argument(
        "--api-key",
        default=None,
        help="Perplexity API key. Defaults to PERPLEXITY_API_KEY env var.",
    )
    parser.add_argument(
        "--json",
        dest="json_output",
        action="store_true",
        default=False,
        help="Print JSON summary to stdout.",
    )
    args = parser.parse_args()

    # Resolve API key
    api_key = args.api_key or os.environ.get("PERPLEXITY_API_KEY", "")
    if not api_key:
        print(
            "Error: No API key provided. Use --api-key or set PERPLEXITY_API_KEY.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Read prompt file
    prompt_path = Path(args.prompt_file)
    if not prompt_path.is_file():
        print(f"Error: Prompt file not found: {prompt_path}", file=sys.stderr)
        sys.exit(1)

    prompt = prompt_path.read_text(encoding="utf-8").strip()
    if not prompt:
        print("Error: Prompt file is empty.", file=sys.stderr)
        sys.exit(1)

    # Call the API
    start_time = time.time()
    print(f"Sending research prompt to {MODEL}...", file=sys.stderr)
    print(f"(timeout: {TIMEOUT_SECONDS}s, this may take several minutes)", file=sys.stderr)

    data = call_api(api_key, prompt)
    duration = time.time() - start_time

    # Parse response
    content, citations, usage = parse_response(data)

    # Build and save report
    report = format_report(content, citations)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(report, encoding="utf-8")

    word_count = len(content.split())
    citation_count = len(citations)

    print(f"Report saved to {output_path} ({word_count} words, {citation_count} citations)", file=sys.stderr)
    print(f"Completed in {duration:.1f}s", file=sys.stderr)

    # JSON summary
    summary = {
        "success": True,
        "word_count": word_count,
        "citation_count": citation_count,
        "duration_seconds": round(duration, 2),
        "output_path": str(output_path),
        "token_usage": {
            "completion_tokens": usage.get("completion_tokens"),
            "citation_tokens": usage.get("citation_tokens"),
            "reasoning_tokens": usage.get("reasoning_tokens"),
        },
    }

    if args.json_output:
        print(json.dumps(summary, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
