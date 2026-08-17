# 01 — The Vault Is the API

Several programs are about to write to your knowledge base: a scheduled job at
five in the morning, a coding agent at your desk, a sync script pulling from a
device API, and you, typing in an editor. The question that decides whether
that ends as infrastructure or as a mess is not which agent you pick. It is
what the four of them agree on.

> The data format is the contract. Every runtime is a client, and any client can be replaced.

---

## The contract

A note is a UTF-8 text file with a YAML frontmatter block and Markdown below it.

```markdown
---
title: "Quarterly planning with Acme"
date: 2026-03-15
tags: [meeting, planning]
type: meeting
status: active
---

# Quarterly planning with Acme

Attendees: [[Doe_Jane]], [[Roe_Richard]]

## Decisions

- Ship the migration behind a flag first. Owner: [[Doe_Jane]].

## Open

- [ ] Confirm the rollback window with Ops #todo
```

That is the whole interface. Five frontmatter fields, wikilinks for references,
tags for cross-cutting facets, task syntax for anything actionable. A program
that can read a text file and parse YAML is a full participant.

Everything else in this guide — the scheduler, the agents, the dashboards, the
health checks — is built on the assumption that this file exists, parses, and
means what its fields say.

## Why a file tree beats a database here

The instinct of most engineers, facing "several writers, shared state, needs
querying", is a database. It is the wrong instinct for this particular problem,
and the reasons are specific rather than ideological.

| Property | What the file tree gives you |
|---|---|
| Readability by any tool | `grep`, `ripgrep`, Python, an agent's file tool, a text editor. No driver, no client library, no connection string. |
| History | git gives you diff, blame, revert, and bisect over your own thinking, for free, forever. |
| Recovery | A corrupted note is one file. A corrupted database is every note. |
| Migration | There is no migration. The format in five years is the format today. |
| Human access | You edit exactly the bytes the agent edits. No export step, no sync layer, no divergence between "the app's view" and "the truth". |
| Failure granularity | A broken write damages one file. Nothing else notices. |
| Longevity | The format outlives every tool named in this guide, including the ones that do not exist yet. |

The last two rows are the ones that matter most in practice, and they are the
ones a database inverts. An agent that writes badly to a file tree produces one
bad file. An agent that writes badly through a schema-enforcing layer either
fails loudly and does nothing, or succeeds and corrupts a shared structure.

## What it costs

A file tree is not a free lunch, and pretending otherwise is how people end up
surprised six months in. Four guarantees a database would give you are simply
absent:

**No referential integrity.** A wikilink to `[[Doe_Jane]]` does not require
that the note exist. Links dangle silently. Nothing tells you.

**No transactions.** A job that writes three files can be interrupted after
two. There is no rollback, so operations have to be individually safe to repeat
instead — the subject of chapter 22.

**No schema enforcement.** Nothing stops a program writing `date: last
Tuesday`. The file will happily hold it, and the failure surfaces weeks later
in whatever tries to sort by date.

**No types.** `status: active` and `status: Active` are different strings, and
both look right to a human skimming.

Every one of these has the same shape: the failure is invisible at write time
and expensive at read time. That is why validation cannot be a property of the
format and has to be a separate, scheduled process that reads the whole tree
and asserts on it. Chapter 21 builds that process. Until then, hold onto the
consequence: **in this architecture, the thing that keeps your data honest runs
on a timer, not at the point of writing.**

## The conventions, and the reason for each

Conventions in a system like this are not style preferences. Each one exists
because a program depends on it.

| Convention | Rule | Why a program needs it |
|---|---|---|
| Daily notes | `YYYY-MM-DD.md` | Lexical sort equals chronological sort. A "find the last entry" query is a directory listing, not a parse of every file. |
| People | `Lastname_Firstname.md` | Stable identity independent of display name, so a link survives a person's name changing. |
| Readings | `YYYY-MM-DD-kebab-title.md` | Date first, so ingestion order is visible without opening anything. |
| Concept notes | `kebab-title.md`, no date | These are not events. A date in the filename implies one and invites duplicates. |
| Wikilinks | `[[Exact_Filename]]`, no extension | One canonical spelling per target, so a link graph can be built by string match rather than by guessing. |
| Tags | lowercase, hyphenated, hierarchical where useful (`#habit/sleep`) | Machine-writable and machine-queryable. Mixed case forks your tag vocabulary in half. |
| Frontmatter `type` | A closed set of values | Lets a query select "all meetings" without heuristics on the path. |
| Frontmatter `status` | A closed set of values | Lets archiving be a field change rather than a move, when a move would break links. |

Write these down in a file the agents read, not in your head. Chapter 03 covers
where they live and what happens when an agent has to guess instead.

### Time series do not go in frontmatter

One exception to "everything is a note", and it is worth stating early because
it is the seam Part 4 is built on. Measurements — steps, sleep, heart rate, any
value produced by a machine once per day — go into append-only JSONL, one
object per line, one line per day:

```
{"date":"2026-03-15","source":"device","steps":8431,"sleep_hours":7.2}
{"date":"2026-03-16","source":"device","steps":11002,"sleep_hours":6.4}
```

Four reasons, and they generalise to any machine-written series:

1. A partial failure costs one line, not a file.
2. Appending is the only write, so no reader can be mid-parse during a write.
3. The last line is the cursor. A sync job that asks "where did I stop" reads
   its own output instead of maintaining a state file that can disagree with
   reality.
4. Thousands of daily records in thousands of notes make every query walk the
   whole tree. In one file, they do not.

A human-readable summary still lands in the day's note, because that is where
the agent will read it as context. The number lives in both places on purpose:
JSONL for querying, prose for reasoning.

## The consequence: runtimes are clients

Here is the test that tells you whether you have built infrastructure or a
demo. Delete the agent. Not disable — delete. Uninstall the runtime, cancel the
API key, remove the container.

What is left?

If the answer is "a folder of Markdown files I can read, search, edit, and
publish from, with a full history", the vault was the system and the agent was
a client. Everything the agent produced is still yours, and swapping in a
different one next year is a configuration change.

If the answer is "a chat history I can no longer query" or "a database in a
format only that tool reads", the agent was the system. The value lives inside
someone else's process, and it leaves when that process does.

This is the property that makes the rest of the architecture possible. Chapter
02 puts two very different runtimes on either side of this contract — one that
runs while you sleep, one that runs while you work — and they never talk to
each other. They both talk to the file tree. That is not a compromise for
simplicity's sake; it is the reason either can be replaced without touching the
other.

### What this rules out

Three tempting designs are incompatible with the contract, and it is worth
naming them because each one arrives disguised as a convenience.

**State in the conversation.** Anything an agent "remembers" from a previous
session but never wrote to a file does not exist. It cannot be queried,
reviewed, backed up, or corrected. If a fact matters, it is a file.

**Derived data checked in as truth.** A generated dashboard, an index, a
summary — none of these are sources. They are caches with a longer refresh
interval. Hand-editing one produces a change that the next regeneration
silently destroys, which is among the most confusing failures in this whole
system precisely because nothing errored.

**A second store for "the structured parts".** The moment structured records
live somewhere the human cannot read with an editor and git cannot diff, you
have two truths and a reconciliation problem, and reconciliation problems are
where quiet data loss lives.

---

**Read next:** [02 — Two Layers](./02_two-layers.md), which puts the autonomous
and collaborative runtimes on either side of this contract and shows why the
seam between them is a directory rather than an interface.
