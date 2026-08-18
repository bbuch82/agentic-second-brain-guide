# 02 — Two Layers

Some work has to happen whether or not you are awake: the briefing at seven, the
sync at five, the health check every fifteen minutes. Other work only makes sense
with you in the room: designing a new capability, deciding what a messy note
means, changing the rules the system runs on. Putting both in one place is the
most common way this architecture fails.

> The autonomous layer must never need a human. The collaborative layer must never be needed by a schedule.

---

## The split

```
        AUTONOMOUS                        COLLABORATIVE
        (runs without you)                (runs with you)

  ┌────────────────────────┐        ┌────────────────────────┐
  │ Agent runtime on a VPS │        │ Coding agent, local    │
  │  · scheduled jobs      │        │  · builds capabilities │
  │  · device and API syncs│        │  · refactors the vault │
  │  · health checks       │        │  · edits the rules     │
  │  · chat interface      │        │ Desktop agent with MCP │
  │                        │        │  · reads live systems  │
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

Look at what is missing: **no arrow runs from one runtime to the other.** They do
not call each other, share no state, and hold no reference to each other's
existence. Everything meets in the file tree.

That is not a simplification for the diagram's sake. It is the property that
makes either side replaceable without touching the other, and it is the whole
reason chapter 01 insisted the format was the contract.

## Which work goes where

The test is a single question: **can this complete without a decision?**

| Work | Layer | Why |
|---|---|---|
| Fetch yesterday's measurements | Autonomous | Deterministic. Either the data is there or the day is skipped. |
| Assemble the morning briefing | Autonomous | Reads files, applies a template. No judgement required. |
| File an inbox item into the right folder | Autonomous | Classification with a documented fallback: when unsure, leave it and flag it. |
| Check that yesterday's journal entry exists | Autonomous | An assertion. True or false. |
| Decide what a half-finished note was for | Collaborative | Needs context only you have. |
| Write a new capability | Collaborative | Design decisions, trade-offs, tests. |
| Change a threshold, a rule, or a convention | Collaborative | Changes the system's behaviour. Never let a schedule do this. |
| Restructure a folder that has outgrown itself | Collaborative | Wide-reaching, needs review before and after. |
| Read a live inbox or ticket queue and draw conclusions | Collaborative | The source is not durable state — see below. |

Note the third row. Classification *looks* like judgement, and it is the
interesting case. It belongs in the autonomous layer only because it has a
documented escape hatch: an item it cannot classify confidently stays where it
is and gets flagged for you. A classifier without that fallback is judgement
wearing a schedule, and it will make confident wrong decisions at five in the
morning for weeks before you notice.

**Any autonomous job that meets ambiguity must have a defined way to stop and
leave a trace.** That is the price of admission to the layer.

## What goes wrong when the split is wrong

Both directions fail, and they fail differently.

### A decision encoded as a schedule

A job that needs an answer cannot get one at five in the morning, so it does
whatever its prompt makes most likely. The output is confident, plausible, and
sometimes wrong — and it is wrong in a file that other things now read.

The symptom is not an error. It is a slowly accumulating drift: notes filed to
almost-right places, links to people who do not exist, a summary that misread
which of two projects a meeting was about. Each instance is small enough to
ignore, and there is no single moment where it becomes obvious.

The fix is not a better prompt. It is moving the decision to the other layer, or
giving the job a fallback that leaves the ambiguity visible.

### Interactive work that a schedule depends on

The mirror image: a nightly summary that only works if you first curated the
inbox that evening. The chain now has a human link, and the human link is the one
that breaks first — on a holiday, on a busy Thursday, when you are ill.

The failure is quiet in the worst way, because the job still runs. It runs
against stale input and produces yesterday's answer with today's date on it.

The fix is to make the autonomous side degrade explicitly: if the input is older
than it should be, say so rather than proceeding. Which brings us to the rule
that shows up in every chapter of Part 5.

## Live systems are not state

The collaborative layer has a second, less obvious member: an agent on your
machine with connectors into live systems — mail, chat, tickets, calendars. It is
enormously useful and it needs one hard rule.

**Read live systems at session time. Write only their conclusions to the vault.**

Mail, chat and ticket queues are not durable state. They change under you, they
are owned by someone else, and their history is not yours. A scheduled job that
depends on reading them inherits every one of those properties, plus an
authentication surface that will expire at the worst possible moment.

So the pattern is: the session reads the live systems, forms a conclusion, and
writes the conclusion — as a note, with a date, in the vault. Tomorrow's
autonomous job reads the conclusion, not the inbox. The live system was an input
to a decision; the vault holds the decision.

This also fixes a subtler problem. A conclusion in the vault can be reviewed,
corrected, and cited later. A conclusion that lives only in the agent's reading
of an inbox cannot be any of those, because the inbox has moved on.

## Freshness is part of every contract

Because the two layers communicate only through files, and files can be stale,
every file that crosses the seam needs to say when it was written.

```markdown
---
title: "Calendar"
updated: 2026-03-15T06:30:00
sources: [work, personal]
degraded: false
---
```

The consumer's obligation is the important half:

| State | What the consumer must do |
|---|---|
| Fresh | Use it |
| Older than its expected interval | Say it is stale. Do not guess the missing part. |
| `degraded: true` — written, but a source failed | Use what is there and name what is missing |

The failure this prevents is the most annoying one in the whole system: a
briefing that confidently describes an empty day because the calendar sync broke
two days ago. Nothing errored. The file existed. It was simply old, and nothing
in the pipeline had an opinion about age.

**A generated file without a timestamp is a file that can lie to you
indefinitely.** Chapter 21 turns this into an automated check; the contract here
is what makes the check possible.

## Where the layers physically live

The split is logical, not geographical, but in practice it maps to hardware, and
the mapping matters for one reason.

| | Autonomous | Collaborative |
|---|---|---|
| Host | A small always-on server | Your laptop |
| Runs | On a schedule, unattended | When you start it |
| Availability requirement | Must survive a closed lid | None |
| Cost of downtime | A missed day, silently | You notice immediately |

The reason the autonomous layer wants its own always-on host is not performance.
It is that a laptop's sleep schedule becomes your system's availability, and a
missed nightly job is exactly the kind of failure that leaves no trace. Chapter
06 provisions that host.

And the rule that follows from having two capable machines, learned the
expensive way: **exactly one scheduler per job.** When the same sync can run on
both the laptop and the server, running both produces duplicate writes and file
conflicts. Choose one, and disable the other rather than merely not using it. A
scheduler you have stopped invoking is still a scheduler.

---

**Read next:** [03 — Governance as Code](./03_governance-as-code.md), on the
files that tell both layers what they are allowed to do — and what happens when
those files are vague.
