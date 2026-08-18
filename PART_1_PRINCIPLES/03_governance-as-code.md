# 03 — Governance as Code

An agent with write access to your files will do exactly what its instructions
permit, including the things you assumed were obviously off-limits. There is no
shared common sense to fall back on — only what is written down, loaded into
context, and specific enough to act on.

> Every rule you keep in your head instead of in a file is a rule the system does not have.

---

## Nine files, one constitution

These live at the vault root, are read on every run, and are the only place the
system's rules exist.

| File | Answers | What breaks when it is vague |
|---|---|---|
| `IDENTITY.md` | Who the agent is; how it speaks | A sycophantic assistant that agrees with everything and pads every answer |
| `SOUL.md` | What it values; what it refuses | It does something socially costly on your behalf — sends, replies, commits |
| `TOOLS.md` | What it can do, and the exact output format for each | Freelance formats. Two capabilities write the same file two ways |
| `HEARTBEAT.md` | Which routines run when | Overlapping jobs, or a job nobody remembers scheduling |
| `USER.md` | Facts about you it should not have to ask twice | It asks again, or worse, guesses |
| `MEMORY.md` | An index of what is remembered and where | It reads everything and burns the context budget, or reads nothing |
| `AGENTS.md` | Which specialists exist and what each owns | Two agents edit the same file with different conventions |
| `SECURITY.md` | Read-only zones, forbidden operations, escalation | Destructive edits, or a system too timid to be useful |
| `CLAUDE.md` (or equivalent) | The rules the coding agent itself obeys | The collaborative layer breaks the autonomous layer's assumptions |

Keep them small. Every one is loaded on every run, so a file that grows to two
thousand lines is a recurring cost on every single operation — the constraint
chapter 24 quantifies. The discipline is to write rules, not documentation.

## The rules that actually matter

Most governance text is decoration. These six earn their place, and each one
exists because its absence causes a specific, observed failure.

### 1. Read-only zones

The files that define the agent's behaviour must not be writable by the agent.

```markdown
## Read-only

Never modify: IDENTITY.md, SOUL.md, TOOLS.md, AGENTS.md, SECURITY.md,
HEARTBEAT.md, USER.md, MEMORY.md, CLAUDE.md

If a change to any of these seems necessary, say so and stop.
```

The reasoning is not that the agent would rewrite them maliciously. It is that an
agent asked to "clean up the vault" or "make the conventions consistent" will
helpfully improve its own constraints, and the change arrives inside a diff of
forty other files. An agent that can edit its own rules has no rules; it has
preferences.

### 2. Append-only zones

Structured logs record history. History is not editable.

```markdown
## Append-only

Never rewrite existing lines in: memory/*.jsonl, memory/observations.md
New information is a new line.
```

Without this, a job "correcting" yesterday's record destroys the only evidence of
what was originally observed. The correction is usually right, which is what
makes the pattern so hard to notice.

### 3. Never delete — archive

```markdown
## Deletion

Do not delete notes. Move them to 90_Archive/ with status: archived.
```

An agent's mistaken deletion is unrecoverable *from the agent's point of view*:
it has no way to know something used to exist. Git will save you if the deletion
was committed, but the loop between deletion and your next look at the vault can
be days. Archiving makes the operation reversible without needing git at all.

### 4. Documented exceptions

Every general rule eventually meets a legitimate exception. The exception is fine.
An *undocumented* exception is what rots the rule.

```markdown
## Approved exception — device sync

skills/sensor-sync writes to memory/measurements.jsonl and 10_Journal/,
which the general rule reserves. Approved 2026-03-02. Append-only for the log;
marker-guarded insertion for journal notes. Scope: those paths only.
```

Written next to the script, not in a commit message and not in someone's memory.
Four properties make it safe: it names the script, the paths, the date, and the
mechanism that keeps it safe. An exception without a scope is a hole; an exception
without a date is folklore.

### 5. Generated files are never hand-edited

```markdown
## Generated output

TASKS.md, PEOPLE_INDEX.md and every dashboard are generated. Never edit them
directly. To change what they show, change the query or the source.
```

This is the rule people break first, because hand-editing a dashboard works
perfectly — right up to the next regeneration, which silently discards the edit.
Nothing errors, and the change simply evaporates. It is among the most confusing
failures in the system precisely because there is nothing to debug.

### 6. Ambiguity stops, visibly

```markdown
## When unsure

Do not guess at a destination, a person's identity, or a date. Leave the item
where it is, tag it #needs-review, and report what was unclear.
```

Chapter 02 named this as the price of admission to the autonomous layer. This is
where it is written down. Note that the instruction is not merely "ask" — an
unattended job has nobody to ask. It has to leave a durable trace that a human
will encounter later, which is why the tag matters more than the message.

## Output rules belong here too

A capability's output format is governance, not style, because other things parse
it. Two rules that prevent a lot of mess:

**One writer per file.** If two capabilities can write the same file, they will
eventually write it differently, and the second one to run wins. Name the owner
of every generated file.

**State the format, not the intent.** "Write a friendly summary" produces a
different structure every run. "Write `## Device` followed by one line of
key-value pairs, then the habit tags" produces something a later job can find and
a marker check can assert on.

## What this looks like when it is working

The signal is not that the agent behaves well on a good day. It is that its
behaviour is *predictable on a bad day* — when the input is malformed, the API is
down, or the request is ambiguous. Governance is the specification of what happens
then.

Three concrete symptoms of governance that is too vague, all of them common:

| Symptom | Missing rule |
|---|---|
| Notes appear in plausible-but-wrong folders | Classification has no documented fallback |
| The same information is formatted three ways | No single owner for the file, or no stated format |
| A capability quietly stopped running weeks ago | No routine inventory, so nothing knew it should be running |

The third is the one to internalise. Governance is not only about what the system
may do; it is about what it is *supposed* to be doing, which is the only way to
notice when it stopped. That inventory is what chapter 21's health checks assert
against.

## Version it, and read the diffs

These files are the system's source code, so treat them that way. Commit every
change with a reason. When behaviour shifts and nobody knows why, the diff of the
governance files is the first place to look — and in a system where an agent
proposes edits, it is the place a change can arrive without anyone deciding to
make it.

---

**Read next:** [04 — An Honest Comparison](./04_an-honest-comparison.md), on
where this system beats a hosted product and where it plainly does not.
