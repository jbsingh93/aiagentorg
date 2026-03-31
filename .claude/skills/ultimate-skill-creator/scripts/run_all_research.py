#!/usr/bin/env python3
"""Parallel orchestrator that runs Gemini and Perplexity research scripts concurrently.

Runs Track A (Gemini) and Track B (Perplexity) as subprocesses in parallel using
ThreadPoolExecutor. Claude's own research (Track C) runs separately inline and is
NOT part of this orchestrator.

Outputs a JSON summary to stdout with results from both scripts.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

OVERALL_TIMEOUT = 1800  # 30 minutes


def run_research_script(script_path, prompt_file, output_file, track_label):
    """Run a single research script as a subprocess.

    Args:
        script_path: Path to the Python research script.
        prompt_file: Path to the prompt file to pass to the script.
        output_file: Path where the script should write its output.
        track_label: Human-readable label (e.g. "Track A - Gemini").

    Returns:
        dict with keys: track, success, output_file, word_count, source_count,
        duration, error.
    """
    start = time.time()
    result = {
        "track": track_label,
        "success": False,
        "output_file": str(output_file),
        "word_count": 0,
        "source_count": 0,
        "duration": 0.0,
        "error": None,
    }

    try:
        print(f"[START] {track_label}: running {Path(script_path).name}...")
        proc = subprocess.run(
            [
                sys.executable,
                str(script_path),
                "--prompt-file", str(prompt_file),
                "--output", str(output_file),
                "--json",
            ],
            capture_output=True,
            text=True,
            timeout=OVERALL_TIMEOUT,
            env=os.environ.copy(),
        )

        duration = time.time() - start
        result["duration"] = round(duration, 2)

        if proc.returncode != 0:
            result["error"] = proc.stderr.strip() or f"Exit code {proc.returncode}"
            print(f"[FAIL] {track_label}: finished in {duration:.1f}s — {result['error']}")
            return result

        # Try to parse JSON output from the script for metadata
        if proc.stdout.strip():
            try:
                script_output = json.loads(proc.stdout.strip())
                result["word_count"] = script_output.get("word_count", 0)
                result["source_count"] = script_output.get("source_count", 0)
            except json.JSONDecodeError:
                pass

        # If no JSON metadata, try reading the output file directly
        if result["word_count"] == 0 and Path(output_file).exists():
            content = Path(output_file).read_text(encoding="utf-8")
            result["word_count"] = len(content.split())

        result["success"] = True
        print(
            f"[DONE] {track_label}: finished in {duration:.1f}s — "
            f"{result['word_count']} words, {result['source_count']} sources"
        )

    except subprocess.TimeoutExpired:
        result["duration"] = round(time.time() - start, 2)
        result["error"] = f"Timed out after {OVERALL_TIMEOUT}s"
        print(f"[TIMEOUT] {track_label}: {result['error']}")
    except FileNotFoundError as exc:
        result["duration"] = round(time.time() - start, 2)
        result["error"] = f"Script not found: {exc}"
        print(f"[ERROR] {track_label}: {result['error']}")
    except Exception as exc:
        result["duration"] = round(time.time() - start, 2)
        result["error"] = str(exc)
        print(f"[ERROR] {track_label}: {result['error']}")

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Run Gemini and Perplexity research scripts in parallel."
    )
    parser.add_argument(
        "--prompt1", required=True,
        help="Path to prompt file for Gemini (Track A).",
    )
    parser.add_argument(
        "--prompt2", required=True,
        help="Path to prompt file for Perplexity (Track B).",
    )
    parser.add_argument(
        "--output-dir", required=True,
        help="Directory to save research outputs.",
    )
    args = parser.parse_args()

    # Resolve paths
    prompt1 = Path(args.prompt1).resolve()
    prompt2 = Path(args.prompt2).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    # Scripts live in the same directory as this orchestrator
    scripts_dir = Path(__file__).resolve().parent
    gemini_script = scripts_dir / "deep_research_gemini.py"
    perplexity_script = scripts_dir / "deep_research_perplexity.py"

    output_a = output_dir / "research_gemini.md"
    output_b = output_dir / "research_perplexity.md"

    # Validate inputs
    for label, path in [("prompt1", prompt1), ("prompt2", prompt2)]:
        if not path.exists():
            print(f"[ERROR] {label} not found: {path}", file=sys.stderr)
            sys.exit(1)

    for label, path in [("Gemini script", gemini_script), ("Perplexity script", perplexity_script)]:
        if not path.exists():
            print(f"[WARNING] {label} not found: {path}", file=sys.stderr)

    print(f"=== Parallel Research Orchestrator ===")
    print(f"Output directory: {output_dir}")
    print(f"Track A (Gemini):    {gemini_script.name}")
    print(f"Track B (Perplexity): {perplexity_script.name}")
    print()

    overall_start = time.time()
    results = []

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = {
            executor.submit(
                run_research_script,
                gemini_script, prompt1, output_a, "Track A - Gemini",
            ): "Track A",
            executor.submit(
                run_research_script,
                perplexity_script, prompt2, output_b, "Track B - Perplexity",
            ): "Track B",
        }

        for future in as_completed(futures):
            track = futures[future]
            try:
                result = future.result()
                results.append(result)
            except Exception as exc:
                results.append({
                    "track": track,
                    "success": False,
                    "output_file": None,
                    "word_count": 0,
                    "source_count": 0,
                    "duration": 0.0,
                    "error": str(exc),
                })

    overall_duration = round(time.time() - overall_start, 2)

    # Build summary
    summary = {
        "overall_duration": overall_duration,
        "tracks": sorted(results, key=lambda r: r["track"]),
        "all_success": all(r["success"] for r in results),
        "total_word_count": sum(r["word_count"] for r in results),
        "total_source_count": sum(r["source_count"] for r in results),
    }

    print()
    print(f"=== Research Complete ({overall_duration:.1f}s) ===")
    for r in summary["tracks"]:
        status = "OK" if r["success"] else "FAILED"
        print(f"  {r['track']}: {status} — {r['word_count']} words, {r['source_count']} sources")
    print(f"  Total: {summary['total_word_count']} words, {summary['total_source_count']} sources")
    print()

    # Output JSON summary to stdout
    print(json.dumps(summary, indent=2))

    sys.exit(0 if summary["all_success"] else 1)


if __name__ == "__main__":
    main()
