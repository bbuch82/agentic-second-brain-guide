# 14 — The Sensor Loop

A wearable produces a few dozen numbers about you every day, and its vendor's
app shows them back to you in isolation. The interesting questions are not
answerable there, because they need a second dataset the vendor does not have:
the record of what you were doing, deciding, and feeling on those days.

> The vendor has your sensor data. The vendor does not have your journal.

This part builds the loop that puts both in one place. This chapter is the
architecture; the five that follow are the implementation.

---

## The chain

```
  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐
  │  device  │───▶│  vendor  │───▶│   sync   │───▶│ measurements │
  │          │    │   API    │    │   job    │    │ .jsonl       │
  └──────────┘    └──────────┘    └────┬─────┘    └──────┬───────┘
     you wear it     you don't        │ scheduled       │ append-only
                     control it       │ idempotent      │
                                      │                 │
                                      ▼                 │
                              ┌──────────────┐          │
                              │ day's note   │          │
                              │ ## Device    │          │
                              │ + #habit/... │          │
                              └──────┬───────┘          │
                                 idempotent             │
                                 via marker             │
                                      │                 │
                                      └────────┬────────┘
                                               │
                                        ┌──────▼───────┐
                                        │  dashboard   │
                                        │  query block │
                                        └──────────────┘
                                          derived, never edited
```

Seven hops. Each one exists for a reason, and each seam has a contract that the
next hop depends on.

| Hop | Contract | Failure property |
|---|---|---|
| device → vendor API | The device syncs when it feels like it. Yesterday may not exist yet. | Missing, not wrong |
| vendor API → sync job | Authenticated read, rate-limited, schema you do not own | Can break without notice |
| sync job → JSONL | One object per line, one line per day, append only | Partial write costs one line |
| sync job → day's note | A marker section, written once | Re-runs are no-ops |
| day's note → tags | A documented tag vocabulary | Three producers, one query |
| JSONL + tags → dashboard | Read-only queries over both | Always safe to re-run |
| dashboard → you | Derived output, never hand-edited | Regeneration overwrites edits |

## Why the measurements do not live in the notes

The obvious design is to put the numbers in each day's frontmatter. It fails for
four reasons, and they are worth understanding because they generalise to every
machine-written series you will add later.

**Rewrites versus appends.** Frontmatter is a mutable block in a file a human
also edits. A sync job updating it has to read, parse, modify, and write the
whole note — four steps, each of which can fail, on a file you might have open.
Appending a line to a log has one step and no parse.

**Query cost.** "Show the last ninety days of resting heart rate" over
frontmatter means opening ninety files and parsing ninety YAML blocks. Over a
log, it means reading one file and filtering. At a few hundred days this is a
noticeable delay in a dashboard; at a few thousand it is a broken dashboard.

**Partial data.** Vendors expose some fields only for the most recent day and
provide no history for them. A log can hold a line where those fields are absent
and a reader can tolerate it. Frontmatter with sometimes-present keys turns
every consumer into a special-case handler.

**Recovery.** A log is reconstructible: delete the bad lines, re-run the sync
for that range. Frontmatter spread across hundreds of notes is not, because the
notes also contain prose you cannot regenerate.

### And why a summary still goes in the note

Because the agent reads notes, not logs. When it drafts an evening entry or
answers "how was last week", the day's note is its context window. A compact
human-readable block in the note is what makes the numbers *reasoned about*
rather than merely stored:

```markdown
## Device

Steps 8,431 · Sleep 7.2 h (score 78, good) · Resting HR 54 bpm · HRV 42 ms
Activity: 42 min run, 7.8 km, avg HR 148

#habit/movement #habit/sleep
```

The same numbers exist in the log for querying and in the note for reasoning.
That is deliberate duplication with a clear owner: the log is the source, the
note's block is generated from it, and nothing reads the note's block
programmatically. If they disagree, the log wins and the block is regenerated.

## Two logs, not one

The first version of any sync writes one log. The second version splits it,
because two kinds of measurement have incompatible catch-up semantics.

| Log | Contents | Catch-up |
|---|---|---|
| `measurements.jsonl` | Daily values the vendor keeps history for: steps, sleep, heart rate, activities | Ask for any past date, get that date's values |
| `derived.jsonl` | Vendor-computed scores that only exist for "now": fitness estimates, readiness, race predictions | Only today is retrievable. Yesterday is gone. |

Mixing them means the second category silently poisons the first: a backfill
run writes today's readiness score onto a date three weeks ago, because that is
the only value the API will hand back. Nothing errors. The dashboard then shows
a flat line where there should be a trend, and the flatness looks like a
finding rather than a bug.

Two files, two catch-up strategies, two readers. The split costs about thirty
lines and prevents a class of wrong conclusions.

## Tags are the third seam

The habit tags in that generated block are the loop's most interesting
interface, because they have **three independent producers**:

- the sync job, from a threshold on a measurement
- an agent, during a conversation ("log that I read tonight")
- you, typing `#habit/reading` in an editor

and exactly one consumer: the dashboard query that aggregates them. That works
only because the tag vocabulary is a written contract rather than an emergent
habit. Chapter 16 covers the vocabulary and, more importantly, where the
threshold that turns a number into a boolean belongs — which is in the producer,
never in the query.

## What the loop is worth

With both datasets behind one query engine, the questions change shape. Not
because the analysis is clever, but because the join is finally possible:

- resting heart rate against weeks you logged travel
- sleep score against days a difficult conversation appears in the journal
- training volume against your own recorded assessment of focus
- a habit streak against the month a project shipped

No fitness application can answer any of these. It has one of the two columns.
Chapter 19 makes this the general argument for the whole system: the value of a
second brain scales with how many domains share a single query surface, which is
why the vault is the centre and the agent is not.

## What can go wrong, in order of how quietly it happens

Preview of Part 5, listed here because the loop is where most of these were
first observed:

| Failure | How quiet |
|---|---|
| Expired auth token; job exits cleanly with zero new rows | Silent. Dashboards show gaps that look like rest days. |
| Device not synced; the day genuinely has no data | Silent, and correct — must not be written as zeroes. |
| Two schedulers running the same job against one vault | Loud eventually: duplicate sections and conflict files. |
| Vendor changes a field name | Silent per-field. Everything else keeps working. |
| A derived score backfilled onto a past date | Silent, and produces a plausible wrong chart. |

Every one of them exits zero. That is why chapter 21's health checks assert on
the state of the vault — is the log fresh, does every recent day have its marker
— rather than on whether the job ran.

---

**Read next:** [15 — Building the Sync](./15_building-the-sync.md), which
implements the first four hops: authentication without a password in the script,
catch-up that derives its cursor from its own output, and idempotency via a
marker section.
