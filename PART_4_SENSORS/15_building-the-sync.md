# 15 — Building the Sync

A sync job runs unattended, every day, against an API you do not control, and
writes into files you also edit by hand. It will be interrupted, it will be run
twice, it will meet days with no data, and its credentials will expire. All four
have to be non-events.

> A scheduled writer that cannot survive being run twice is not scheduled. It is a manual step with a timer attached.

The worked example is a health device sync — Garmin, because it is the case with
the most awkward real-world edges. Everything here transfers; the seam for
swapping the vendor is at the end.

---

## Authentication without a password in the script

The naive version puts a username and password in the script or in an
environment file and logs in on every run. Do not. A daily job holding
reusable account credentials in plaintext is the highest-value secret in this
whole system, and it buys nothing that a token does not.

Most device vendors issue OAuth tokens with a long life — often around a year.
The pattern that works:

1. Authenticate **once**, interactively, using a client that persists tokens to
   disk. Any maintained library for your vendor does this, as do the MCP servers
   that wrap these APIs.
2. Point the sync job at that token directory. It refreshes tokens itself and
   never sees a password.
3. When the refresh token eventually expires, the job fails loudly. Re-do step 1.

```python
from pathlib import Path
from garminconnect import Garmin

TOKEN_DIR = Path.home() / ".garminconnect"


def connect():
    """Log in from persisted OAuth tokens. Never handles a password."""
    client = Garmin()
    client.login(str(TOKEN_DIR))     # raises if tokens are absent or expired
    return client
```

The failure mode to design for is not "the token expired" — that is a fifteen
minute annoyance once a year. It is **the token expired and nothing noticed**,
because the job caught the exception, logged it, and exited zero. Chapter 21's
freshness check on the log file is what makes that impossible; the sync's own
job is simply to fail rather than to paper over it.

## Catch-up: derive the cursor from the output

A daily job misses days. The machine was asleep, the container was restarting,
the network was out. So the job cannot ask "what is today"; it has to ask "which
days are still missing".

The tempting design is a state file recording the last successful date. Don't:
now two things claim to know where you are, and when they disagree — because a
write succeeded and the state update didn't — you get either duplicates or a
permanent gap.

**The output is the cursor.** The last line of the log is, by construction, the
last day that was successfully written:

```python
import json
from datetime import date, timedelta

EPOCH = date(2026, 1, 1)        # how far back a first run should reach


def last_written(log_path):
    """The most recent date present in the log, or None if it is empty."""
    if not log_path.exists():
        return None
    last = None
    with log_path.open(encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                last = json.loads(line)["date"]
    return date.fromisoformat(last) if last else None


def days_to_fetch(log_path, until=None):
    """Every date from the day after the last written one through yesterday."""
    until = until or date.today() - timedelta(days=1)
    start = (last_written(log_path) or EPOCH - timedelta(days=1)) + timedelta(days=1)
    out, d = [], start
    while d <= until:
        out.append(d)
        d += timedelta(days=1)
    return out
```

Three properties fall out of this for free:

- **No state to corrupt.** There is one source of truth about progress.
- **Interruption is safe.** Whatever was written is the new cursor.
- **Backfill is the same code path.** A first run against an empty log fetches
  the whole history. There is no separate import script to maintain, and
  therefore no second code path that can drift.

Note the deliberate `until = yesterday`. Today is still in progress; a device
that syncs at midday would write a half-day as if it were a full one, and the
next run would see the date already present and never correct it.

## Days with no data: skip, never write zeroes

A watch on the charger produces no data. Writing a row of zeroes for that day is
the single most damaging thing this job can do, because zeroes are
indistinguishable from a real day of complete inactivity — and they average into
every chart forever.

```python
def fetch_day(client, d):
    """One day's measurements, or None if the vendor has nothing for that date."""
    iso = d.isoformat()
    stats = client.get_stats(iso) or {}

    # The presence check must be a field the vendor only sets when the device
    # actually reported. A zero here means "no data", not "no steps".
    if stats.get("totalSteps") is None:
        return None

    sleep = client.get_sleep_data(iso) or {}
    dto = sleep.get("dailySleepDTO") or {}
    seconds = dto.get("sleepTimeSeconds")
    scores = (dto.get("sleepScores") or {}).get("overall") or {}

    return {
        "date": iso,
        "source": "device",
        "steps": stats.get("totalSteps"),
        "sleep_hours": round(seconds / 3600, 2) if seconds else None,
        "sleep_score": scores.get("value"),
        "hrv_ms": round(sleep["avgOvernightHrv"]) if sleep.get("avgOvernightHrv") else None,
        "resting_hr": stats.get("restingHeartRate"),
        "activities": [
            {
                "type": (a.get("activityType") or {}).get("typeKey", "unknown"),
                "duration_min": round((a.get("duration") or 0) / 60),
                "distance_km": round(a["distance"] / 1000, 2) if a.get("distance") else None,
                "avg_hr": round(a["averageHR"]) if a.get("averageHR") else None,
            }
            for a in client.get_activities_by_date(iso, iso) or []
        ],
    }
```

Skipped days are simply not appended. Because the cursor is the last written
date, a skipped day in the middle is re-attempted on every subsequent run until
it either yields data or the range moves past it — which is exactly right for a
device that uploads late. `None` for individual fields is normal and every
consumer has to tolerate it; chapter 17 covers that on the query side.

## Idempotency: a marker, not a flag

The job also writes a section into each day's note. That write is not
append-only — it goes into a file you edit — so it needs a different guarantee:
running twice must produce the same file as running once.

The mechanism is a marker section. The job looks for its own heading; if it is
there, the day is done.

```python
MARKER = "## Device"


def write_day_note(vault, record, section_text):
    """Insert the generated section once. A second run is a no-op."""
    path = vault / "10_Journal" / record["date"][:4] / record["date"][5:7] / f"{record['date']}.md"
    path.parent.mkdir(parents=True, exist_ok=True)

    if not path.exists():
        path.write_text(day_template(record["date"], section_text), encoding="utf-8")
        return "created"

    body = path.read_text(encoding="utf-8")
    if MARKER in body:
        return "skipped"                     # already present, leave it alone

    anchor = "## Recap"                      # insert above a known later heading
    if anchor in body:
        body = body.replace(anchor, f"{section_text}\n{anchor}", 1)
    else:
        body = body.rstrip() + "\n\n" + section_text + "\n"
    path.write_text(body, encoding="utf-8")
    return "inserted"
```

Two details that matter more than they look:

**Insert above a known anchor, not at the end.** Appending puts machine output
below whatever you wrote that evening, which reads backwards and, worse, means
the position of the section depends on when the job ran relative to your typing.

**Create from a template when the note is missing.** The sync must not be the
only reason a day's note exists in a half-formed state. If it creates the file,
it creates the full skeleton so that the note is normal in every other respect.

For the harder case — a section that must be *updated* on every run rather than
written once — use a guarded block with explicit begin and end markers and
replace only between them. That is the pattern that lets a script rewrite its own
output on every run without destroying prose a human or an agent wrote in the
same file. Chapter 11 covers it in full.

## Partial data: the second log

Some vendor-computed values exist only for "now". Ask for last Tuesday's
readiness score and the API hands back today's, with no indication that it did.
Written into a backfill, that produces a flat line where a trend should be — and
a flat line looks like a finding, not a bug.

So those fields go in a separate log with their own rule: **written only for the
most recent day, never backfilled.**

```python
def sync_derived(client, log_path, today):
    """Vendor-computed scores with no retrievable history. Today only, once."""
    if last_written(log_path) == today:
        return "skipped"
    record = {
        "date": today.isoformat(),
        "fitness_estimate": client.get_max_metrics(today.isoformat()),
        "readiness": client.get_training_readiness(today.isoformat()),
    }
    append_line(log_path, record)
    return "written"
```

Two files, two catch-up strategies, roughly thirty extra lines. It prevents a
whole class of confidently wrong charts.

## Writing the log

The only write is an append, and it is worth being pedantic about it:

```python
def append_line(log_path, record):
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
```

`sort_keys=True` so that a diff of the log shows changed *values* rather than
reshuffled keys. `ensure_ascii=False` so that text stays readable. Open in
append mode per record rather than holding the handle across the whole run, so
an interruption cannot lose buffered lines.

Readers must still de-duplicate by date, because a re-run after a manual edit
can produce two lines for one day. One line of defensive reading on the query
side is cheaper than any locking scheme:

```javascript
const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
```

Last line for a date wins. That is the right precedence: a later append is a
correction.

## The dry run is not optional

An unattended writer needs a mode that shows what it would do and touches
nothing:

```
sync.py --dry-run                       # print planned writes, change nothing
sync.py --from 2026-03-01 --to 2026-03-15   # bounded re-fetch
sync.py --vault /tmp/scratch-vault      # run against a copy
```

`--vault` matters most. It lets you test the whole job against a copied tree
before pointing it at the real one, which is the difference between a bug and
an incident.

## Exactly one scheduler

The sync will end up runnable from two places — a laptop and a server — and
running both against one vault produces duplicate sections and file-sync
conflicts. Choose one, and **disable** the other rather than merely not using
it. A scheduler you have stopped invoking is still a scheduler; a scheduler
whose definition you have removed is not.

Write down which host owns the job, next to the job. Chapter 23's runbook format
exists for exactly this kind of fact.

## The seam for other devices

Everything above is vendor-specific in exactly one place: `fetch_day`. Its
contract is the seam.

| | |
|---|---|
| Input | a `date` |
| Output | one dict with the fields the log defines, or `None` if the vendor has no data for that date |
| Must not | write anything, retry indefinitely, or invent values |

Swapping Garmin for Oura, Whoop, or Fitbit means writing one function against
that contract. The catch-up logic, the marker insertion, the logs, the dashboards
and the health checks are untouched.

Be honest with yourself about the cost, though: this is the one component in the
whole guide with a third-party dependency that can break without warning. A
vendor can rename a field, tighten a rate limit, or retire an endpoint, and your
first signal will be a gap in a chart. That is not an argument against building
it. It is an argument for the freshness check in chapter 21, and it is why
chapter 27 lists this as a standing maintenance cost rather than a solved
problem.

---

**Read next:** [16 — Tags as the Interface](./16_tags-as-the-interface.md), on
the vocabulary that lets a script, an agent, and a human write to the same
dashboard.
