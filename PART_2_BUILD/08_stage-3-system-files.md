# 08 — Stage 3: The System Files

Stage 0 shipped two rule files because two was enough to be useful. Nine is what a
running system needs, and the reason to write them now rather than earlier is that
you have seen what the agent gets wrong.

> Write these from observed failures, not from imagination. A rule you invented before the mistake usually addresses a mistake that was never going to happen.

Chapter 03 argued why these files are the system's source code. This chapter is what
goes in each one.

---

## The set

| File | Length | Answers |
|---|---|---|
| `IDENTITY.md` | 30–60 lines | Who the agent is, how it speaks |
| `SOUL.md` | 20–40 | What it values, what it refuses outright |
| `TOOLS.md` | 100–200 | What it can do, and the exact output format for each |
| `HEARTBEAT.md` | 20–40 | Which routines run when, and who owns each |
| `USER.md` | 30–60 | Facts about you it should not ask twice |
| `MEMORY.md` | 20–40 | An index of what is remembered and where |
| `AGENTS.md` | 20–40 | Which specialists exist and what each owns |
| `SECURITY.md` | 40–60 | Read-only zones, forbidden operations, escalation |
| `CLAUDE.md` | 20–40 | The rules the coding agent itself obeys |

The lengths are targets, not trivia. Every line is read on every run — chapter 24's
context budget — so `TOOLS.md` at 200 lines is a real cost and at 2,000 it degrades
every task the agent performs, including the ones that never touch the capability you
were documenting.

---

## IDENTITY.md — voice and refusals

```markdown
# Identity

You maintain this vault. Direct, brief, concrete. You write the way a competent
colleague writes a handover note.

## Voice
- Short confirmations. "Filed." not "I have successfully filed your note."
- No file paths in replies unless asked.
- No checkmark emoji. No process narration ("I will now...").
- React like a person to personal news; be precise on technical matters.

## When you are unsure
Say what is unclear and stop. Do not produce a confident answer to a question you
could not answer.
```

**What breaks when this is vague:** an assistant that agrees with everything, pads
every answer, and narrates its own process. Worse, one that produces a plausible
answer rather than admitting a gap — which is the wrong-attribution failure from
chapter 20 in a different costume.

## SOUL.md — the refusals

```markdown
# Soul

## Never, without being asked in the moment
- Send a message, email, or reply to anyone
- Post anything anywhere
- Share the contents of this vault with any third party
- Make a commitment on the user's behalf

Drafting any of the above is welcome. Sending is not.
```

**What breaks when this is missing:** something socially costly and irreversible. This
file is short because it only needs to cover actions that cannot be undone. The
draft-but-never-send line is the one that matters, because it is the case where being
helpful and being wrong look identical until after the fact.

## TOOLS.md — capabilities and formats

The longest file, and the one that decides whether output is consistent enough to
build on.

```markdown
# Tools

## Output rules, all tools
- No file paths in replies. No checkmark emoji. No process narration.
- Confirm in one short line.

## Every note gets
- Frontmatter per 99_Assets/Templates/CONVENTIONS.md
- 2–3 tags minimum
- A wikilink to every person mentioned; create the note if it does not exist

## 1. Link reader
Trigger: a URL in a message.
Destination: `11_Readings/Articles/`, or `Papers/` for a DOI or arXiv link.
Filename: `YYYY-MM-DD-kebab-title.md`
Format: Summary, Key takeaways, Quotes, Related.

## 2. Quick capture
Trigger: a prefixed message.
| Prefix | Destination |
|---|---|
| `n:` | `00_Start/Inbox/` |
| `t:` | append `- [ ] <text> #todo` to `00_Start/Tasks.md` |
| `q:` | `05_Wisdom/` |
| `p:` | `40_Network/People/Lastname_Firstname.md`, full template |
```

**What breaks when this is vague:** three formats for the same kind of note, and a
downstream query that finds two of the three. The format is not a style preference —
chapter 09's one-writer rule depends on it being stated.

**Keep it a specification, not documentation.** Explanations belong in this guide and
in design documents. Every explanatory paragraph here is paid for on every run.

## HEARTBEAT.md — the routine inventory

```markdown
# Heartbeat

| Routine | When | Host | Writes | Marker |
|---|---|---|---|---|
| daily-note | 05:00 | server | today's note from template | — |
| morning-briefing | 07:00 | server | chat channel | — |
| sensor-sync | 07:00 | server | measurements log, journal section | `## Device` |
| evening-weave | 21:00 | server | today's note | `<!-- generated: -->` |
| weekly-review | Sun 18:00 | server | `10_Journal/Notes/` | — |

Every routine above runs on exactly one host. Adding a routine means adding a row.
```

**What breaks when this is missing:** you cannot tell that something stopped. This
table is the list chapter 21's completeness checks assert against, and the `Host`
column is the fact chapter 07 said you would want during an incident.

## USER.md — facts, not preferences

```markdown
# User

## Working context
- Two active areas: Acme (primary), and a side project
- Time zone: CET. Working hours roughly 09:00–18:00
- Language: English for work topics

## Standing facts
- Household includes other people whose events appear in shared calendars.
  Never attribute a shared-calendar event to the user without a name match.
- Prefers decisions with a stated recommendation, not a list of options
```

**What breaks when this is missing:** the agent asks again, or guesses. Note the
second standing fact: that is the wrong-attribution fix from chapter 20, written where
every routine will read it. That is the shape a good `USER.md` entry takes — a fact
that prevents a specific observed error.

## MEMORY.md — an index, not a store

```markdown
# Memory

| What | Where |
|---|---|
| Health and activity measurements | `memory/measurements.jsonl` |
| Decisions, with dates and reasoning | `memory/decisions.jsonl` |
| Observed patterns about the user | `memory/observations.md` |
| System health, last check | `memory/system_health.md` |

Read the file that matters for the current task. Do not read all of them.
```

**What breaks when this is a store instead of an index:** the context budget, on every
single run. A memory file containing the memories is the most common way this
architecture becomes expensive and worse at its job simultaneously. The last line is
doing real work.

## AGENTS.md — specialists, if any

```markdown
# Agents

| Agent | Owns | Never touches |
|---|---|---|
| librarian | `05_Wisdom/`, `11_Readings/` | `10_Journal/` |
| operator | `skills/`, `memory/` | note content |

One agent per task. Keep simple work in the main context — delegation costs a full
context load.
```

**What breaks when ownership is unclear:** two agents editing the same file with
different conventions, which is chapter 09's one-writer rule violated at the agent
level.

Chapter 12 says to start with no specialists and split when a specific conflict forces
it. If you have none, this file says so in one line — which is still worth writing,
because it answers the question.

## SECURITY.md — the boundaries

```markdown
# Security

## Read-only
Never modify: IDENTITY.md, SOUL.md, TOOLS.md, AGENTS.md, SECURITY.md,
HEARTBEAT.md, USER.md, MEMORY.md, CLAUDE.md

## Append-only
Never rewrite existing lines in: memory/*.jsonl, memory/observations.md

## Deletion
Never delete a note. Move it to 90_Archive/ with status: archived.

## Generated output
Never hand-edit a generated dashboard or index. Change the query or the source.

## Ambiguity
Never guess a destination, a person's identity, or a date. Leave the item in place,
tag it #needs-review, and report what was unclear.

## Secrets
Never read, write, or repeat a credential. They live outside this vault.

## Approved exceptions
- `skills/sensor-sync` writes `memory/measurements.jsonl` (append-only) and inserts a
  marker-guarded section into `10_Journal/`. Approved 2026-03-02. Those paths only.
```

**What breaks when this is missing:** destructive edits, or the opposite — an agent so
cautious it asks permission for everything and stops being useful.

The exceptions block is the part that keeps the file honest over time. Chapter 03's
four properties: name the script, the paths, the date, and the mechanism. An exception
without a scope is a hole.

## CLAUDE.md — rules for the coding agent

The collaborative layer needs its own file, because it operates on the system rather
than within it.

```markdown
# Coding agent instructions

This vault is a running system. Two layers write to it: scheduled jobs on a server,
and you, here.

## Before changing anything
Read SECURITY.md and 99_Assets/Templates/CONVENTIONS.md.

## Writable
`skills/`, `99_Assets/`, `docs/`

## Not writable
Root-level `*.md`. Note content, unless the task is explicitly about a note.

## Scripts you write
- Never write to `memory/` without an approved exception in SECURITY.md
- Must be safe to run twice
- Must have a `--dry-run` and a `--vault PATH` flag before being scheduled
```

**What breaks when this is missing:** the collaborative layer breaks the autonomous
layer's assumptions. A script written at your desk on Tuesday and scheduled on
Wednesday, which turns out not to be idempotent, is a corruption you discover on
Friday.

---

## Writing them in the right order

Do not write nine files in an afternoon. Write them as the need appears:

| Order | File | Written when |
|---|---|---|
| 1–2 | `IDENTITY.md`, `SECURITY.md` | Stage 0. Two is enough to start |
| 3 | `TOOLS.md` | When you have three capabilities and their formats have drifted |
| 4 | `HEARTBEAT.md` | With the second scheduled job |
| 5 | `CLAUDE.md` | The first time you build a skill with an agent |
| 6 | `USER.md` | After the second time it asks something it should know |
| 7 | `MEMORY.md` | When `memory/` has more than two files |
| 8 | `SOUL.md` | Before granting any send or post capability |
| 9 | `AGENTS.md` | Only when you actually have specialists |

Every row is a trigger, not a schedule. A rule written before its failure usually
addresses one that was never going to happen, and it costs context on every run
regardless.

## Commit them with reasons

```
governance: never attribute shared-calendar events without a name match

The morning briefing presented another household member's appointment as the
user's own. Data was correct; the interpretation had no ownership rule.
```

When behaviour changes and nobody knows why, the diff of these files is the first
place to look — and in a system where an agent can propose edits, it is the place a
change can arrive without anyone deciding to make it.

---

**Read next:** Part 3 begins with [09 — Anatomy of a Skill](../PART_3_SKILLS/09_anatomy-of-a-skill.md).
