# 05 — Stage 0: Thirty Minutes

No server, no Docker, no scheduler, no chat interface. A directory, a handful of
rule files, a local coding agent, and one capability that works. At the end of this
chapter the system does something useful, which is the only honest way to find out
whether you want the rest of it.

> Build the destination before the machinery. A vault with no automation is still useful; automation with no vault is a demo.

---

## What you need

| | |
|---|---|
| A local coding agent | Claude Code, or any agent that can read and write files in a directory |
| A text editor | Obsidian is ideal but comes in chapter 07; anything works now |
| Nothing else | No server, no API keys beyond the agent you already have |

## 1. The skeleton

Numbered directories, because a number in front of a name is a sort order and an
implicit statement of how often you touch it.

```bash
mkdir -p secondbrain/{00_Start/Inbox,05_Wisdom,10_Journal,11_Readings,20_Areas,30_Life,40_Network/People,90_Archive,99_Assets/Templates,memory,skills}
cd secondbrain
git init && git add -A && git commit -m "Empty vault skeleton"
```

| Directory | Holds |
|---|---|
| `00_Start/` | Dashboards, the inbox, goals. The place you open first |
| `05_Wisdom/` | Distilled concept notes — the output of thinking, not the input |
| `10_Journal/` | Dated entries, `YYYY/MM/YYYY-MM-DD.md` |
| `11_Readings/` | Articles, books, papers, video notes |
| `20_Areas/` | Ongoing responsibilities: a job, a mandate, a side project |
| `30_Life/` | Health, finances, travel |
| `40_Network/People/` | One note per person, `Lastname_Firstname.md` |
| `90_Archive/` | Finished things. Queries exclude it |
| `99_Assets/Templates/` | Frontmatter templates |
| `memory/` | Agent state and append-only logs |
| `skills/` | Capability directories |

Git from the first commit. Chapter 01 promised history as a free property of the
format, and it is only free if you start.

## 2. Two rule files

Nine files eventually — chapter 08 — but two are enough to be useful, and starting
with nine means starting with eight you have not thought about.

`IDENTITY.md`:

```markdown
# Identity

You maintain this vault. You are direct, brief, and concrete.

## How you respond
- Short confirmations. "Filed." not "I have successfully filed your note."
- No file paths in replies unless asked.
- No checkmark emoji, no process narration.
- When something is ambiguous, say what is unclear and stop.

## What you never do
- Never delete a note. Move it to 90_Archive/ instead.
- Never modify IDENTITY.md, SECURITY.md, or TOOLS.md.
- Never invent a fact about a person. Unknown fields stay empty.
```

`SECURITY.md`:

```markdown
# Security

## Read-only
Never modify: IDENTITY.md, SECURITY.md, TOOLS.md

## Append-only
Never rewrite existing lines in memory/*.jsonl

## Deletion
Never delete. Move to 90_Archive/ with status: archived.

## Ambiguity
Never guess a destination, a person's identity, or a date. Leave the item in
place, tag it #needs-review, and report what was unclear.
```

Both are short on purpose. Chapter 24 explains the arithmetic: every line here is
read on every run, forever.

## 3. The frontmatter contract

`99_Assets/Templates/note.md`:

```markdown
---
title: ""
date:
tags: []
type: note
status: active
---
```

And the convention file the agent reads, `99_Assets/Templates/CONVENTIONS.md`:

```markdown
# Conventions

## Filenames
- Daily: `YYYY-MM-DD.md`
- People: `Lastname_Firstname.md`
- Readings: `YYYY-MM-DD-kebab-title.md`
- Concepts: `kebab-title.md`, no date

## Frontmatter
Every note has title, date, tags, type, status.
`type` is one of: note, daily, reading, person, meeting, concept, project.
`status` is one of: active, completed, archived.

## Links
`[[Exact_Filename]]` without the extension. Always link people by note name.
```

Chapter 01 argued each of these exists because a program depends on it. This file is
where the programs look.

## 4. One skill

`quick-capture` — a prefix that routes a thought to the right place. Chapter 12 calls
it the highest-value item relative to its size, because it removes the decision that
otherwise stops you capturing at all.

`skills/quick-capture/SKILL.md`:

```markdown
# Skill: quick-capture

## Purpose
Route a prefixed message to the right file without asking follow-up questions.

## Trigger
A message beginning with a known prefix.

## Routing
| Prefix | Meaning | Destination |
|---|---|---|
| `n:` | A note or idea | New file in `00_Start/Inbox/` |
| `t:` | A task | Append `- [ ] <text> #todo` to `00_Start/Tasks.md` |
| `q:` | A quote worth keeping | New file in `05_Wisdom/` |
| `p:` | A person to remember | `40_Network/People/Lastname_Firstname.md` |

## Outputs
The file, with full frontmatter per CONVENTIONS.md. Nothing else.

## Invariants
1. Never ask a clarifying question for a prefixed message. Route it or flag it.
2. `p:` uses every template field; unknown values stay empty strings.
3. Never edit a file other than the destination.

## Failure behaviour
Unrecognised prefix, or text that does not fit the prefix: write it to
`00_Start/Inbox/` tagged `#needs-review` and say what was unclear.
```

No code. This is a specification-only skill — chapter 09's decision table puts it
there because a human is present and each invocation is a fresh judgement.

## 5. Point the agent at it

Create `CLAUDE.md` (or your agent's equivalent) at the vault root:

```markdown
# Agent instructions

This is a personal knowledge vault. Read IDENTITY.md, SECURITY.md and
99_Assets/Templates/CONVENTIONS.md before acting.

Skills live in `skills/<name>/SKILL.md`. When a request matches a skill's trigger,
follow that contract exactly.

Never modify root-level *.md files. Never delete notes.
```

Then use it:

```
n: the two-layer split is the thing I keep having to re-explain
t: write the freshness check before adding another integration
p: Jane Doe, head of platform at Acme, met at the meetup
```

Three messages, three files in the right places with valid frontmatter. That is the
system working.

## 6. Prove the contract holds

Before trusting it, check the thing that will actually break — the format:

```bash
python3 - <<'PY'
from pathlib import Path
import yaml, sys
bad = []
for p in Path(".").rglob("*.md"):
    if any(part.startswith(".") for part in p.parts):
        continue
    text = p.read_text(encoding="utf-8")
    if not text.startswith("---"):
        continue
    block = text.split("---", 2)[1]
    try:
        yaml.safe_load(block)
    except yaml.YAMLError as e:
        bad.append(f"{p}: {str(e).splitlines()[0]}")
print("\n".join(bad) if bad else f"all notes parse")
PY
```

Run it now, and run it again in a month. This is chapter 21's integrity check in its
smallest form, and it will eventually find something.

## What you have, and what you do not

**Have:** a vault whose format is a contract, rules the agent obeys, one capability
that works, and git history from the first commit. Everything in Parts 3 and 4 builds
on exactly this.

**Do not have:** anything that runs without you. No briefing, no sync, no checks. If
you stop opening the agent, nothing happens — which is fine, and is precisely what
chapter 06 changes.

Stay here for a week before continuing. Two things are worth knowing before you
provision a server, and only a week of use will tell you: whether the conventions
survive contact with your actual notes, and whether you reach for this at all. The
answer to the second question is more useful than any amount of infrastructure.

---

**Read next:** [06 — Stage 1: Make It Autonomous](./06_stage-1-autonomous.md).
