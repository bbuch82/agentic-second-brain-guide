# Guide v2 — Stage 1 Implementation Plan (Foundation)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the foundation of guide v2 — the safety tooling that makes publishing safe, the v1 archive that preserves inbound links, the canonical architecture diagram, and a README that stands alone as the document's front door.

**Architecture:** Two verification tools run before every commit and at the end of every stage: a denylist scanner whose wordlist lives outside the repository, and an internal-link resolver with a shrinking allowlist of not-yet-written targets. v1 moves wholesale into `v1/` so its internal links keep resolving, and eleven short stubs take its original filenames so external links survive. The six part directories get real index files in this stage; their chapters arrive in stages 2–4.

**Tech Stack:** Markdown, bash, Python 3 (standard library only), git.

**Spec:** `docs/specs/2026-08-17-guide-v2-design.md`

**Repository:** `~/CCProjects/agentic-second-brain-guide`, branch `v2`

---

## Global Constraints

Copied verbatim from the spec. Every task's requirements implicitly include this section.

- **Language:** English throughout — prose, code comments, chart labels, file names.
- **Voice:** Third person and second person only. No first-person singular. No persona. No fictional character.
- **Privacy — prohibited in every shipped file:** author name and variants, family members, colleagues, any real person; employers, clients, mandates, brand and product names from the author's work; real note text, real area names, real project names, real meeting content; server hostnames, private repository names, absolute local paths, launch-agent identifiers; email addresses, chat IDs, bot tokens, domains, API keys; body weight, VO2max, resting heart rate, sleep values, any health reading; habit categories touching partnership, sexuality, conflict, or children; screenshots of any kind.
- **Privacy — permitted:** rounded aggregate system metrics phrased as properties of the system, not facts about a person; named third-party products (OpenClaw, Claude Code, Obsidian, Dataview, Syncthing, Hetzner, Garmin, Docker); de-identified failure narratives.
- **Numbers:** every figure confirmed with the repository owner before it ships; none inferred; none stated more precisely than the nearest round number that is still true.
- **Placeholders in examples:** `Acme`, `<Area>`, `Doe_Jane`, `<baseline>`, `<target>`, `{{PLACEHOLDER}}`.
- **Style:** no emoji in headings; tables over paragraphs for mappings; complete runnable code blocks, never elided; one blockquote pull-quote per chapter; every chapter opens with the problem it solves in two sentences and ends with what to read next.
- **Denylist location:** `$ASBG_DENYLIST`, defaulting to `~/.config/asbg/denylist.txt`. Never committed.
- **Chapter numbering:** continuous 01–27 across the six parts.

### Owner inputs required before Task 7

Two figures cannot be derived and must be supplied by the repository owner. Task 7 is blocked until they are:

- `MONTHS_RUNNING` — months of continuous operation of the autonomous layer.
- `MONTHLY_COST` — actual monthly running cost in EUR, rounded.

Figures already derived and approved for use, rounded:

| Figure | Value to publish |
|---|---|
| Markdown notes | `~7,800` |
| Files total | `~11,000` |
| Skills | `27` |
| Skills with an implementation | `14` |
| Watchdog health checks | `13` |
| Days of sensor history | `~140` |
| Dashboard query blocks | `14` |

---

## File Structure

| Path | Responsibility |
|---|---|
| `tools/privacy-check.sh` | Fails if any scanned file contains a denylisted string. Fails closed when the denylist is absent. |
| `tools/denylist.example.txt` | Category comments and generic patterns only. Contains no real term. |
| `tools/privacy-check.ignore` | Path prefixes exempt from the scan, with a written reason per line. |
| `tools/link-check.py` | Resolves every relative Markdown link in tracked `.md` files. |
| `tools/pending-links.txt` | Link targets permitted not to exist yet. Must be empty before publication. |
| `tools/install-hooks.sh` | Points `core.hooksPath` at `.githooks`. |
| `.githooks/pre-commit` | Runs both checkers against staged files. |
| `v1/` | v1 verbatim: eleven chapters, `README.md`, `assets/`, `examples/`. |
| `01_SERVER_SETUP.md` … `11_ADVANCED_TIPS.md` | Eleven redirect stubs at v1's original filenames. |
| `assets/architecture.md` | Canonical diagrams for v2. The two-layer diagram lives here and is inlined in the README. |
| `PART_1_PRINCIPLES/README.md` … `PART_6_OPERATE/README.md` | Six part indexes: what the part covers, its chapters, and why it exists. |
| `README.md` | The front door. Thesis, numbers, diagram, three reading paths, quickstart, contents. |
| `CHANGELOG.md` | What changed from v1 to v2 and why. |

---

## Task 1: Privacy check tooling

**Files:**
- Create: `tools/privacy-check.sh`
- Create: `tools/denylist.example.txt`
- Create: `tools/privacy-check.ignore`
- Create: `tools/install-hooks.sh`
- Create: `.githooks/pre-commit`

**Interfaces:**
- Consumes: nothing.
- Produces: `tools/privacy-check.sh [PATH...]` — scans the given paths, or all git-tracked files when called with no arguments. Exit `0` clean, `1` denylist hit, `2` denylist file missing or unreadable. Reads the denylist from `$ASBG_DENYLIST`, defaulting to `$HOME/.config/asbg/denylist.txt`.

- [ ] **Step 1: Write the failing test**

Create `tools/test-privacy-check.sh`:

```bash
#!/usr/bin/env bash
# Tests for privacy-check.sh. Run from anywhere: bash tools/test-privacy-check.sh
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/privacy-check.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok   - $name"
    pass=$((pass + 1))
  else
    echo "FAIL - $name (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

printf 'acme-forbidden-term\n' > "$TMP/denylist.txt"
printf 'This line mentions acme-forbidden-term inline.\n' > "$TMP/dirty.md"
printf 'This line is entirely harmless.\n' > "$TMP/clean.md"
printf 'A term like acme-forbidden-termination should not match.\n' > "$TMP/boundary.md"

ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "clean file passes" 0 $?

ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/dirty.md" >/dev/null 2>&1
check "denylisted term is blocked" 1 $?

ASBG_DENYLIST="$TMP/denylist.txt" bash "$CHECK" "$TMP/boundary.md" >/dev/null 2>&1
check "word boundary is respected" 0 $?

ASBG_DENYLIST="$TMP/does-not-exist.txt" bash "$CHECK" "$TMP/clean.md" >/dev/null 2>&1
check "missing denylist fails closed" 2 $?

printf 're:[a-z]+@[a-z]+\.[a-z]{2,}\n' > "$TMP/regex-denylist.txt"
printf 'Contact someone@example.org for details.\n' > "$TMP/email.md"
ASBG_DENYLIST="$TMP/regex-denylist.txt" bash "$CHECK" "$TMP/email.md" >/dev/null 2>&1
check "re: rules are treated as regex" 1 $?

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tools/test-privacy-check.sh`
Expected: every case reports `FAIL`, because `tools/privacy-check.sh` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `tools/privacy-check.sh`:

```bash
#!/usr/bin/env bash
# Blocks publication of denylisted strings.
#
# The denylist contains exactly the strings that must never be published, so it
# is deliberately NOT stored in this repository. Point ASBG_DENYLIST at it, or
# place it at ~/.config/asbg/denylist.txt. See tools/denylist.example.txt for
# the format.
#
# Usage: privacy-check.sh [PATH...]
#   With paths: scans those paths.
#   Without:    scans every git-tracked file, minus tools/privacy-check.ignore.
# Exit: 0 clean, 1 denylist hit, 2 denylist unavailable.
set -uo pipefail

DENYLIST="${ASBG_DENYLIST:-$HOME/.config/asbg/denylist.txt}"

if [[ ! -r "$DENYLIST" ]]; then
  echo "privacy-check: denylist not readable at $DENYLIST" >&2
  echo "privacy-check: create it or set ASBG_DENYLIST; see tools/denylist.example.txt" >&2
  exit 2
fi

files=()
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  root="$(git rev-parse --show-toplevel)" || exit 2
  cd "$root" || exit 2
  ignore="tools/privacy-check.ignore"
  prefixes=()
  if [[ -r "$ignore" ]]; then
    while IFS= read -r line; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -n "$line" ]] && prefixes+=("$line")
    done < "$ignore"
  fi
  while IFS= read -r f; do
    skip=0
    for p in ${prefixes[@]+"${prefixes[@]}"}; do
      if [[ "$f" == "$p"* ]]; then skip=1; break; fi
    done
    [[ $skip -eq 0 ]] && files+=("$f")
  done < <(git ls-files)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "privacy-check: no files to scan"
  exit 0
fi

# Word-boundary syntax differs between greps: GNU uses \b, BSD uses [[:<:]], and
# a given machine may have either behind the name `grep` (ugrep, for one, accepts
# \b but not [[:<:]]). Each candidate is proven by a positive and a negative
# probe before use. If neither can be proven, fall back to substring matching:
# over-matching costs a false positive, while under-matching would let a
# denylisted term through silently, and this is a safety gate.
detect_boundary_style() {
  if grep -qE '\bword\b' <<< 'a word here' 2>/dev/null \
     && ! grep -qE '\bword\b' <<< 'a wordy here' 2>/dev/null; then
    echo gnu; return
  fi
  if grep -qE '[[:<:]]word[[:>:]]' <<< 'a word here' 2>/dev/null \
     && ! grep -qE '[[:<:]]word[[:>:]]' <<< 'a wordy here' 2>/dev/null; then
    echo bsd; return
  fi
  echo none
}

BOUNDARY_STYLE="$(detect_boundary_style)"
if [[ "$BOUNDARY_STYLE" == none ]]; then
  echo "privacy-check: this grep has no provable word-boundary support; matching substrings instead (expect false positives)" >&2
fi

boundary_pattern() {
  case "$BOUNDARY_STYLE" in
    gnu)  printf '\\b%s\\b' "$1" ;;
    bsd)  printf '[[:<:]]%s[[:>:]]' "$1" ;;
    *)    printf '%s' "$1" ;;
  esac
}

status=0
rules=0
while IFS= read -r rule || [[ -n "$rule" ]]; do
  rule="${rule#"${rule%%[![:space:]]*}"}"
  rule="${rule%"${rule##*[![:space:]]}"}"
  [[ -z "$rule" || "$rule" == \#* ]] && continue
  rules=$((rules + 1))
  if [[ "$rule" == re:* ]]; then
    pattern="${rule#re:}"
  else
    pattern="$(boundary_pattern "$rule")"
  fi
  if hits="$(grep -InEi -- "$pattern" "${files[@]}" 2>/dev/null)"; then
    echo "privacy-check: BLOCKED by rule '${rule}'" >&2
    printf '%s\n' "$hits" | head -20 >&2
    status=1
  fi
done < "$DENYLIST"

if [[ $status -ne 0 ]]; then
  echo >&2
  echo "privacy-check: blocked. Remove the content, or narrow the rule if it is a false positive." >&2
  exit 1
fi

echo "privacy-check: clean (${#files[@]} files, $rules rules)"
```

The boundary detection was verified on the target machine, where `grep` resolves to `ugrep 7.5.0`: it accepts `\b` and rejects `[[:<:]]`, so the GNU branch is selected. The negative probe matters as much as the positive one — a grep that treats `\bword\b` as a literal would pass a positive-only probe while matching nothing.

- [ ] **Step 4: Run the test to verify it passes**

Run: `chmod +x tools/privacy-check.sh && bash tools/test-privacy-check.sh`
Expected: `5 passed, 0 failed`.

If `privacy-check` reports that it found no provable word-boundary support, the `word boundary is respected` case is expected to fail: the tool has fallen back to substring matching by design. That is a platform report, not a defect — but every commit will then need a closer look at false positives.

- [ ] **Step 5: Write the example denylist**

Create `tools/denylist.example.txt`:

```
# Denylist format — copy this file to ~/.config/asbg/denylist.txt and fill it in.
#
# THE REAL DENYLIST IS NEVER COMMITTED. It contains exactly the strings that
# must not be published; committing it would publish them.
#
# One rule per line. Blank lines and lines starting with # are ignored.
#   plain text   matched case-insensitively on word boundaries
#   re:PATTERN   matched as an extended regular expression
#
# --- Identity -----------------------------------------------------------
# Your name, every spelling and every handle. Family members. Colleagues.
#
# --- Organizations ------------------------------------------------------
# Employers, clients, mandates. Product and brand names from your work.
#
# --- Vault content ------------------------------------------------------
# Real area directory names. Real project names. Distinctive note titles.
#
# --- Infrastructure -----------------------------------------------------
# Server hostnames. SSH aliases. Private repository names. Container names.
re:/Users/[a-z0-9._-]+/
re:/home/[a-z0-9._-]+/
re:ssh\s+[a-z0-9._-]+@
#
# --- Contact and secrets ------------------------------------------------
re:[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}
re:\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b
re:[0-9]{8,10}:[A-Za-z0-9_-]{35}
re:sk-[A-Za-z0-9]{20,}
re:AIza[0-9A-Za-z_-]{35}
#
# --- Personal measurements ----------------------------------------------
# Any body metric that is a real reading rather than a placeholder.
```

- [ ] **Step 6: Write the ignore file**

Create `tools/privacy-check.ignore`:

```
# Path prefixes exempt from the privacy scan. One per line, reason required.

# v1/ is the previously published guide, archived verbatim per the spec. Its
# content is already public, and altering it would defeat the purpose of the
# archive. Anything sensitive in it was published in 2026 and cannot be recalled
# by editing this repository.
v1/

# The example denylist deliberately contains the generic patterns it teaches,
# which the scanner would otherwise flag as matches against itself.
tools/denylist.example.txt
```

- [ ] **Step 7: Write the link-check placeholder call and the pre-commit hook**

Create `.githooks/pre-commit`:

```bash
#!/usr/bin/env bash
# Blocks a commit whose staged content fails the publication checks.
set -uo pipefail

root="$(git rev-parse --show-toplevel)" || exit 1
cd "$root" || exit 1

mapfile -t staged < <(git diff --cached --name-only --diff-filter=ACMR)
if [[ ${#staged[@]} -eq 0 ]]; then
  exit 0
fi

existing=()
for f in "${staged[@]}"; do
  [[ -f "$f" ]] && existing+=("$f")
done

if [[ ${#existing[@]} -gt 0 ]]; then
  if ! bash tools/privacy-check.sh "${existing[@]}"; then
    echo "pre-commit: privacy-check failed" >&2
    exit 1
  fi
fi

if [[ -x tools/link-check.py ]] || [[ -f tools/link-check.py ]]; then
  if ! python3 tools/link-check.py; then
    echo "pre-commit: link-check failed" >&2
    exit 1
  fi
fi

exit 0
```

Create `tools/install-hooks.sh`:

```bash
#!/usr/bin/env bash
# Enables this repository's publication checks as git hooks.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
chmod +x .githooks/pre-commit tools/privacy-check.sh tools/install-hooks.sh
git config core.hooksPath .githooks

echo "Hooks enabled: core.hooksPath = .githooks"
echo
DENYLIST="${ASBG_DENYLIST:-$HOME/.config/asbg/denylist.txt}"
if [[ -r "$DENYLIST" ]]; then
  echo "Denylist found: $DENYLIST"
else
  echo "Denylist MISSING: $DENYLIST"
  echo "Commits will be blocked until it exists. Start from tools/denylist.example.txt:"
  echo "  mkdir -p \"\$(dirname \"$DENYLIST\")\" && cp tools/denylist.example.txt \"$DENYLIST\""
fi
```

- [ ] **Step 8: Verify the hook fires**

```bash
bash tools/install-hooks.sh
printf 'acme-hook-probe\n' >> tools/denylist.example.txt.probe
git add tools/denylist.example.txt.probe
# Temporarily add the probe term to the local denylist, then:
git commit -m "probe" 2>&1 | grep -q "privacy-check failed" && echo "hook blocks as expected"
git reset HEAD tools/denylist.example.txt.probe && rm tools/denylist.example.txt.probe
# Remove the probe term from the local denylist afterwards.
```

Expected: `hook blocks as expected`, and the probe file is gone.

- [ ] **Step 9: Commit**

```bash
git add tools/privacy-check.sh tools/test-privacy-check.sh tools/denylist.example.txt \
        tools/privacy-check.ignore tools/install-hooks.sh .githooks/pre-commit
git commit -m "Add privacy check tooling and pre-commit hook

The denylist lives outside the repository by design: it contains exactly the
strings that must not be published. The repository ships the scanner, an
example with generic patterns only, and an ignore file with a written reason
per exemption. The scanner fails closed when the denylist is absent."
```

---

## Task 2: Internal link checker

**Files:**
- Create: `tools/link-check.py`
- Create: `tools/pending-links.txt`
- Create: `tools/test-link-check.py`

**Interfaces:**
- Consumes: nothing.
- Produces: `python3 tools/link-check.py [--root DIR]` — resolves every relative Markdown link target in tracked `.md` files. Exit `0` all resolve or are allowlisted, `1` otherwise. Reads allowlisted targets from `tools/pending-links.txt`, one repository-relative path per line.

- [ ] **Step 1: Write the failing test**

Create `tools/test-link-check.py`:

```python
#!/usr/bin/env python3
"""Tests for link-check.py. Run: python3 tools/test-link-check.py"""
import subprocess
import sys
import tempfile
from pathlib import Path

CHECKER = Path(__file__).resolve().parent / "link-check.py"

results = []


def run_case(name, files, pending, expected_exit):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for rel, body in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(body, encoding="utf-8")
        if pending is not None:
            (root / "tools").mkdir(parents=True, exist_ok=True)
            (root / "tools" / "pending-links.txt").write_text(pending, encoding="utf-8")
        proc = subprocess.run(
            [sys.executable, str(CHECKER), "--root", str(root)],
            capture_output=True,
            text=True,
        )
        ok = proc.returncode == expected_exit
        results.append((name, ok, expected_exit, proc.returncode))
        print(f"{'ok  ' if ok else 'FAIL'} - {name} (expected {expected_exit}, got {proc.returncode})")


run_case(
    "resolving link passes",
    {"README.md": "See [the target](target.md).\n", "target.md": "# Target\n"},
    None,
    0,
)

run_case(
    "broken link fails",
    {"README.md": "See [the target](missing.md).\n"},
    None,
    1,
)

run_case(
    "pending link is allowed",
    {"README.md": "See [the target](missing.md).\n"},
    "missing.md\n",
    0,
)

run_case(
    "external links are ignored",
    {"README.md": "See [site](https://example.org) and [mail](mailto:a@b.c).\n"},
    None,
    0,
)

run_case(
    "anchor-only links are ignored",
    {"README.md": "See [section](#a-heading).\n"},
    None,
    0,
)

run_case(
    "link into a subdirectory resolves",
    {
        "README.md": "See [part](PART_1_PRINCIPLES/README.md).\n",
        "PART_1_PRINCIPLES/README.md": "# Part 1\n",
    },
    None,
    0,
)

run_case(
    "anchor is stripped before resolving",
    {"README.md": "See [target](target.md#heading).\n", "target.md": "# Target\n"},
    None,
    0,
)

failed = [r for r in results if not r[1]]
print()
print(f"{len(results) - len(failed)} passed, {len(failed)} failed")
sys.exit(1 if failed else 0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `python3 tools/test-link-check.py`
Expected: every case reports `FAIL`, because `tools/link-check.py` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `tools/link-check.py`:

```python
#!/usr/bin/env python3
"""Resolve every relative Markdown link in this repository.

A link target that does not exist is a broken link and fails the check, unless
it is listed in tools/pending-links.txt. That file is the record of chapters
not yet written; it shrinks as stages land and must be empty before
publication.

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
SKIP_PREFIXES = ("http://", "https://", "mailto:", "tel:", "#")


def markdown_files(root: Path) -> list[Path]:
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "ls-files", "*.md"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.split()
        if out:
            return [root / p for p in out]
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return sorted(root.rglob("*.md"))


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
        rel_dir = path.parent
        for lineno, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), start=1
        ):
            for target in LINK.findall(line):
                if target.startswith(SKIP_PREFIXES):
                    continue
                target = target.split("#", 1)[0]
                if not target:
                    continue
                if target.startswith("/"):
                    resolved = root / target.lstrip("/")
                else:
                    resolved = rel_dir / target
                resolved = Path(os.path.normpath(resolved))
                checked += 1
                if resolved.exists():
                    continue
                try:
                    rel_target = resolved.relative_to(root).as_posix()
                except ValueError:
                    rel_target = resolved.as_posix()
                if rel_target in allowed:
                    continue
                broken.append((path.relative_to(root).as_posix(), lineno, target))

    if broken:
        print(f"link-check: {len(broken)} broken link(s)", file=sys.stderr)
        for src, lineno, target in broken:
            print(f"  {src}:{lineno} -> {target}", file=sys.stderr)
        print(
            "\nlink-check: fix the link, or add the target to tools/pending-links.txt "
            "if the file is scheduled for a later stage.",
            file=sys.stderr,
        )
        return 1

    print(f"link-check: {checked} link(s) resolve; {len(allowed)} pending target(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 tools/test-link-check.py`
Expected: `7 passed, 0 failed`.

- [ ] **Step 5: Create the pending-links allowlist**

Create `tools/pending-links.txt`:

```
# Link targets that do not exist yet. Each entry is a repository-relative path
# scheduled for a later delivery stage. This file must be EMPTY before v2 is
# published; a non-empty allowlist at publication time means the guide links to
# chapters that were never written.
#
# Stage 2 — Part 1 and Part 5
PART_1_PRINCIPLES/01_the-vault-is-the-api.md
PART_1_PRINCIPLES/02_two-layers.md
PART_1_PRINCIPLES/03_governance-as-code.md
PART_1_PRINCIPLES/04_an-honest-comparison.md
PART_5_TRUST/20_failure-modes.md
PART_5_TRUST/21_the-watchdog.md
PART_5_TRUST/22_idempotency-and-state.md
PART_5_TRUST/23_recovery-runbooks.md
#
# Stage 3 — Part 3 and Part 4
PART_3_SKILLS/09_anatomy-of-a-skill.md
PART_3_SKILLS/10_design-plan-implement.md
PART_3_SKILLS/11_four-patterns.md
PART_3_SKILLS/12_skill-inventory.md
PART_3_SKILLS/13_composing-pipelines.md
PART_4_SENSORS/14_the-sensor-loop.md
PART_4_SENSORS/15_building-the-sync.md
PART_4_SENSORS/16_tags-as-the-interface.md
PART_4_SENSORS/17_dataview-mechanics.md
PART_4_SENSORS/18_dashboard-archetypes.md
PART_4_SENSORS/19_why-not-the-vendor-app.md
#
# Stage 4 — Part 2 and Part 6
PART_2_BUILD/05_stage-0-thirty-minutes.md
PART_2_BUILD/06_stage-1-autonomous.md
PART_2_BUILD/07_stage-2-close-the-loop.md
PART_2_BUILD/08_stage-3-system-files.md
PART_6_OPERATE/24_scale.md
PART_6_OPERATE/25_cost-and-model-routing.md
PART_6_OPERATE/26_privacy-in-practice.md
PART_6_OPERATE/27_what-is-still-wrong.md
#
# Stage 5 — starter kit
starter/README.md
```

- [ ] **Step 6: Run both checkers over the repository as it stands**

Run:
```bash
bash tools/privacy-check.sh
python3 tools/link-check.py
```
Expected: `privacy-check` clean. `link-check` clean — v1's internal links still resolve because v1 has not moved yet.

- [ ] **Step 7: Commit**

```bash
chmod +x tools/link-check.py
git add tools/link-check.py tools/test-link-check.py tools/pending-links.txt
git commit -m "Add internal link checker with a pending-target allowlist

Broken links fail the check. Targets scheduled for a later stage are listed in
tools/pending-links.txt, which shrinks as stages land and must be empty before
publication."
```

---

## Task 3: Archive v1

**Files:**
- Move: eleven `NN_*.md` files, `README.md`, `assets/`, `examples/` into `v1/`
- Create: `v1/README_ARCHIVE.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `v1/` containing v1 verbatim with its internal links intact. Tag `v1.0` on commit `4692d67`.

Moving the whole set together is what preserves v1's internal links: a link from `v1/README.md` to `./01_SERVER_SETUP.md` resolves to `v1/01_SERVER_SETUP.md`, and a link to `./examples/docker-compose.yml` resolves to `v1/examples/docker-compose.yml`. Moving files individually would break them.

- [ ] **Step 1: Tag v1 in history**

```bash
git tag -a v1.0 4692d67 -m "Guide v1 — eleven-chapter setup manual, as published"
git tag -l v1.0
```
Expected: `v1.0` is listed. Do not push the tag; pushing is an owner-authorized step in stage 5.

- [ ] **Step 2: Record the pre-move checksum**

```bash
git ls-files -- '*.md' 'assets' 'examples' | sort | xargs shasum -a 256 | shasum -a 256
```
Expected: a single hash. Write it into the commit message in step 6 so the verbatim claim is checkable.

- [ ] **Step 3: Move v1 into place**

```bash
mkdir -p v1
git mv README.md v1/README.md
for f in 01_SERVER_SETUP 02_OPENCLAW_INSTALL 03_SECONDBRAIN_STRUCTURE 04_SYSTEM_FILES \
         05_TELEGRAM_SETUP 06_OBSIDIAN_SETUP 07_CRON_AUTOMATION 08_SUBAGENT_SYSTEM \
         09_SCRIPTS_AND_TOOLS 10_DAILY_WORKFLOW 11_ADVANCED_TIPS; do
  git mv "$f.md" "v1/$f.md"
done
git mv assets v1/assets
git mv examples v1/examples
git status --short
```
Expected: thirteen renames staged, `LICENSE` and `docs/` and `tools/` untouched.

- [ ] **Step 4: Write the archive notice**

Create `v1/README_ARCHIVE.md`:

```markdown
# Archive notice — guide v1

This directory holds the first edition of the guide exactly as it was published,
unedited. It is kept for two reasons: external links point into it, and forks
were made from it.

It is no longer maintained. Its architecture is superseded by v2 in the
repository root, which treats the vault as the contract between several runtimes
rather than describing a single installation.

- Start here for the current guide: [../README.md](../README.md)
- Read v1 from the top: [README.md](./README.md)

v1 is also available as the git tag `v1.0`.
```

- [ ] **Step 5: Verify the archive is byte-identical to what was published**

```bash
git stash -u -q 2>/dev/null || true
for f in $(git ls-tree -r --name-only v1.0 | grep -E '\.(md|yml|json|js)$'); do
  if ! git show "v1.0:$f" | diff -q - "v1/$f" >/dev/null 2>&1; then
    echo "DIFFERS: $f"
  fi
done
git stash pop -q 2>/dev/null || true
echo "verbatim check done"
```
Expected: no `DIFFERS:` lines before `verbatim check done`.

- [ ] **Step 6: Verify the checkers still pass**

```bash
bash tools/privacy-check.sh
python3 tools/link-check.py
```
Expected: `privacy-check` clean — `v1/` is exempt via `tools/privacy-check.ignore`, which is why that exemption exists. `link-check` clean — v1's internal links moved together, and `v1/README_ARCHIVE.md` points at `../README.md`, which still exists at this point.

- [ ] **Step 7: Commit**

```bash
git add v1 && git commit -m "Archive guide v1 verbatim under v1/

Moved as one set so v1's internal links keep resolving. Content is unmodified;
verified byte-identical against tag v1.0. Pre-move tree hash: <hash from step 2>.

v1/ is exempt from the privacy scan because it is already published and
altering it would defeat the purpose of an archive."
```

---

## Task 4: Redirect stubs at v1's filenames

**Files:**
- Create: `01_SERVER_SETUP.md` through `11_ADVANCED_TIPS.md` (eleven files)

**Interfaces:**
- Consumes: `v1/` from Task 3.
- Produces: eleven stubs at the original filenames. Each links to its v1 original and to the v2 chapter covering the same ground.

- [ ] **Step 1: Write the mapping table**

The v2 target for each v1 chapter. Use this table verbatim in step 2; every v2 path here is already listed in `tools/pending-links.txt`, so the link checker will accept it.

| v1 file | Title | v2 successor |
|---|---|---|
| `01_SERVER_SETUP.md` | Server Setup | `PART_2_BUILD/06_stage-1-autonomous.md` |
| `02_OPENCLAW_INSTALL.md` | OpenClaw Install | `PART_2_BUILD/06_stage-1-autonomous.md` |
| `03_SECONDBRAIN_STRUCTURE.md` | SecondBrain Structure | `PART_1_PRINCIPLES/01_the-vault-is-the-api.md` |
| `04_SYSTEM_FILES.md` | System Files | `PART_2_BUILD/08_stage-3-system-files.md` |
| `05_TELEGRAM_SETUP.md` | Telegram Setup | `PART_2_BUILD/06_stage-1-autonomous.md` |
| `06_OBSIDIAN_SETUP.md` | Obsidian Setup | `PART_2_BUILD/07_stage-2-close-the-loop.md` |
| `07_CRON_AUTOMATION.md` | Cron Automation | `PART_1_PRINCIPLES/02_two-layers.md` |
| `08_SUBAGENT_SYSTEM.md` | Subagent System | `PART_3_SKILLS/09_anatomy-of-a-skill.md` |
| `09_SCRIPTS_AND_TOOLS.md` | Scripts and Tools | `PART_3_SKILLS/11_four-patterns.md` |
| `10_DAILY_WORKFLOW.md` | Daily Workflow | `PART_3_SKILLS/13_composing-pipelines.md` |
| `11_ADVANCED_TIPS.md` | Advanced Tips | `PART_5_TRUST/21_the-watchdog.md` |

- [ ] **Step 2: Generate the stubs**

```bash
write_stub() {
  local file="$1" title="$2" successor="$3" successor_title="$4"
  cat > "$file" <<EOF
# Moved — $title

This chapter belonged to guide v1. The second edition reorganized the material,
so this filename now exists only so that links to it keep working.

| | |
|---|---|
| The original, unedited | [v1/$file](./v1/$file) |
| What replaced it | [$successor_title](./$successor) |
| Start of the current guide | [README.md](./README.md) |

v1 in full: [v1/README.md](./v1/README.md), or the git tag \`v1.0\`.
EOF
}

write_stub 01_SERVER_SETUP.md        "Server Setup"          PART_2_BUILD/06_stage-1-autonomous.md      "Stage 1 — Make It Autonomous"
write_stub 02_OPENCLAW_INSTALL.md    "OpenClaw Install"      PART_2_BUILD/06_stage-1-autonomous.md      "Stage 1 — Make It Autonomous"
write_stub 03_SECONDBRAIN_STRUCTURE.md "SecondBrain Structure" PART_1_PRINCIPLES/01_the-vault-is-the-api.md "The Vault Is the API"
write_stub 04_SYSTEM_FILES.md        "System Files"          PART_2_BUILD/08_stage-3-system-files.md    "Stage 3 — The System Files"
write_stub 05_TELEGRAM_SETUP.md      "Telegram Setup"        PART_2_BUILD/06_stage-1-autonomous.md      "Stage 1 — Make It Autonomous"
write_stub 06_OBSIDIAN_SETUP.md      "Obsidian Setup"        PART_2_BUILD/07_stage-2-close-the-loop.md  "Stage 2 — Close the Loop"
write_stub 07_CRON_AUTOMATION.md     "Cron Automation"       PART_1_PRINCIPLES/02_two-layers.md         "Two Layers"
write_stub 08_SUBAGENT_SYSTEM.md     "Subagent System"       PART_3_SKILLS/09_anatomy-of-a-skill.md     "Anatomy of a Skill"
write_stub 09_SCRIPTS_AND_TOOLS.md   "Scripts and Tools"     PART_3_SKILLS/11_four-patterns.md          "Four Patterns"
write_stub 10_DAILY_WORKFLOW.md      "Daily Workflow"        PART_3_SKILLS/13_composing-pipelines.md    "Composing Pipelines"
write_stub 11_ADVANCED_TIPS.md       "Advanced Tips"         PART_5_TRUST/21_the-watchdog.md            "The Watchdog"
```

- [ ] **Step 3: Add the not-yet-existing README to the allowlist**

`README.md` at the root will be written in Task 7, and the stubs link to it. Append to `tools/pending-links.txt` under a new heading:

```
#
# Stage 1 — written later in this stage
README.md
CHANGELOG.md
```

Remove both entries again at the end of Task 8.

- [ ] **Step 4: Verify**

```bash
ls -1 [01][0-9]_*.md | wc -l
python3 tools/link-check.py
bash tools/privacy-check.sh
```
Expected: `11`, then both checkers clean.

- [ ] **Step 5: Commit**

```bash
git add [01][0-9]_*.md tools/pending-links.txt
git commit -m "Add redirect stubs at v1 filenames

External links and forks point at the original chapter filenames. Each stub
names the v1 original, the v2 chapter that replaced it, and the current entry
point."
```

---

## Task 5: Canonical architecture diagrams

**Files:**
- Create: `assets/architecture.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `assets/architecture.md` containing the two-layer diagram, referenced by name from the README and later chapters. The two-layer diagram is inlined in the README as well; this file is the source of truth and holds the longer explanation plus the secondary diagrams.

- [ ] **Step 1: Write the file**

Create `assets/architecture.md` with exactly these four sections.

**Section 1 — The two-layer model.** Use this diagram verbatim; it is the canonical one and must be identical everywhere it appears:

```
        AUTONOMOUS                        COLLABORATIVE
        (runs without you)                (runs with you)

  ┌────────────────────────┐        ┌────────────────────────┐
  │ OpenClaw on a VPS      │        │ Claude Code (local)    │
  │  · cron jobs           │        │  · builds skills       │
  │  · scheduled syncs     │        │  · refactors the vault │
  │  · watchdog + alerts   │        │  · governance edits    │
  │  · Telegram interface  │        │ Desktop agent w/ MCP   │
  │                        │        │  · live work context   │
  └───────────┬────────────┘        └───────────┬────────────┘
              │                                 │
              └───────────────┬─────────────────┘
                              │
                  ┌───────────▼────────────┐
                  │   THE VAULT            │  ← the only contract
                  │   plain Markdown       │
                  │   YAML frontmatter     │
                  │   append-only JSONL    │
                  │   git + file sync      │
                  └───────────┬────────────┘
                              │
                  ┌───────────▼────────────┐
                  │ Obsidian (you, reading)│
                  └────────────────────────┘
```

Follow it with the reading of the diagram, in prose: no arrow runs runtime to runtime; every path goes through the file tree; that is what makes any single runtime replaceable, and it is the whole architecture in one property.

**Section 2 — The capture pipeline.** A left-to-right ASCII chain showing arbitrary input entering an inbox, classification, filing to a destination directory, cross-linking into journal and network notes, distillation into a concept note, and finally composition into publishable output. Label every arrow with the contract it satisfies, not with a verb.

**Section 3 — The sensor loop.** An ASCII chain: device, vendor API, sync job, append-only JSONL, journal section, habit tag, dashboard query. Mark which hops are idempotent and which are append-only, since those two properties are what make the loop safe to re-run.

**Section 4 — The watchdog's position.** A small diagram showing the watchdog reading the vault rather than the jobs, with an alert channel leaving to the operator. One sentence on why the arrow points at the vault: a job's exit code reports whether it ran, and every interesting failure in this system is one where the job ran and exited zero.

Every diagram is plain ASCII with box-drawing characters, no images, no Mermaid — so it survives being pasted into a terminal, an issue, a chat window, or a slide.

- [ ] **Step 2: Verify the diagrams render as intended**

```bash
python3 - <<'PY'
from pathlib import Path
text = Path("assets/architecture.md").read_text(encoding="utf-8")
blocks = text.split("```")
fences = (len(blocks) - 1) // 2
print(f"fenced blocks: {fences}")
assert fences >= 4, "expected at least four diagrams"
for i, block in enumerate(blocks[1::2], start=1):
    widths = {len(line) for line in block.splitlines() if line.strip()}
    print(f"  diagram {i}: {len(widths)} distinct line widths, max {max(widths)}")
    assert max(widths) <= 100, f"diagram {i} is too wide to paste"
print("ok")
PY
```
Expected: at least four diagrams, none wider than 100 columns, ending in `ok`.

- [ ] **Step 3: Commit**

```bash
git add assets/architecture.md
git commit -m "Add canonical architecture diagrams

Plain ASCII so they survive being pasted anywhere. The two-layer diagram is the
canonical one and must stay byte-identical wherever it appears."
```

---

## Task 6: Part index files

**Files:**
- Create: `PART_1_PRINCIPLES/README.md`
- Create: `PART_2_BUILD/README.md`
- Create: `PART_3_SKILLS/README.md`
- Create: `PART_4_SENSORS/README.md`
- Create: `PART_5_TRUST/README.md`
- Create: `PART_6_OPERATE/README.md`

**Interfaces:**
- Consumes: `tools/pending-links.txt` from Task 2, which already allowlists every chapter these indexes link to.
- Produces: six part indexes linked from the README's table of contents in Task 7.

Each index is real content, not a stub. It is what a reader lands on when they follow a part link, and it must be worth reading on its own.

- [ ] **Step 1: Write the six indexes to a fixed shape**

Every part index contains, in order:

1. `# Part N — <Title>`
2. One paragraph, three to five sentences: the question this part answers and why it comes where it does in the sequence.
3. A chapter table: number, linked title, and a one-line description of what the chapter delivers. Use the chapter paths from `tools/pending-links.txt` verbatim.
4. A blockquote pull-quote: the part's single load-bearing claim.
5. `**Read next:**` with a link to the next part's index, or for Part 6, back to the root README.

The six pull-quotes, to be used verbatim:

| Part | Pull-quote |
|---|---|
| 1 | The data format is the contract. Every runtime is a client, and any client can be replaced. |
| 2 | Each stage ends with a system that is useful on its own. A build that is only valuable when finished is a build that gets abandoned. |
| 3 | A capability you cannot version, test, or read is not a capability. It is a prompt you got lucky with. |
| 4 | The vendor has your sensor data. The vendor does not have your journal. |
| 5 | Every failure worth catching in this system exits zero. Success is not evidence. |
| 6 | The cost of a second brain is not the server. It is every file the agent reads on every single run. |

Part titles and one-line framings for the index paragraphs:

| Part | Title | Frames |
|---|---|---|
| 1 | Principles | Why a file tree, not a database; why two layers; why governance is written down; where this system loses to a hosted product |
| 2 | Build | Four stages, each independently useful, from thirty minutes with no server to a full autonomous installation |
| 3 | Skills | Capabilities as specified, versioned, sometimes tested artifacts, and the four patterns that cover most of what anyone needs |
| 4 | Sensors and Dashboards | The complete loop from a wearable's API to a query block, and the argument for owning both ends |
| 5 | Trust | The failure modes of unattended agents, and the observability that makes them visible |
| 6 | Operate | What scale, cost, and privacy actually look like after months of continuous operation, and what is still wrong |

- [ ] **Step 2: Verify**

```bash
ls -1 PART_*/README.md | wc -l
python3 tools/link-check.py
bash tools/privacy-check.sh
grep -L '^> ' PART_*/README.md && echo "MISSING PULL-QUOTE" || echo "all parts have a pull-quote"
```
Expected: `6`, both checkers clean, `all parts have a pull-quote`.

- [ ] **Step 3: Commit**

```bash
git add PART_1_PRINCIPLES PART_2_BUILD PART_3_SKILLS PART_4_SENSORS PART_5_TRUST PART_6_OPERATE
git commit -m "Add the six part indexes

Each index is content, not a stub: the question the part answers, its chapters,
and the part's load-bearing claim as a pull-quote."
```

---

## Task 7: The README

**Files:**
- Create: `README.md`
- Modify: `tools/pending-links.txt` (remove the `README.md` entry)

**Interfaces:**
- Consumes: `assets/architecture.md` from Task 5, the six part indexes from Task 6, the owner-supplied `MONTHS_RUNNING` and `MONTHLY_COST`.
- Produces: the repository front door. Every other file links back to it.

**Blocked until** the owner supplies `MONTHS_RUNNING` and `MONTHLY_COST`. Do not invent them and do not ship the file with a placeholder.

- [ ] **Step 1: Confirm the two missing figures**

Ask the repository owner for `MONTHS_RUNNING` and `MONTHLY_COST`. Do not proceed without both.

- [ ] **Step 2: Write the README to this exact shape**

1. `# The Agentic Second Brain` and, on the next line, the thesis as a single italic line: *A second brain is not a note system. It is a distributed system, and it has to be engineered like one.*

2. **Cold open, at most 150 words.** States the problem operationally: an agent that writes to your files on a schedule is a distributed system with a shared mutable store, several writers, and no transactions. Its interesting failures are the quiet ones — the job that exits zero and does nothing. Ends by stating what the document delivers: the architecture, the code, and the operational practice that makes such a system trustworthy. No sales language, no promise of transformation, no first person.

3. **Numbers table.** Exactly these rows, with the values from Global Constraints plus the two owner-supplied figures:

| | |
|---|---|
| Markdown notes | ~7,800 |
| Files under management | ~11,000 |
| Skills | 27, of which 14 have an implementation |
| Health checks | 13 |
| Days of sensor history | ~140 |
| Dashboard query blocks | 14 |
| Continuous operation | `MONTHS_RUNNING` months |
| Running cost | `MONTHLY_COST` EUR / month |

Precede the table with one sentence stating these are properties of a running installation, given to set the scale of what follows.

4. **The two-layer diagram**, inlined byte-identical to `assets/architecture.md` section 1, followed by the two-sentence reading of it and a link to `assets/architecture.md` for the remaining diagrams.

5. **Three reading paths**, as a table: *Understand it* to Part 1; *Build it* to the quickstart below then Part 2; *Operate it* to Parts 5 and 6. One sentence each on who that path is for.

6. **Quickstart.** The thirty-minute path, inline and copy-pasteable: clone, create the vault skeleton, install the hooks, point a local coding agent at it, run the first skill. Every command complete. Ends by stating what the reader now has and linking to chapter 05 for the explanation of what they just did. Where the quickstart depends on files that arrive in stage 5, link to `starter/README.md` — already allowlisted — and mark the section with a single line: `The starter kit lands in the final stage of this rewrite; the commands below are the shape it will take.` Remove that line in stage 5.

7. **Contents.** A table of the six parts linking to their indexes, each with its chapter range and one line on what it covers.

8. **What this is not.** Four bullets: not a hosted product; not a plugin; not zero-maintenance — you become the operator; not a replacement for deciding what matters. Plain, no hedging.

9. **Prerequisites** as a table: a VPS, an API key for a model provider, a chat account for the interface, a local machine, and Obsidian with the Dataview and Charts community plugins for Part 4. Cost column where a cost exists.

10. **License** and **Contributing**, two lines each.

Deliberately omitted: a support or donation link. It carries the author's name, and the privacy constraint puts the author outside the document. This is a decision to revisit with the owner, not an oversight.

- [ ] **Step 3: Verify the README standalone claim**

```bash
python3 - <<'PY'
from pathlib import Path
import re
text = Path("README.md").read_text(encoding="utf-8")
required = [
    "The Agentic Second Brain",
    "distributed system",
    "AUTONOMOUS",
    "COLLABORATIVE",
    "THE VAULT",
    "What this is not",
    "Quickstart",
]
missing = [r for r in required if r not in text]
assert not missing, f"README missing: {missing}"
assert not re.search(r"\b(I|I'm|I've|my|mine)\b", text), "first person found in README"
words = len(text.split())
print(f"README: {words} words, all required sections present, no first person")
PY
```
Expected: all sections present, no first person.

- [ ] **Step 4: Verify the diagram is byte-identical in both places**

```bash
python3 - <<'PY'
from pathlib import Path
def first_block(p):
    return Path(p).read_text(encoding="utf-8").split("```")[1]
a = first_block("assets/architecture.md")
b = [b for b in Path("README.md").read_text(encoding="utf-8").split("```") if "THE VAULT" in b][0]
assert a.strip() == b.strip(), "the two-layer diagram differs between README and assets"
print("diagram identical in both files")
PY
```
Expected: `diagram identical in both files`.

- [ ] **Step 5: Remove README from the pending allowlist and re-run the checkers**

```bash
grep -v '^README.md$' tools/pending-links.txt > tools/pending-links.tmp && mv tools/pending-links.tmp tools/pending-links.txt
python3 tools/link-check.py
bash tools/privacy-check.sh
```
Expected: both clean.

- [ ] **Step 6: Commit**

```bash
git add README.md tools/pending-links.txt
git commit -m "Rewrite the README as the v2 front door

Thesis, scale, the canonical diagram, three reading paths, a thirty-minute
quickstart, and an explicit statement of what the system is not. A reader who
reads only this file should be able to decide whether to build."
```

---

## Task 8: CHANGELOG and stage close-out

**Files:**
- Create: `CHANGELOG.md`
- Modify: `tools/pending-links.txt` (remove the `CHANGELOG.md` entry)

**Interfaces:**
- Consumes: everything above.
- Produces: a stage-1 tree that passes every check and is publishable on its own.

- [ ] **Step 1: Write the changelog**

Create `CHANGELOG.md` with two sections.

`## v2 — in progress` — what changed and, for each item, why. Cover: the reorganization from eleven install chapters into six parts; the skills system replacing prose agent profiles; the new sensor and dashboard part; the new trust part; the starter kit; the privacy tooling; and the shift in voice away from a fictional persona. One line per item, each with its reason.

`## v1 — 2026` — one paragraph. What v1 was, that it is archived under `v1/` and tagged `v1.0`, and that its filenames still resolve through redirect stubs.

- [ ] **Step 2: Remove the last stage-1 allowlist entry**

```bash
grep -v '^CHANGELOG.md$' tools/pending-links.txt > tools/pending-links.tmp && mv tools/pending-links.tmp tools/pending-links.txt
grep -c '^[^#]' tools/pending-links.txt
```
Expected: 28 remaining entries, all of them chapters and the starter README scheduled for stages 2 through 5.

- [ ] **Step 3: Full verification run**

```bash
bash tools/test-privacy-check.sh
python3 tools/test-link-check.py
bash tools/privacy-check.sh
python3 tools/link-check.py
git status --short
```
Expected: both test suites pass, both checkers clean, working tree clean apart from the changelog about to be committed.

- [ ] **Step 4: Verify the stage-1 acceptance criteria**

```bash
test -f README.md                        && echo "ok README"
test -f CHANGELOG.md                     && echo "ok CHANGELOG"
test -f assets/architecture.md           && echo "ok diagrams"
test "$(ls -1 PART_*/README.md | wc -l | tr -d ' ')" = 6 && echo "ok six part indexes"
test "$(ls -1 [01][0-9]_*.md | wc -l | tr -d ' ')" = 11 && echo "ok eleven stubs"
test -d v1 && test -f v1/README.md       && echo "ok v1 archive"
git tag -l v1.0 | grep -q v1.0           && echo "ok v1.0 tag"
test -x tools/privacy-check.sh           && echo "ok privacy tooling"
git config --get core.hooksPath | grep -q .githooks && echo "ok hooks installed"
```
Expected: nine `ok` lines.

- [ ] **Step 5: Commit**

```bash
git add CHANGELOG.md tools/pending-links.txt
git commit -m "Add changelog and close out stage 1

Stage 1 delivers the publishable foundation: safety tooling, the v1 archive
with working redirects, the canonical diagrams, six part indexes, and a README
that stands alone."
```

- [ ] **Step 6: Hand back for review**

Report to the owner: the tree passes all checks, `tools/pending-links.txt` holds 28 entries for stages 2 through 5, nothing has been pushed, and the branch is `v2`. Ask them to read `README.md` and `assets/architecture.md`, which are the two files the rest of the document is built around.

---

## Stages 2–5 — scope, gates, and what each plan must contain

Each stage gets its own plan, written after the previous stage's review, because a review of the README and the diagram changes how the chapters are written. The scope below is fixed by the spec and is not open for reinterpretation while planning.

| Stage | Delivers | Chapters | New verification the plan must add |
|---|---|---|---|
| 2 | Part 1 and Part 5 | 01–04, 20–23 | Pull-quote presence per chapter; failure-mode table completeness against the spec's eight rows |
| 3 | Part 3 and Part 4 | 09–19 | Every fenced code block extracted and executed or syntax-checked; every dashboard query loaded in Obsidian against a synthetic dataset containing gaps and nulls |
| 4 | Part 2 and Part 6 | 05–08, 24–27 | Every command in the build path executed against a scratch environment, with the unverifiable steps explicitly listed for owner verification |
| 5 | `starter/`, verification run, humanizer pass, publication | — | `setup.sh` run twice against an empty and a populated directory; `importer` tests pass; watchdog checks fire against a deliberately broken scratch vault; `tools/pending-links.txt` empty |

Stage 5 additionally carries the two gates that cannot be automated:

1. **Owner verification of the unverifiable path** — a from-scratch VPS provision, Docker install, OpenClaw deploy, and Telegram pairing; real device authentication for the sensor sync; mobile file sync. Until confirmed, these sections stay marked in the document.
2. **A manual read-through of every shipped file** against the privacy constraints, because a denylist catches known strings and not an overlooked detail.

Publication — pushing the `v2` branch, merging, and pushing the `v1.0` tag — happens only after both gates and only on explicit owner instruction.

---

## Self-Review

**Spec coverage.** Spec sections 4 (privacy) and 5 (repository layout) are fully implemented by Tasks 1–8. Section 6's README and diagram are Tasks 5 and 7; its part structure is Task 6; its 27 chapters are staged into 2–4 with scope fixed in the table above. Section 7 (starter kit) is stage 5. Section 8 (style) enters as Global Constraints here and as the humanizer pass in stage 5. Section 9's mechanics: the standalone README is Task 7, the canonical diagram Task 5, pull-quotes Task 6 and stage 2. Section 10's verification is distributed across every task's verify step, with the unverifiable list carried into stage 5. Section 11's stages map one-to-one. Section 12's link-rot risk is Tasks 3 and 4; the privacy risk is Task 1; the scope risk is the per-stage split itself.

**Gap found and closed.** The spec requires a code-block validator for chapters carrying runnable code. No stage-1 chapter has code, so the tool is scheduled in stage 3's plan where it is first needed rather than built here unused.

**Placeholder scan.** No `TBD`, no `TODO`, no "add error handling", no "similar to Task N". The two genuinely unknown values, `MONTHS_RUNNING` and `MONTHLY_COST`, are named as owner inputs with an explicit block on Task 7 rather than left as placeholders in the output.

**Type consistency.** `tools/privacy-check.sh` takes optional path arguments and returns 0/1/2 in Task 1, and every later call site uses that contract, including `.githooks/pre-commit`. `tools/link-check.py` takes `--root` and returns 0/1 in Task 2, and the test harness and hook both use it that way. `tools/pending-links.txt` is one repository-relative path per line in Task 2, and Tasks 4, 7, and 8 add and remove entries in that exact format. Chapter filenames appear identically in `tools/pending-links.txt` (Task 2), the redirect mapping (Task 4), and the part indexes (Task 6).
