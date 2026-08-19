# 25 — Cost and Model Routing

The money does not go where people expect. Interactive sessions feel expensive
because you watch them happen. The bill is dominated by the jobs running at three in
the morning that nobody watches at all.

> Interactive work is bounded by your attention. Unattended work is bounded by whatever limit you remembered to set.

---

## Where it goes

| Category | Share of spend | Why |
|---|---|---|
| Unattended batch pipelines | Most of it | Runs nightly, processes every unprocessed item, no human pacing it |
| Scheduled routines | Some | Small, but daily and forever |
| Interactive sessions | Less than it feels | You are the rate limit |
| Syncs and checks | Effectively nothing | Deterministic code, no model calls |

The last row is the useful one: **the most reliable way to reduce cost is to move
work out of the model entirely.** A sync that parses an API response needs no model.
A freshness check needs no model. Chapter 09's code-versus-specification decision is
also a cost decision, and it is the one with the best return.

## The infrastructure is the cheap part

| Item | Monthly |
|---|---|
| A small VPS, 2 vCPU and 4 GB | Around 5 € |
| Backup storage | Under 1 € |
| Domain, if you use one | Under 1 € |
| Model usage | The rest, and the variable |

Around fifteen euros a month, most of it model usage, roughly flat as the vault
grows. The flatness matters: cost scales with *new items per day*, not with total
notes, because every pipeline processes a delta.

That is the structural advantage over per-seat subscriptions, and the honest
caveat is that it is only true if your batch jobs are bounded. An unbounded first
run against a full vault will produce a memorable invoice.

## Route by job, not by preference

Pick the cheapest model that can do the job, per job. The temptation is to default
everything to the best available model because it is easier to reason about; that
choice is usually paid for by the nightly pipeline.

| Work | Tier | Why |
|---|---|---|
| Classification, routing, tagging | Cheap | A closed set of outputs and a documented fallback |
| Extraction and summarisation | Cheap to mid | Structured output from a source, low ambiguity |
| Distillation into a concept note | Mid | Needs to hold a whole document and produce something new |
| Synthesis across many notes | Best available | Wide context, real judgement, run rarely |
| Anything with a defined answer | No model | Arithmetic, formatting, moving files, parsing |

The last row is the discipline that matters. "Format this table" and "compute this
average" are not model tasks, and a routine that asks a model to do arithmetic is
both more expensive and less correct than four lines of code.

### Bound the batches

```python
BATCH = int(os.environ.get("BATCH", 20))
```

One environment variable, and it is the difference between a predictable bill and a
surprise. Twenty items a night keeps a pipeline current with normal intake. Setting
`BATCH=200` for a deliberate catch-up is a decision you make once, watching, rather
than a default that fires unattended.

Two more guards worth having from the start:

**A per-run ceiling.** If a job would process more than N items, process N and log
that it stopped early. A silent cap is worse than no cap — chapter 20's whole
subject — so the log line is not optional.

**A cost log.** One line per run: date, items, tokens if the API reports them. It
turns "the bill went up" into "this job changed on the eleventh".

## Measure yours, do not trust these numbers

The figures above describe one installation with one pattern of use. Yours will
differ by more than a factor of two, in either direction, depending on how many
pipelines you run and how much you talk to it.

So instrument it rather than estimating:

```python
def log_run(log_path: Path, job: str, items: int, tokens: int | None) -> None:
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps({
            "date": date.today().isoformat(),
            "job": job,
            "items": items,
            "tokens": tokens,
        }) + "\n")
```

Append-only, one line per run, in the same JSONL shape as everything else — which
means chapter 18's dashboard techniques work on it unchanged. A cost chart is a
twenty-line query block, and it is the one that will tell you which job to look at.

## The cheapest optimisations

In order of return, and the first three cost nothing:

| Change | Effect |
|---|---|
| Move deterministic work out of the model | Removes the cost entirely |
| Bound every batch | Makes the ceiling knowable |
| Shrink the governance files | Reduces the fixed cost of every single run |
| Route classification to a cheap tier | Large, because classification is high-volume |
| Cache what does not change | A concept note re-distilled from unchanged sources is pure waste |

The third row is chapter 24's context budget seen from the invoice: those files are
read on every run, so a hundred lines removed is a hundred lines removed from every
operation for as long as the system exists.

## What is worth paying for

Cost discipline is not the goal, and there are places to spend deliberately:

- **Synthesis that changes a decision.** A monthly review that makes you drop a
  project has paid for a year of pipeline.
- **The check that catches a silent failure.** Cheap in tokens, and the alternative
  is weeks of missing data.
- **The best model for a hard one-off.** A restructure you will live with for years
  is not the place to save a few cents.

The pattern: spend on the rare and consequential, economise on the frequent and
mechanical. Which is the same instinct as chapter 09's split between judgement and
mechanism, applied to money.

---

**Read next:** [26 — Privacy in Practice](./26_privacy-in-practice.md), on what
leaves the machine and what never does.
