# 13 — Composing Pipelines

A list of skills is a toolbox. What makes the system feel like one thing is that
each skill's output satisfies the same contract, so the next one can consume it
without knowing anything about how it was produced.

> Skills are not features. They are stages, and the only reason they compose is that every stage writes a file the next stage already knows how to read.

---

## The capture pipeline

```
  anything                                        something you reread
      │                                                    ▲
      ▼                                                    │
  ┌────────┐   ┌──────────┐   ┌────────┐   ┌─────────┐  ┌──┴───┐
  │ inbox  │──▶│ classify │──▶│  file  │──▶│  link   │─▶│distil│
  └────────┘   └──────────┘   └────────┘   └─────────┘  └──┬───┘
   a file       a decision      a path      a graph        │
   exists       recorded        that is     that is     ┌──▼───┐
                                stable     traversable │deepen│
                                                        └──┬───┘
                                                        ┌──▼───┐
                                                        │compile│
                                                        └──────┘
```

Six stages. What travels between them is never a function call, a queue, or a
message — it is a file that satisfies chapter 01's contract. That is the property
worth internalising, because it is what makes every other property possible.

| Arrow | The contract it satisfies |
|---|---|
| inbox → classify | A Markdown file exists in a known directory |
| classify → file | A destination and a filename have been decided and recorded |
| file → link | The file is at a stable path with valid frontmatter |
| link → distil | Wikilinks resolve, so the note has neighbours |
| distil → deepen | A concept note exists with a `type` a query can select |
| deepen → compile | Concept notes carry enough substance to draw from |

## Why this beats an orchestrator

The obvious alternative is one job that does all six, or a framework that wires
them together. Both are worse here, for reasons that are specific rather than
stylistic.

**Every stage is independently runnable.** Distillation can process a year of
backlog without touching the classifier. A single note can be pushed through one
stage by hand while debugging.

**Every stage is independently testable.** Its input is files, its output is files.
A test is a scratch vault, a run, and an assertion — chapter 22's snapshot test
works on any stage without modification.

**A stage failing does not stop the others.** The classifier being broken means
items accumulate in the inbox. Distillation carries on with what is already filed.
Compare that with an orchestrator, where a failure halfway leaves the run in a
state nobody designed.

**Stages can run on different schedules, in different places.** Classification
nightly on the server, compilation manually on a laptop when you actually want a
draft. No coordination needed, because there is no shared runtime — only shared
files.

**You can insert a stage without touching its neighbours.** Adding `tagger`
between filing and distillation means writing one skill whose input and output are
both notes. Nothing upstream or downstream changes, because nothing upstream or
downstream knew about the pipeline in the first place.

That last point is the real test of the design. In an orchestrated system, adding a
step means editing the orchestrator, which means every step now depends on it.

## What each stage owns

| Stage | Owns | Never touches |
|---|---|---|
| classify | The decision and where it is recorded | The file's content |
| file | The path and collision handling | The classification |
| link | Journal and person cross-references | The filed note's body |
| distil | `05_Wisdom/` concept notes | Its source notes, except the done marker |
| deepen | The body of existing concept notes | Which notes exist |
| compile | Drafts in a separate directory | Anything upstream |

The right-hand column is what keeps this composable. `distil` reading its sources
but writing only elsewhere means it can be re-run at any time against any subset.
The moment a stage edits its own input beyond a marker, the pipeline acquires an
order dependency that nothing enforces.

## Idempotency is what makes the composition safe

Each stage is individually repeatable — chapter 22 — which means the *whole
pipeline* is repeatable. That has a practical consequence worth stating outright:

**There is no recovery procedure for a partial run.** If the nightly job dies after
filing but before linking, the next run files nothing new and links what is
missing. No cleanup, no rollback, no half-state to reason about.

Compare that with a transactional design, where an interrupted run needs a
deliberate answer about what to undo. Here the answer is "run it again", and it is
the same answer for every stage and every combination of them.

## Where composition ends

Two limits, both worth respecting rather than engineering around.

**Fan-in needs an owner.** When two stages write to one file, chapter 09's
one-writer rule applies: use guarded blocks with named owners, or give one stage the
file and have the other produce input for it. Do not let both write freely and hope
the ordering holds.

**Cross-stage judgement does not compose.** A question like "does this article
contradict a concept note from last year" needs both in one context at once. That
is not a pipeline stage; it is a session in the collaborative layer. Chapter 02's
split applies inside the pipeline as much as outside it — and the honest version is
that the interesting synthesis mostly happens there, with a human present, not on a
schedule.

## A worked trace

One item, end to end, with what exists after each step:

| Step | State after |
|---|---|
| A transcript lands in the inbox | One file, no frontmatter, arbitrary name |
| `process-inbox` classifies it | A decision: work meeting, area Acme |
| It is moved | `20_Areas/Acme/Meetings/2026-03-15 Planning.md`, frontmatter normalised |
| Cross-links are written | Today's journal links to it; two person notes mention it |
| Tasks are extracted | Two `- [ ] … #todo` lines in the meeting file itself |
| `distil` runs that night | A concept note in `05_Wisdom/` citing it |
| `deepen` runs that week | The concept note gains a section, still citing it |
| `compile` runs in a month | A draft that draws on the concept note |

Note where the tasks went: into the meeting file, not into a central task list. The
generated dashboard collects them by querying paths, so the task lives with its
context and the dashboard stays a read. That is chapter 03's rule about generated
files, applied to the thing people most want to hand-edit.

Nine steps, six skills, four schedules, no orchestrator. Every arrow is a file.

---

**Read next:** Part 4 begins with [14 — The Sensor Loop](../PART_4_SENSORS/14_the-sensor-loop.md),
which applies this shape to data that arrives from a device rather than from you.
