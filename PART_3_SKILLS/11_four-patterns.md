# 11 — Four Patterns

Almost every skill worth building is one of four shapes. Learn these and the fifth
one you need is an afternoon rather than a research project.

> Four patterns cover the work. What varies between skills is the judgement inside them, not the machinery around them.

| Pattern | Shape | Runs |
|---|---|---|
| Classification and routing | Agent decides, script writes | On demand or nightly |
| Batch pipeline | Select unprocessed, transform, mark done | On a schedule |
| External sync | Fetch since last, write, derive the cursor | On a schedule |
| Test-driven importer | Parse a foreign export, merge without destroying | On demand |

---

## 1. Classification and routing

The agent reads prose and decides where it belongs. A script performs the write.
Chapter 09 explained the split; this is what it looks like.

The contract carries the matrix, because the matrix *is* the judgement and it needs
to be reviewable:

```markdown
## Classification matrix

| Content | Type | Destination | Filename |
|---|---|---|---|
| Meeting notes with a work context | meeting | `20_Areas/<Area>/Meetings/` | `YYYY-MM-DD <title>.md` |
| Personal conversation | transcript | `30_Life/Transcripts/` | `YYYY-MM-DD <title>.md` |
| An external article | reading | `11_Readings/Articles/` | `YYYY-MM-DD-<kebab-title>.md` |
| An idea or sketch | idea | `<Area>/Notes/` | `YYYY-MM-DD-<kebab-title>.md` |
| Nothing recognisable | clarify | stays in place | unchanged |
```

The last row is the pattern's whole safety property. Everything the agent cannot
place confidently stays where it is and gets tagged, and that path must be as
well-specified as the others.

The script does the writing:

```python
from pathlib import Path
import shutil


def file_item(source: Path, dest_dir: Path, name: str) -> Path:
    """Move source to dest_dir/name. Never overwrite; never copy-then-delete."""
    dest_dir.mkdir(parents=True, exist_ok=True)
    target = dest_dir / name

    if target.exists():
        stem, suffix = target.stem, target.suffix
        n = 2
        while (dest_dir / f"{stem}-{n}{suffix}").exists():
            n += 1
        target = dest_dir / f"{stem}-{n}{suffix}"

    shutil.move(str(source), str(target))     # atomic within a filesystem
    return target
```

Three properties, all load-bearing: **never overwrite** (a collision is a
suffix, not a loss), **move rather than copy-then-delete** (chapter 22), and
**return the final path** so the caller can write the cross-link to where the file
actually landed rather than where it intended to put it.

### Where it goes wrong

| Failure | Guard |
|---|---|
| Confident misclassification | An explicit low-confidence path that leaves the file alone |
| Filed correctly, never linked | The link is part of the same operation, not a later step |
| Same item processed twice | The item is gone from the inbox after a successful move — the absence is the state |

## 2. Batch pipeline

Take a set of unprocessed inputs, transform each, mark it done. The shape of every
distillation, summarisation and enrichment job.

```python
BATCH = int(os.environ.get("BATCH", 20))


def unprocessed(vault: Path, marker: str = "distilled:") -> list[Path]:
    """Inputs that have not been through this stage yet."""
    out = []
    for path in (vault / "11_Readings").rglob("*.md"):
        text = path.read_text(encoding="utf-8")
        if marker not in text:
            out.append(path)
    return sorted(out)[:BATCH]


def run(vault: Path) -> None:
    items = unprocessed(vault)
    print(f"{len(items)} to process")
    for path in items:
        try:
            result = transform(path)          # the model call
            write_output(vault, result)
            mark_done(path, f"distilled: {date.today()}")
        except Exception as exc:
            # One bad input must not stop the batch. It stays unmarked and is
            # retried on the next run; a persistent failure shows up as an item
            # that never clears.
            print(f"skip {path.name}: {exc}")
```

Four decisions worth copying:

**The bound is a batch size, not a time limit.** A model-calling job's cost scales
with items, and an unbounded first run against a full vault is how you discover
your rate limit and your budget in the same minute. `BATCH=100` for a deliberate
catch-up.

**The marker lives in the input.** Not a separate ledger — the input's own state
answers "was this done", which is chapter 22's rule about deriving the cursor from
the work.

**A failure skips, it does not abort.** One malformed note must not block the other
nineteen.

**Progress is printed.** A scheduled job that prints nothing gives you nothing to
read when it turns out to have been doing nothing. Chapter 20's first failure was
exactly this.

### Ordering

`sorted()` matters. Processing in a stable order means a job interrupted at item
twelve resumes predictably, and it makes the batch reproducible when you are
debugging why one item behaves oddly.

## 3. External sync

Fetch what has changed since last time, write it, and keep no separate record of
where you are. Chapter 15 develops this fully against a device API; the general
form:

```python
def sync(vault: Path, client) -> None:
    log = vault / "memory" / "records.jsonl"

    for day in days_to_fetch(log):
        record = fetch(client, day)
        if record is None:
            continue                    # no data: skip, retry next run, never zero
        append_line(log, record)
```

The three properties that make an unattended sync trustworthy:

| Property | Mechanism |
|---|---|
| Knows where it stopped | The last line of its own output |
| Safe to run twice | Append-only, plus a de-duplicating reader |
| Distinguishes "no data" from "zero" | Skip the day rather than writing a record |

The third is the one that silently ruins datasets. A missing day and a day of
genuine inactivity are different facts, and once they are the same row you cannot
recover the difference.

### Backoff

An API that rate-limits will do so at the least convenient time. Retry with
increasing delay, and give up rather than hammering:

```python
import time


def with_retry(fn, attempts: int = 4, base: float = 2.0):
    for attempt in range(attempts):
        try:
            return fn()
        except TransientError:
            if attempt == attempts - 1:
                raise
            time.sleep(base ** attempt)     # 1s, 2s, 4s, 8s
```

Note that it re-raises on the last attempt. A sync that swallows a persistent
failure and exits zero is the silent sensor outage from chapter 20 — the freshness
check will catch it eventually, but the job should have said so itself.

## 4. Test-driven importer

Parse a foreign export — a CSV from a service, a platform's data dump — and merge
it into notes that already contain writing you must not destroy. The only pattern
here that genuinely needs tests, because the input format is not yours and will
change without notice.

### Guarded blocks

The mechanism that makes re-import safe. The importer owns a delimited region; the
prose outside it belongs to whoever wrote it.

```markdown
---
title: "Jane Doe"
type: person
---

# Jane Doe

<!-- begin:import -->
| Field | Value |
|---|---|
| Company | Acme |
| Role | Head of Platform |
| Updated | 2026-03-15 |
<!-- end:import -->

Met at the platform meetup. Thinks the migration is under-scoped, and said so
before anyone else did.
```

Re-running the importer refreshes the table and leaves the paragraph untouched. The
markers name their owner — `begin:import`, not `begin:generated` — so a second
writer cannot claim the same region.

### Fixtures from the real export

```
skills/importer/test/fixtures/
  contacts.csv          a real export, anonymised, including its oddities
  contacts-empty.csv    header only
  contacts-broken.csv   the malformed row that appeared once
```

Anonymise the values, keep the *shape*: the BOM, the quoted commas, the blank
trailing line, the column that is sometimes a date and sometimes empty. Those are
the reason the importer needs tests, and a fixture you cleaned up tests nothing.

```python
def test_quoted_comma_in_company_name():
    rows = parse(FIXTURES / "contacts.csv")
    assert rows[3].company == "Acme, Inc."


def test_broken_row_is_skipped_not_fatal():
    rows = parse(FIXTURES / "contacts-broken.csv")
    assert len(rows) == 4                  # the malformed one is dropped


def test_reimport_preserves_prose(tmp_path):
    note = tmp_path / "Doe_Jane.md"
    note.write_text(WITH_PROSE, encoding="utf-8")

    write_import_block(note, {"Company": "Acme"})
    write_import_block(note, {"Company": "Acme Holdings"})

    text = note.read_text(encoding="utf-8")
    assert "Met at the platform meetup" in text     # prose survived
    assert text.count("begin:import") == 1          # no duplicate block
    assert "Acme Holdings" in text                  # refreshed
```

The third test is the important one, and it is the one people leave out. It asserts
the property the whole pattern exists for.

---

## Choosing between them

| If the work | Use |
|---|---|
| Reads prose and decides where it belongs | Classification and routing |
| Transforms many items on a schedule | Batch pipeline |
| Talks to a system you do not control | External sync |
| Merges a foreign format into existing notes | Test-driven importer |

And if it is two of these, it is two skills. A sync that also distils is a sync
feeding a pipeline — separate stages, separate contracts, separate failure modes.
Chapter 13 covers how they connect.

---

**Read next:** [12 — Skill Inventory](./12_skill-inventory.md), a menu of what a
mature system ends up running.
