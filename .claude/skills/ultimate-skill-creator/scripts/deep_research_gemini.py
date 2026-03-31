#!/usr/bin/env python3
"""
Gemini Deep Research Agent - Async Research with Polling

Submits a research prompt to Google's Gemini Deep Research Agent API,
polls for completion, and saves the resulting research report as markdown.

The Deep Research agent performs multi-step web research autonomously,
typically taking 5-20 minutes to complete. This script handles the full
lifecycle: task creation, progress polling, and result extraction.

Uses only Python stdlib (urllib, json) -- no external dependencies required.

Usage:
    python deep_research_gemini.py --prompt-file prompt.txt --output report.md
    python deep_research_gemini.py --prompt-file prompt.txt --output report.md --json
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API_BASE = "https://generativelanguage.googleapis.com/v1beta"
AGENT_ID = "deep-research-pro-preview-12-2025"
DEFAULT_POLL_INTERVAL = 10
MAX_POLL_DURATION = 3600  # 60 minutes


def create_research_task(prompt: str, api_key: str) -> dict:
    """Submit a research prompt to the Gemini Deep Research Agent.

    Args:
        prompt: The research prompt text.
        api_key: Gemini API key for authentication.

    Returns:
        The parsed JSON response containing the interaction ID.

    Raises:
        SystemExit: On HTTP or network errors.
    """
    url = f"{API_BASE}/interactions"
    payload = json.dumps({
        "input": prompt,
        "agent": AGENT_ID,
        "background": True,
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-goog-api-key": api_key,
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="replace")
        except Exception:
            pass
        print(f"ERROR: HTTP {e.code} creating research task: {e.reason}", file=sys.stderr)
        if body:
            print(f"Response: {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR: Network error creating research task: {e.reason}", file=sys.stderr)
        sys.exit(1)
    except TimeoutError:
        print("ERROR: Request timed out creating research task.", file=sys.stderr)
        sys.exit(1)


def poll_interaction(interaction_id: str, api_key: str) -> dict:
    """Poll the status of a research interaction.

    Args:
        interaction_id: The interaction ID returned by create_research_task.
        api_key: Gemini API key for authentication.

    Returns:
        The parsed JSON response with current interaction state.

    Raises:
        urllib.error.HTTPError: On HTTP errors.
        urllib.error.URLError: On network errors.
    """
    url = f"{API_BASE}/interactions/{interaction_id}"
    req = urllib.request.Request(
        url,
        headers={"x-goog-api-key": api_key},
        method="GET",
    )

    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def extract_report(interaction: dict) -> str:
    """Extract the research report text from a completed interaction.

    Args:
        interaction: The full interaction response dict.

    Returns:
        The research report text, or an empty string if not found.
    """
    outputs = interaction.get("outputs", [])
    if outputs:
        return outputs[-1].get("text", "")
    return ""


def run_deep_research(
    prompt: str,
    api_key: str,
    poll_interval: int = DEFAULT_POLL_INTERVAL,
) -> tuple:
    """Execute the full deep research workflow.

    Args:
        prompt: The research prompt text.
        api_key: Gemini API key.
        poll_interval: Seconds between status polls.

    Returns:
        A tuple of (report_text, duration_seconds).

    Raises:
        SystemExit: On fatal errors or timeout.
    """
    # Step 1: Create the research task
    print("Submitting research task to Gemini Deep Research Agent...", file=sys.stderr)
    response = create_research_task(prompt, api_key)

    interaction_id = response.get("id") or response.get("name", "").split("/")[-1]
    if not interaction_id:
        print("ERROR: No interaction ID in response.", file=sys.stderr)
        print(f"Full response: {json.dumps(response, indent=2)}", file=sys.stderr)
        sys.exit(1)

    print(f"Task created: {interaction_id}", file=sys.stderr)
    print("Polling for completion (this typically takes 5-20 minutes)...", file=sys.stderr)

    # Step 2: Poll until completed or failed
    start_time = time.time()
    last_status = ""

    while True:
        elapsed = time.time() - start_time
        if elapsed > MAX_POLL_DURATION:
            print(
                f"\nERROR: Polling timed out after {MAX_POLL_DURATION}s ({MAX_POLL_DURATION // 60} minutes).",
                file=sys.stderr,
            )
            sys.exit(1)

        try:
            interaction = poll_interaction(interaction_id, api_key)
        except urllib.error.HTTPError as e:
            body = ""
            try:
                body = e.read().decode("utf-8", errors="replace")
            except Exception:
                pass
            print(f"\nERROR: HTTP {e.code} polling task: {e.reason}", file=sys.stderr)
            if body:
                print(f"Response: {body}", file=sys.stderr)
            sys.exit(1)
        except urllib.error.URLError as e:
            # Transient network error -- retry on next poll
            print(f"\nWARN: Network error polling (will retry): {e.reason}", file=sys.stderr)
            time.sleep(poll_interval)
            continue
        except TimeoutError:
            print("\nWARN: Poll request timed out (will retry).", file=sys.stderr)
            time.sleep(poll_interval)
            continue

        status = interaction.get("status", "unknown")

        if status != last_status:
            minutes = int(elapsed) // 60
            seconds = int(elapsed) % 60
            print(f"\n[{minutes:02d}:{seconds:02d}] Status: {status}", file=sys.stderr, end="")
            last_status = status
        else:
            print(".", file=sys.stderr, end="", flush=True)

        if status == "completed":
            duration = time.time() - start_time
            print(file=sys.stderr)  # newline after dots
            report = extract_report(interaction)
            if not report:
                print("WARNING: Task completed but no output text found.", file=sys.stderr)
                print(f"Interaction keys: {list(interaction.keys())}", file=sys.stderr)
            return report, duration

        if status == "failed":
            print(file=sys.stderr)
            error_info = interaction.get("error", {})
            error_msg = error_info if isinstance(error_info, str) else json.dumps(error_info, indent=2)
            print(f"ERROR: Research task failed: {error_msg}", file=sys.stderr)
            sys.exit(1)

        time.sleep(poll_interval)


def main():
    parser = argparse.ArgumentParser(
        description="Run a deep research query via the Gemini Deep Research Agent API.",
        epilog=(
            "Examples:\n"
            "  %(prog)s --prompt-file research_question.txt --output report.md\n"
            "  %(prog)s --prompt-file prompt.txt --output out.md --json\n"
            "  %(prog)s --prompt-file prompt.txt --output out.md --poll-interval 15\n"
            "\n"
            "The research prompt file should contain the full research question or topic.\n"
            "Deep research typically takes 5-20 minutes to complete.\n"
            "Maximum polling duration is 60 minutes before timeout."
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
        help="Gemini API key. Defaults to GEMINI_API_KEY env var.",
    )
    parser.add_argument(
        "--poll-interval",
        type=int,
        default=DEFAULT_POLL_INTERVAL,
        help=f"Seconds between status polls (default: {DEFAULT_POLL_INTERVAL}).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Print JSON summary to stdout on completion.",
    )
    args = parser.parse_args()

    # Resolve API key
    api_key = args.api_key or os.environ.get("GEMINI_API_KEY", "")
    if not api_key:
        print(
            "ERROR: No API key provided. Use --api-key or set GEMINI_API_KEY env var.",
            file=sys.stderr,
        )
        sys.exit(1)

    # Read the prompt file
    prompt_path = Path(args.prompt_file)
    if not prompt_path.is_file():
        print(f"ERROR: Prompt file not found: {prompt_path}", file=sys.stderr)
        sys.exit(1)

    prompt = prompt_path.read_text(encoding="utf-8").strip()
    if not prompt:
        print("ERROR: Prompt file is empty.", file=sys.stderr)
        sys.exit(1)

    print(f"Research prompt ({len(prompt)} chars) loaded from: {prompt_path}", file=sys.stderr)

    # Run the deep research workflow
    report, duration = run_deep_research(prompt, api_key, args.poll_interval)

    # Save the report
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(report, encoding="utf-8")

    word_count = len(report.split())
    print(f"Report saved to: {output_path} ({word_count} words)", file=sys.stderr)
    print(f"Duration: {duration:.1f}s ({duration / 60:.1f} minutes)", file=sys.stderr)

    # JSON summary output
    if args.json_output:
        summary = {
            "success": True,
            "word_count": word_count,
            "duration_seconds": round(duration, 1),
            "output_path": str(output_path.resolve()),
        }
        print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
