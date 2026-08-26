# 12 — Skill Inventory

What a system of this kind ends up running after a year. Not a prescription — a
menu. Most readers will recognise five they want, and the point of the table is to
make those five obvious rather than to suggest you need thirty.

> A skill that is not in the inventory is a capability nothing knows should be running. That is how a pipeline dies unnoticed.

---

## Capture

Getting things in with as little friction as possible.

| Skill | Trigger | Code | Writes |
|---|---|---|---|
| `process-inbox` | Nightly, or on demand | Mixed | Everywhere; empties the inbox |
| `link-reader` | A URL in a message | Mixed | `11_Readings/Articles/` |
| `video-notes` | A video URL alone in a message | Yes | `11_Readings/Video/` |
| `voice-notes` | An audio file | Mixed | Transcript, then routed like the inbox |
| `quick-capture` | A prefixed message (`n:`, `t:`, `q:`) | Spec | The matching list or note |

`quick-capture` is the highest-value item in the whole inventory relative to its
size. A one-character prefix that routes a thought to the right file removes the
decision that otherwise stops you capturing at all.

## Meetings and people

| Skill | Trigger | Code | Writes |
|---|---|---|---|
| `process-meetings` | A transcript appears | Spec | `<Area>/Meetings/`, plus journal and people links |
| `add-contact` | A new person is mentioned | Spec | `40_Network/People/First Last.md` |
| `sync-people-index` | After any person change | Yes | `40_Network/PEOPLE_INDEX.md`, regenerated |
| `contacts-import` | Manual, after an export | Yes | Guarded blocks in person notes |

The template rule from chapter 03 applies hardest here: a person note always uses
every field, with unknowns left empty. Partial templates are why a person query
returns three people when you have four hundred.

## Distillation

The pipeline that turns intake into something you will actually reread.

| Skill | Trigger | Code | Writes |
|---|---|---|---|
| `distill` | Nightly, batched | Yes | `05_Wisdom/` concept notes |
| `deepen` | Weekly, batched | Yes | Expands existing concept notes |
| `tagger` | Batched, on demand | Yes | Frontmatter tags across notes |
| `compile` | Manual | Yes | Long-form drafts from concept notes |

This is the chain where the system stops being storage. Chapter 13 walks it end to
end. Note that all four are batch pipelines — the same pattern four times, with
different judgement inside.

## Routines

| Skill | Trigger | Code | Writes |
|---|---|---|---|
| `daily-note` | 05:00 | Yes | Today's note from the template |
| `morning-briefing` | 07:00 | Spec | The chat channel |
| `evening-weave` | 21:00 | Mixed | Today's note; sets the completion marker |
| `weekly-review` | Sunday | Spec | `10_Journal/Notes/` |
| `monthly-review` | Month end | Spec | `10_Journal/Notes/` |

`evening-weave` is the one to build first, because it writes the completion marker
that chapter 21's completeness check asserts on. A routine with no observable output
cannot be monitored.

## External systems

Each of these is an external sync, and each is a standing maintenance cost.

| Skill | Trigger | Code | Writes |
|---|---|---|---|
| `sensor-sync` | 07:00 | Yes | `memory/measurements.jsonl`, journal sections |
| `calendar-sync` | Every 30 min | Yes | `00_Start/Calendar.md` with a freshness field |
| `tasks-sync` | Hourly | Yes | Task state, both directions |
| `tracker-sync` | Every 2 h | Yes | A work snapshot note |
| `recorder-sync` | Every 2 h | Yes | Transcripts into the inbox |

Be deliberate about how many of these you run. Every one is an API that can change
without notice, a token that will expire, and a freshness check to maintain.
Chapter 04 put a number on it: an hour or two per integration per year, plus
whatever the failure costs before you notice.

## Operations

| Skill | Trigger | Code | Writes |
|---|---|---|---|
| `git-sync` | Every 5 min | Yes | Commits and pushes the vault |
| `watchdog` | Every 15 min | Yes | Alerts, plus `memory/system_health.md` |
| `privacy-check` | Pre-commit | Yes | Nothing; blocks |
| `add-area` | Manual | Spec | A new area skeleton |

Four skills, and they are the ones nobody demos. They are also the difference
between a system you rely on and one you check on.

---

## Reading the table

**Code column.** `Yes` means a script owns the operation. `Spec` means the agent
performs it from a written contract. `Mixed` means the agent decides and a script
writes — chapter 09's split, and the most common answer for anything that touches
files.

Counted up, roughly half have an implementation. That ratio is worth noticing: the
other half are capabilities that exist purely as well-written contracts, which is
only possible because the format is plain text and the rules are written down.

**Trigger column.** Everything on a clock belongs to the autonomous layer and needs
a documented fallback for ambiguity. Everything triggered manually or by a message
can ask you a question instead.

## What to build first

In order, and stop when the next one is not solving a problem you have:

| # | Skill | Why first |
|---|---|---|
| 1 | `quick-capture` | Nothing else matters if capture has friction |
| 2 | `daily-note` | Gives everything else a place to land |
| 3 | `process-inbox` | Turns capture into structure |
| 4 | `evening-weave` | Produces the marker the watchdog needs |
| 5 | `watchdog` | From here on, failures are visible |
| 6 | `distill` | The first skill that creates something new |

The order is not arbitrary: each one makes the next worth having, and the watchdog
arrives at position five because that is the point where the system starts doing
things you would not notice stopping.

### What not to build early

| Skill | Wait until |
|---|---|
| Anything with a second external API | The first one has run for a month without attention |
| `compile` or long-form generation | You have a few hundred concept notes for it to draw on |
| A second dashboard | The first one has changed a decision |
| A specialist agent per domain | One general contract has demonstrably failed |

The last row deserves a note, because the temptation is strong and early. Splitting
into specialists feels like architecture, but it multiplies the number of contracts
that can disagree about the same file, and chapter 09's one-writer rule gets much
harder to hold. Start with one set of rules and split when a specific conflict
forces it.

---

**Read next:** [13 — Composing Pipelines](./13_composing-pipelines.md), on how these
connect into something more than a list.
