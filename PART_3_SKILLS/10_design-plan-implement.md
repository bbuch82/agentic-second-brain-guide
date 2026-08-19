# 10 — Design, Plan, Implement

Writing a design document for a forty-line script looks like ceremony. It is the
opposite: it is the only reason the script is still correct after you have
forgotten it, and the only way an agent can extend it without deleting the parts
whose purpose is not visible in the code.

> Code records what the system does. A design document records what it must not do, and why. Only one of those is recoverable from the other.

---

## Three artifacts

| Artifact | Answers | Written when |
|---|---|---|
| `YYYY-MM-DD-<topic>-design.md` | What are we building, why this way, what did we reject | Before any code |
| `YYYY-MM-DD-<topic>-plan.md` | In what order, with what verification per step | After the design is agreed |
| `SKILL.md` | What it does now | Continuously; it is the living contract |

The design and plan are dated and immutable — a record of a decision at a moment.
The contract is current. When they disagree, the contract wins and the design
explains how you got there.

## What goes in a design document

Six sections. Two of them are the point.

```markdown
# Design — inbox processing
Date: 2026-03-02
Status: approved

## Problem
Files accumulate in the inbox faster than they are filed by hand. Filing them
requires reading each one, so it does not batch, and it is skipped when busy.

## Constraints
- Originals are never deleted, only moved (governance).
- Dashboards are query-generated and must not be hand-edited (governance).
- Person notes must use the full template, every field present.
- Must be safe to run twice.

## Approach
The agent classifies; a script writes. Classification needs judgement over prose,
which no rule set covers. Writing needs atomicity and collision handling, which an
agent does inconsistently.

## Rejected
- **Pure script with regex classification.** Tried on 40 real files: 62% correct.
  The failures were confident and wrong, which is worse than unfiled.
- **Pure agent, including file moves.** Correct classification, but two
  copy-then-delete sequences and one silent overwrite in the first week.
- **A queue with human approval per item.** Correct, and unused after four days.
  The friction it adds is exactly the friction it was meant to remove.

## Open questions
- Should low-confidence items be moved to a staging folder rather than left in
  place? Deferred: leaving them is simpler and the inbox is already the staging
  folder.
```

**Rejected** is the section that pays for the document. Without it, the next person
to touch this — including you, including an agent — will propose the pure-script
approach again, because it is the obvious idea. With it, the proposal is answered
in one line and the conversation moves on. Record the alternative *and* the reason
it lost, with a number where you have one.

**Constraints** is the section that prevents regressions. Each line is a promise
some other part of the system relies on. An implementer who has read them cannot
accidentally trade one away for convenience, because trading it away now requires
disagreeing with something written down.

## What goes in a plan

The design says what and why. The plan says in what order, and how each step is
verified.

```markdown
# Plan — inbox processing

## Task 1: Classification matrix
- [ ] Write the matrix into SKILL.md: type, destination, filename pattern
- [ ] Verify: 40 sample files classify correctly by hand-check
- [ ] Commit

## Task 2: The move, with collision handling
- [ ] Write the failing test: existing destination name must not be overwritten
- [ ] Run it; confirm it fails
- [ ] Implement move-with-suffix
- [ ] Run it; confirm it passes
- [ ] Commit

## Task 3: Idempotency
- [ ] Write the failing test: second run against the same vault changes nothing
- [ ] Run it; confirm it fails
- [ ] Implement marker detection
- [ ] Run it; confirm it passes
- [ ] Commit
```

Two properties make a plan worth writing rather than just starting.

**Every task ends in something verifiable.** Not "implement the mover" but "the
test that proves it does not overwrite passes". This is what lets you stop halfway
and resume without wondering whether the last thing worked.

**The test comes before the implementation, and is run before it.** A test written
after the code passes on the first try and proves nothing. Chapter 20's eighth
failure is exactly this: a test that went green for an unrelated reason, caught only
because it went green sooner than it should have. **Confirm the red first.**

## Why this matters more when an agent implements

Working with an agent changes the economics of documentation, in two ways that
point the same direction.

**Context does not persist.** An agent implementing task 3 next week has no memory
of the conversation that produced task 1. The design document is not a courtesy to
your future self; it is the agent's only access to intent.

**Agents remove what they cannot justify.** Asked to simplify a function, an agent
will delete a defensive check whose reason is not stated, because from the code
alone it looks redundant. The reason is invisible: it is a thing that happened once,
in production, at an awkward hour. Written into the design, and referenced in a
comment, it survives.

The practical form of that second point:

```python
# Skip days where the vendor reports no step count at all. A zero is a real
# measurement; a null means the device was not worn, and writing it as zero
# averages into every chart forever. See design 2026-03-02, "Rejected: treat
# missing as zero".
if stats.get("totalSteps") is None:
    return None
```

Four lines of comment on one line of code, and a reference. That ratio is correct
here, because the code is obvious and the *reason* is not.

## When to skip it

The process scales down, and pretending otherwise is how it gets abandoned.

| Change | Artifacts |
|---|---|
| A new capability, or one that writes to the vault | Design, plan, contract |
| A change to an invariant or a threshold | A dated note appended to the contract |
| A bug fix, a rename, a formatting change | The commit message |
| A new dashboard query | Nothing; it is a read |

The dividing line is whether the change alters what other things can rely on. A
threshold is not a detail — chapter 16 explained that it encodes a judgement, so
changing it changes the meaning of every record written afterwards. That gets a
dated line. A renamed variable does not.

## The history section

The contract carries a short log of what changed and what caused it:

```markdown
## History

Design: `2026-03-02-inbox-processing-design.md`.

- **2026-03-14** — Added the area-detection keyword list. A transcript was filed
  to the wrong area because classification relied on the filename alone.
- **2026-04-02** — Low-confidence items now stay in place and are tagged rather
  than moved to a best guess. Two wrong destinations in one week.
```

This is the cheapest high-value documentation in the whole system. Each line is a
sentence, and together they answer the question that otherwise costs an hour of
archaeology: *why is it like this?* Note that both entries above are reactions to a
specific failure — that is the normal case, and recording the trigger is what makes
the entry worth reading.

---

**Read next:** [11 — Four Patterns](./11_four-patterns.md), which implements the
four shapes that cover most of what anyone needs.
