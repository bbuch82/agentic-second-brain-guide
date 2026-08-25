#!/usr/bin/env python3
"""Resolve every relative Markdown link in this repository.

Links inside fenced code blocks are ignored. A link in a fence is example text a
reader pastes, not a link to follow — and without this rule the guide's own code
samples produce a wall of false positives, which is how a check gets disabled.

A target that does not exist is a broken link and fails, unless it is listed in
tools/pending-links.txt.

Usage: link-check.py [--root DIR]
Exit:  0 every link resolves or is allowlisted, 1 otherwise.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

LINK = re.compile(r"\]\(\s*([^)\s]+)")
FENCE = re.compile(r"^(`{3,})")
SKIP_PREFIXES = ("http://", "https://", "mailto:", "tel:", "#")


def markdown_files(root: Path) -> list[Path]:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "*.md"],
            capture_output=True, text=True, check=True,
        ).stdout.split()
        if out:
            return [root / p for p in out]
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return sorted(root.rglob("*.md"))


def prose_lines(text: str):
    """Yield (line_number, line) for lines outside fenced code blocks."""
    fence: str | None = None
    for n, line in enumerate(text.split("\n"), start=1):
        m = FENCE.match(line.lstrip())
        if fence is None:
            if m:
                fence = m.group(1)
                continue
            yield n, line
        else:
            if m and len(m.group(1)) >= len(fence):
                fence = None


def pending(root: Path) -> set[str]:
    path = root / "tools" / "pending-links.txt"
    if not path.is_file():
        return set()
    entries = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            entries.add(line)
    return entries


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    allowed = pending(root)
    broken: list[tuple[str, int, str]] = []
    checked = 0

    for path in markdown_files(root):
        if not path.is_file():
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno, line in prose_lines(text):
            for target in LINK.findall(line):
                if target.startswith(SKIP_PREFIXES):
                    continue
                target = target.split("#", 1)[0]
                if not target:
                    continue
                resolved = (
                    root / target.lstrip("/") if target.startswith("/")
                    else path.parent / target
                )
                resolved = Path(os.path.normpath(resolved))
                checked += 1
                if resolved.exists():
                    continue
                try:
                    rel = resolved.relative_to(root).as_posix()
                except ValueError:
                    rel = resolved.as_posix()
                if rel in allowed:
                    continue
                broken.append((path.relative_to(root).as_posix(), lineno, target))

    if broken:
        print(f"link-check: {len(broken)} broken link(s)", file=sys.stderr)
        for src, lineno, target in broken:
            print(f"  {src}:{lineno} -> {target}", file=sys.stderr)
        print(
            "\nlink-check: fix the link, or add the target to "
            "tools/pending-links.txt if it is scheduled for later.",
            file=sys.stderr,
        )
        return 1

    print(f"link-check: {checked} link(s) resolve; {len(allowed)} pending target(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
