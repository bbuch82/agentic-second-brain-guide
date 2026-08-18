#!/usr/bin/env python3
"""Check chapter prose against the guide's voice and structure rules.

Code is not prose: fenced blocks and inline code spans are stripped before any
check runs. Without that, a shell flag like `-I` reads as a first-person
pronoun, and a check that cries wolf on correct content is a check that gets
ignored.

Usage: prose-check.py FILE [FILE...]
Exit:  0 all files pass, 1 at least one violation.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

FENCE = re.compile(r"^(`{3,})", re.MULTILINE)
INLINE_CODE = re.compile(r"`[^`\n]*`")
FIRST_PERSON = re.compile(r"\b(I|I'm|I've|I'd|I'll|my|mine|myself)\b")
EMOJI_HEADING = re.compile(
    r"^#{1,6}\s.*[\U0001F300-\U0001FAFF☀-➿]", re.MULTILINE
)


def strip_code(text: str) -> str:
    """Blank out fenced blocks and inline spans, preserving line numbering."""
    lines = text.split("\n")
    out: list[str] = []
    fence: str | None = None
    for line in lines:
        stripped = line.lstrip()
        if fence is None:
            m = FENCE.match(stripped)
            if m:
                fence = m.group(1)
                out.append("")
                continue
        else:
            # A closing fence is at least as long as the one that opened it.
            m = FENCE.match(stripped)
            if m and len(m.group(1)) >= len(fence):
                fence = None
            out.append("")
            continue
        out.append(INLINE_CODE.sub("", line))
    return "\n".join(out)


def check(path: Path) -> list[str]:
    raw = path.read_text(encoding="utf-8")
    prose = strip_code(raw)
    problems: list[str] = []

    for n, line in enumerate(prose.split("\n"), start=1):
        for m in FIRST_PERSON.finditer(line):
            problems.append(f"{path}:{n}: first person '{m.group(0)}'")

    for m in EMOJI_HEADING.finditer(prose):
        n = prose[: m.start()].count("\n") + 1
        problems.append(f"{path}:{n}: emoji in heading")

    # Structural rules apply to chapters only. A chapter is a NN_-prefixed file
    # inside a PART_ directory; everything else (material, indexes, the README)
    # has its own shape and must not be forced into this one.
    is_chapter = path.parent.name.startswith("PART_") and re.match(r"^\d\d_", path.name)
    if is_chapter:
        if not re.search(r"^> ", raw, re.MULTILINE):
            problems.append(f"{path}: no pull-quote (a line starting '> ')")
        if "**Read next:**" not in raw:
            problems.append(f"{path}: no 'Read next:' pointer")

    return problems


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__.strip(), file=sys.stderr)
        return 1
    all_problems: list[str] = []
    for arg in argv:
        all_problems.extend(check(Path(arg)))
    if all_problems:
        for p in all_problems:
            print(p, file=sys.stderr)
        print(f"\nprose-check: {len(all_problems)} problem(s)", file=sys.stderr)
        return 1
    print(f"prose-check: {len(argv)} file(s) clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
