# 22 — Idempotency and State

Chapter 01 gave up transactions in exchange for a format that outlives its tools.
This is the bill. Without rollback, the only way a scheduled writer stays safe is
for every operation to be individually repeatable — because it will be repeated,
after an interruption, a manual re-run, or a backfill.

> There is no rollback. So there is no such thing as a write that only needs to work once.

---

## Five mechanisms

Each solves one shape of repeated write, and each prevents a specific corruption.

| Mechanism | Use when | Prevents |
|---|---|---|
| Append-only log | A machine writes one record per period | Rewrites destroying history |
| Derive the cursor from the output | A job needs to know where it stopped | A state file disagreeing with reality |
| Marker section | A section is written once into a file humans edit | Duplicate blocks on re-run |
| Guarded block | A section must be *rewritten* on every run | Regeneration destroying adjacent prose |
| Move, never copy-then-delete | Filing something to a new location | A crash between the two steps losing the file |

## 1. Append-only, with a de-duplicating reader

Appending is atomic enough for this purpose and needs no locking. What it does not
prevent is two records for one date, after a re-run.

The resolution belongs in the reader, and it is three lines:

```javascript
const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
```

Last line for a date wins. That precedence is a design decision, not a
convenience: a later append is a correction, so the newest record is the one that
should survive. Writing it the other way round would make corrections impossible.

The alternative — having the writer read the whole log, remove the old line, and
rewrite the file — turns an atomic append into a read-modify-write that can be
interrupted halfway, which is how you lose a year of measurements.

## 2. The output is the cursor

A job that records progress separately from its work has two claims about where it
is, and they will disagree — because a write succeeded and the progress update did
not, or vice versa.

```python
def last_written(log_path):
    """The latest date in the log. This is the only progress record."""
    if not log_path.exists():
        return None
    last = None
    with log_path.open(encoding="utf-8") as fh:
        for line in fh:
            if line.strip():
                last = json.loads(line)["date"]
    return date.fromisoformat(last) if last else None
```

Three properties, all free:

- Interruption is safe. Whatever was written *is* the new position.
- Backfill and daily catch-up are one code path, so there is no second path to
  drift.
- Nothing to corrupt, because nothing separate exists.

The general rule: **if the work itself records what was done, do not record it
twice.** A separate state file is only justified when the output genuinely cannot
answer the question — a sync against an API whose cursor is an opaque token, for
instance. Then the state file *is* the work product and gets the same care.

## 3. Marker sections — write once

For a section inserted into a file a human also edits, the guarantee needed is:
running twice produces the same file as running once.

```python
MARKER = "## Device"

def insert_once(path, section):
    body = path.read_text(encoding="utf-8")
    if MARKER in body:
        return "skipped"
    anchor = "## Recap"
    if anchor in body:
        body = body.replace(anchor, f"{section}\n{anchor}", 1)
    else:
        body = body.rstrip() + "\n\n" + section + "\n"
    path.write_text(body, encoding="utf-8")
    return "inserted"
```

The marker has to be something a human would not type by accident and would not
delete while tidying. A heading works because it is meaningful to both readers. A
comment works when the section should be invisible.

What does **not** work is checking for the *content* rather than a marker. Content
changes — a different step count, a different summary — so a content check fails to
recognise its own previous output and inserts a second copy.

## 4. Guarded blocks — rewrite safely

Some sections must be updated on every run: an index, a computed summary, an
imported profile. The problem is that the same file also holds prose written by a
human or an agent, and a naive rewrite takes it with it.

Delimit the generated region explicitly and replace only between the markers:

```python
import re

BEGIN = "<!-- begin:generated -->"
END = "<!-- end:generated -->"

def replace_guarded(path, new_body):
    """Rewrite only between the markers. Everything else is untouched."""
    text = path.read_text(encoding="utf-8")
    block = f"{BEGIN}\n{new_body}\n{END}"
    pattern = re.compile(re.escape(BEGIN) + r".*?" + re.escape(END), re.DOTALL)
    if pattern.search(text):
        text = pattern.sub(block, text, count=1)
    else:
        text = text.rstrip() + "\n\n" + block + "\n"
    path.write_text(text, encoding="utf-8")
```

This is the mechanism that makes repeated imports safe, and it has one property
worth stating plainly: **a file can have several guarded blocks with different
owners.** An importer owns one, an agent's written summary sits outside it, and
neither destroys the other. A person's note can carry machine-imported contact
fields that refresh on every import, alongside a paragraph of context nobody
regenerates.

Two rules keep it honest. The markers name their owner — `<!-- begin:contacts -->`
rather than `<!-- begin:generated -->` — so a second writer cannot claim the same
region. And the region is documented as generated, so chapter 03's rule about never
hand-editing generated output has something to point at.

## 5. Move, never copy-then-delete

Filing an inbox item to its destination is one operation, and `mv` is that
operation.

```bash
mv "00_Start/Inbox/note.md" "20_Areas/Acme/Meetings/2026-03-15-note.md"
```

Copy-then-delete is two, and a crash between them either loses the file or leaves
two copies that will diverge. On the same filesystem, a rename is atomic; nothing
else in this list is as cheap a guarantee.

Beyond atomicity, `mv` preserves a fact that matters more than it sounds: the file
keeps its identity, so a link to it can be repaired rather than guessed at. A
copy-delete pair leaves no trace connecting the two paths.

## Testing repeatability

Idempotency is one of the few properties that is trivially testable, so there is no
excuse for asserting it in prose:

```python
def test_second_run_changes_nothing(tmp_path):
    vault = make_scratch_vault(tmp_path)

    run_sync(vault)
    first = snapshot(vault)          # {relative path: sha256}

    run_sync(vault)
    assert snapshot(vault) == first
```

Run the job twice against a scratch vault, hash every file, compare. Anything that
differs is a repeatability bug — and this test catches the whole class rather than
the instance you thought of.

Three variants worth having:

| Test | Catches |
|---|---|
| Run twice, compare | Duplicate insertion, double-counting |
| Run, hand-edit the prose, run again | Regeneration eating adjacent content |
| Interrupt mid-run, run again | Partial writes that block a later retry |

The second one is the test people skip, and it is the one that catches the most
damaging failure — because a job that destroys your writing is much worse than one
that writes twice.

## The order to apply this

Not everything needs all five. The decision is short:

- Machine-written time series → append-only, plus a de-duplicating reader.
- Progress tracking → derive it from the output; no state file unless forced.
- A section written once → marker.
- A section rewritten every run → guarded block with a named owner.
- Filing → `mv`.

And one thing that needs none of it: reads. Dashboards, queries and checks are
safe to run at any time, in any order, as often as you like. That asymmetry is why
chapter 18's dashboards carry no state and why the watchdog can run every fifteen
minutes without a second thought.

---

**Read next:** [23 — Recovery Runbooks](./23_recovery-runbooks.md), for when
something has already gone wrong.
