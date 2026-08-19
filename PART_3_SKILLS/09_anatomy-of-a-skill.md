# 09 — Anatomy of a Skill

A capability described only in a prompt cannot be versioned, tested, or reviewed.
It works until the day it quietly stops, and then there is nothing to diff. A
skill is the same capability made into an artifact.

> A capability you cannot version, test, or read is not a capability. It is a prompt you got lucky with.

---

## What a skill is

A directory. A specification, always. An implementation, sometimes.

```
skills/process-inbox/
  SKILL.md          the contract — always present
  process.py        the implementation — only when determinism is needed
  test/             tests — only when there is code
```

That is the whole structure. What makes it a skill rather than a folder is the
contract, and what makes the contract useful is that it is written for a reader
with no memory of the conversation that produced it — which includes an agent in a
session six months from now.

## The contract

`SKILL.md` answers six questions in a fixed order. Fixed, because an agent
scanning for one of them should not have to read the others.

```markdown
# Skill: process-inbox

## Purpose
Classify every file in the inbox, move it to its destination, ensure it has
frontmatter, and cross-link it — so the inbox ends empty or holding only items
that need a human.

## Trigger
Invoked manually, or by the nightly routine at 22:00.

## Inputs
Files in `00_Start/Inbox/`. Any Markdown; no naming convention assumed.

## Outputs
- The file, moved to its destination with normalised frontmatter
- A wikilink to it from the relevant journal entry
- Person notes created or updated for anyone mentioned
- Anything unclassifiable left in place and tagged `#needs-review`

## Invariants
1. Originals are moved with `mv`, never copied and deleted.
2. Root-level system files are never modified.
3. Generated dashboards are never edited; tasks go in the destination file.
4. Every follow-up note links back to the original.

## Failure behaviour
On an unrecognised type: leave the file, tag it, report what was unclear.
On a missing destination directory: create it.
On a name collision: append a numeric suffix; never overwrite.
```

Two sections carry most of the weight, and they are the two that get left out.

**Invariants** are the promises. They exist so a later change cannot silently
break something the rest of the system depends on — and so an agent implementing
this skill has a list it can check its own work against. Numbered, because a review
comment can then cite invariant 3.

**Failure behaviour** is what makes the skill safe to run unattended. Chapter 02
called a documented escape hatch the price of admission to the autonomous layer;
this is where the escape hatch is written down. A skill without it is a skill that
guesses.

## Code or specification?

The decision that shapes everything else.

| Write code when | Keep it specification-only when |
|---|---|
| The operation must be deterministic | The operation needs judgement |
| It runs unattended on a schedule | A human is present |
| It must be idempotent | Each run is a fresh decision |
| It talks to an API with a fixed schema | It reads prose and decides what it means |
| The same input must always produce the same output | The right answer depends on context |

Most interesting skills are **mixed**, and the split within them is always the
same: the agent decides *what*, the script guarantees *how*.

Filing an inbox item is the canonical example. Deciding that a transcript belongs
to a particular work area is judgement — it needs to weigh names, topics and
context, and no `if` statement will do it. Moving the file safely, normalising the
frontmatter, and refusing to overwrite an existing name is mechanism, and an agent
doing it by hand will occasionally get it wrong in a way that loses data.

So: the agent classifies, the script writes. Neither does the other's job.

## The cost of skipping the specification

A skill with only an implementation is a script, and it degrades predictably:

| After | What happens |
|---|---|
| Two weeks | You remember why the odd branch exists |
| Two months | You do not, but you recognise the code |
| Six months | An agent asked to modify it removes the odd branch, because nothing said why it was there |

That last row is not hypothetical, and it is specific to working with agents. An
agent reads the code and infers intent from it. Where the code's intent is not
recoverable from the code — a threshold, a skipped case, a defensive check for
something that happened once — the inference will be confident and wrong.

The specification is where intent lives. Chapter 10 pushes this one step further:
for anything non-trivial, the reason goes in a dated design document before the
code exists.

## Where the boundaries go

Skills should be composable, which means each one owns a stage rather than a
feature.

| Good boundary | Why |
|---|---|
| One directory of the vault | Ownership is unambiguous |
| One external system | Its authentication and rate limits stay in one place |
| One transformation | Testable in isolation; reusable by the next stage |

| Bad boundary | Why |
|---|---|
| "Everything about health" | Spans a device API, a journal writer and a dashboard. Three failure modes, one blast radius |
| "Tidy up the vault" | No definable output, so nothing can assert it worked |
| A skill that calls three others | Composition belongs in a routine, not inside a skill |

The test that settles it: **can you state this skill's output as a file, or a
change to a file?** If not, the boundary is wrong. "Files the inbox" has an
output. "Improves organisation" does not, and a skill whose success cannot be
observed cannot be checked by chapter 21.

## One writer per file

Two skills that can write the same file will eventually write it differently, and
the second to run wins. So every generated file names its owner, in the owning
skill's contract:

```markdown
## Outputs
- `40_Network/PEOPLE_INDEX.md` — fully regenerated. This skill is its sole writer.
```

Where two skills genuinely need to contribute to one file, they use guarded blocks
with distinct owners rather than sharing the whole file. Chapter 22 covers the
mechanism.

## Naming and inventory

Name for the action, not the domain: `process-inbox`, `sync-calendar`,
`distill-readings`. A verb tells you what invoking it does; a noun leaves you
guessing whether it reads or writes.

Keep an inventory — chapter 12 is one — and treat it as operational rather than
documentary. A skill that is not in the inventory is a skill nothing knows should
be running, which is exactly the third symptom from chapter 03: a capability that
stopped weeks ago with nothing to notice.

---

**Read next:** [10 — Design, Plan, Implement](./10_design-plan-implement.md), on
why a forty-line script gets a design document.
