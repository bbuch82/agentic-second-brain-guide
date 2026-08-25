# 20 — Failure Modes

An agentic system does not usually fail by crashing. It fails by finishing. The
job runs, exits zero, writes its log line, and produces nothing — or produces
something confidently wrong — and every monitoring signal you have says the
system is healthy.

> Every failure worth catching in this system exits zero. Success is not evidence.

---

## The catalogue

Each of these was observed in operation, not imagined for this chapter.

| Failure | Symptom | Why nothing alarmed | Fix |
|---|---|---|---|
| Silent skip | A day with no generated entry | The job succeeded. It simply did nothing. | A completion marker per unit of work, checked from outside |
| Silent corruption | Dozens of notes with invalid frontmatter | Nothing parses frontmatter until something needs it | A vault-wide parse check |
| Wrong attribution | Events from a shared calendar assigned to the wrong person | Technically correct, semantically wrong | An explicit attribution rule in the prompt contract |
| Stale source as truth | The agent guesses instead of reporting staleness | The file existed. It was merely old. | A freshness field plus a mandatory degraded path |
| Concurrency artifacts | Sync-conflict files accumulating | No check knew the filename pattern | Baseline the existing ones, alarm only on new |
| Two schedulers, one target | Duplicate sections, conflict files | A laptop scheduler and a server cron ran the same job | Exactly one scheduler per job; disable the other |
| Silent sensor outage | Dashboards show gaps that look like rest days | Expired token, job exits cleanly with zero rows | A freshness check on the log file |
| Tool conflict in a job | A daily error nobody reads | The error went to a log, not to a channel | Restrict tool scope per job; route errors to a human channel |

Eight rows, one shape. In every case the process exited zero and the failure was
visible only in the *contents of the vault*, days or weeks later.

## The three that teach the most

### Silent skip

A nightly job assembles the day's journal entry. One evening it produced nothing.
Not an error — the job started, read its inputs, found a condition it interpreted
as "nothing to do", and exited successfully.

The gap was discovered a week later, by eye, while scrolling.

What makes this the archetype is that **every conventional signal was green**.
Exit code zero. No exception. A log line saying the job ran. Uptime monitoring on
the container: fine. The only evidence was the absence of a file, and nothing was
looking for absences.

The fix is a **completion marker**: the job writes a token into its output —
`<!-- generated: 2026-03-15 -->` — and a separate check asserts that every
completed day has one. The check does not ask whether the job ran. It asks whether
the work exists.

That distinction is the whole of chapter 21.

### Silent corruption

A batch of notes acquired invalid YAML frontmatter — an unescaped colon in a
title, a stray quote. Obsidian rendered them fine. Search found them. Reading
them was normal.

They were broken for exactly one audience: anything that parsed frontmatter. So
they vanished from typed queries, dashboards under-counted, and a "list all
meetings this quarter" answer was quietly incomplete. Nobody noticed, because a
short list looks like a quiet quarter.

The lesson generalises past YAML: **a format nothing validates is a format that
drifts.** Chapter 01 named this as the price of using a file tree, and it comes
due here. The check is trivial — walk the tree, parse every frontmatter block,
report failures — and it will find things on its first run.

### Wrong attribution

A morning briefing told its reader they had a personal appointment. The event was
real, the calendar was correct, the sync was working. The appointment belonged to
someone else in the household, entered into a shared calendar for information.

Nothing malfunctioned. The data was accurate and the interpretation was wrong,
because the job had no rule for whose event an entry in a shared source is.

This is the failure class no health check can catch, and it is worth being clear
about why: correctness here is not a property of the data or the code, but of the
*contract in the prompt*. The fix was an explicit rule — never present another
person's entry as the reader's own; attribute by name prefix or context; when
unsure, stay neutral.

Two consequences follow, and both matter more than the anecdote:

- **A shared data source needs an ownership rule before it is used**, not after
  the first wrong answer.
- **Prompt contracts are part of the system's correctness**, so they belong in
  version control with a reason recorded, exactly like code. Chapter 03's
  governance files are where they live.

## Why these are the hard ones

Compare the two classes of failure:

| | Loud failure | Quiet failure |
|---|---|---|
| Example | Container won't start | Job runs, writes nothing |
| Time to notice | Minutes | Days to weeks |
| Discovered by | Monitoring | Coincidence |
| Data lost | None | Everything in the window |
| Cost of the fix | Restart | Backfill, if the source still has it |

Loud failures are solved. Every hosting platform will tell you a container is
down. Nothing on the market will tell you a container is up and producing
nothing, because that requires knowing what the output was supposed to look
like — and only you know that.

The window matters more than it first appears. A quiet failure lasting three
weeks against a vendor API that keeps thirty days of history is recoverable. The
same failure lasting five weeks is permanent data loss, and you find out during
the backfill.

## A worked example: the checker that could not block

The privacy checker in this repository exists to scan for content that must never
be published and to block the commit. One input file of rules, one decision. As
small as a security gate gets.

It shipped with **ten distinct ways to report success while failing**, and every
one of them was found by asking a different question than "do the tests pass":

| # | Mechanism | Result |
|---|---|---|
| 1 | Word-boundary syntax the local tool did not support | Matched nothing; "no match" is indistinguishable from "no findings" |
| 2 | Single-file input changed grep's output format, breaking a field split | Every structural rule passed unconditionally |
| 3 | A malformed allow-rule made `sed` fail; the empty output was treated as content | Every structural hit discarded |
| 4 | An allow-rule of `.*` blanked whole lines before re-testing | Same, by legitimate syntax |
| 5 | A flag copied from an example made binary files scan as empty | Image metadata never checked |
| 6 | Exit status 2 (invalid pattern) folded into the exit-1 (no match) path | A broken rule neutered itself, silently |
| 7 | A stray argument reintroduced #6 in the code written to fix #5 | Same root cause, different door |
| 8 | A test fixture corrupted by `printf` interpreting an escape | The test passed for an unrelated reason |
| 9 | One rule file consumed by two regex engines with different dialects | An exemption silently did nothing; an unanchored one let a real address through |
| 10 | The exemption list loaded on only one of the tool's two entry points | The pre-commit hook and a manual scan disagreed about the same content |

The full write-up, with the fix for each, is in
[`docs/material/failure-modes-observed.md`](../docs/material/failure-modes-observed.md).

Five things this list is evidence for:

**Tests being green is not coverage.** The suite passed at every stage. Removing
a defence entirely and re-running the suite — mutation, not inspection — was what
proved a whole branch was untested. That check takes a minute and answers a
question inspection cannot.

**An unexpected pass is a bug report.** Entry 8 was caught because a test went
green sooner than it should have. A result that arrives too easily has usually
skipped the thing it claimed to measure.

**Fix classes, not instances.** Entry 7 is entry 6 reappearing in the code written
to fix a neighbouring bug. Patching the case in front of you invites the class
back through another door.

**A flag copied from an example is a decision nobody made.** Entry 5 sat in the
tool from the first draft because it looked like part of the idiom.

That is roughly two hundred lines of shell whose only job is to say no. Scale that
honestly against a system of scheduled jobs, API integrations, and prompt
contracts, and the case for chapter 21 stops being a matter of taste.

## The rule that follows

Every failure in this chapter shares one property, and it dictates the design of
everything in the rest of Part 5:

> Assert on the state of the vault, never on the state of the job.

"Did the job exit zero" is answerable and useless. "Does today's entry exist, does
every note parse, is the log newer than a day" is the same question asked where
the answer lives.

---

**Read next:** [21 — The Watchdog](./21_the-watchdog.md), which builds the process
that asks those questions on a timer.
