# 21 — The Watchdog

One process, on a timer, that reads the vault and asserts that it looks the way a
working system would leave it. It knows nothing about the jobs, their exit codes,
or their logs. It looks at outcomes.

> A check that asks whether the job ran can only detect a crash. A check that asks whether the work exists detects everything else.

---

## Four families of check

Roughly a dozen checks cover a system of this size. Every one belongs to one of
four families, and knowing the family tells you what a new check should look like.

| Family | Question | Example |
|---|---|---|
| **Freshness** | Did a file that should have changed recently change? | The measurement log is newer than 26 hours |
| **Integrity** | Does everything that should parse, parse? | Every note's frontmatter is valid YAML |
| **Completeness** | Does every unit of work carry its completion marker? | Every finished day has a generated journal section |
| **Capacity** | Is there room and is the runtime alive? | Disk above a floor; the container is running |

Freshness catches the silent outage. Integrity catches the silent corruption.
Completeness catches the silent skip. Capacity catches the boring failures that
cause all three.

## The shape of a check

Every check is a function returning a name, a boolean, and a human sentence. No
check knows about alerting, state, or the other checks.

```python
from dataclasses import dataclass
from pathlib import Path
import os, time, yaml


@dataclass
class Result:
    name: str
    ok: bool
    detail: str


def env_hours(key: str, default: float) -> float:
    """Thresholds are environment variables so tuning needs no deploy."""
    return float(os.environ.get(key, default))


def check_log_freshness(vault: Path) -> Result:
    path = vault / "memory" / "measurements.jsonl"
    limit = env_hours("MEASUREMENTS_MAX_H", 26)
    if not path.exists():
        return Result("measurements", False, "log missing entirely")
    age = (time.time() - path.stat().st_mtime) / 3600
    return Result(
        "measurements",
        age <= limit,
        f"last written {age:.1f} h ago (limit {limit:.0f} h)",
    )
```

The 26-hour default is deliberate: a daily job needs more than 24 hours of slack
or a slightly late run pages you every morning. **A threshold that fires on normal
variance trains you to ignore the channel**, which is the same failure as having
no check at all — the lesson chapter 20's checker learned the hard way.

### Integrity

```python
def check_frontmatter(vault: Path) -> Result:
    bad = []
    for path in vault.rglob("*.md"):
        if any(part.startswith(".") or part == "90_Archive" for part in path.parts):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if not text.startswith("---"):
            continue                      # notes without frontmatter are allowed
        _, _, rest = text.partition("---")
        block, sep, _ = rest.partition("\n---")
        if not sep:
            bad.append(f"{path.name}: unterminated frontmatter")
            continue
        try:
            yaml.safe_load(block)
        except yaml.YAMLError as exc:
            bad.append(f"{path.name}: {str(exc).splitlines()[0]}")
    return Result(
        "frontmatter",
        not bad,
        "all notes parse" if not bad else f"{len(bad)} invalid: " + "; ".join(bad[:3]),
    )
```

Two decisions worth copying. The archive is skipped, because old notes in a
retired format are not a live problem and a check that reports permanent failures
is noise. And the detail string truncates to three examples — an alert listing
forty filenames does not get read.

### Completeness

```python
from datetime import date, timedelta


def check_journal_markers(vault: Path) -> Result:
    days = int(env_hours("JOURNAL_MAX_D", 7))
    since = date.fromisoformat(os.environ.get("JOURNAL_SINCE", "2026-01-01"))
    missing = []
    # Today is excluded: the job that writes the marker runs in the evening.
    for offset in range(1, days + 1):
        day = date.today() - timedelta(days=offset)
        if day < since:
            continue
        path = vault / "10_Journal" / f"{day:%Y}" / f"{day:%m}" / f"{day}.md"
        if not path.exists() or "<!-- generated:" not in path.read_text(encoding="utf-8"):
            missing.append(str(day))
    return Result(
        "journal",
        not missing,
        "every day complete" if not missing else "no marker: " + ", ".join(missing),
    )
```

`JOURNAL_SINCE` exists because history predates the marker. Without a floor, a new
completeness check opens by reporting every day since the beginning — and an alert
that arrives already failing gets muted before it ever says anything true.

That generalises into a rule: **a new check baselines what already exists and
alarms only on what happens after it.** The same applies to accumulating
artifacts — count the conflict files present on first run, store the count, and
alarm on increases.

## Alert cadence

Getting this wrong is how a watchdog becomes wallpaper. Three states, three
behaviours:

| Transition | Message |
|---|---|
| ok → failing | One alert, immediately |
| failing → failing | One reminder per interval, default daily |
| failing → ok | One recovery message, explicitly |

The recovery message is the part people leave out, and it is the one that makes
the channel trustworthy. Without it you never learn whether something resolved or
you simply stopped looking.

```python
import json


def notify(state_path: Path, results: list[Result], send, remind_seconds: int = 86400):
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    now = time.time()

    for r in results:
        prev = state.get(r.name, {})
        was_failing = prev.get("failing", False)

        if not r.ok and not was_failing:
            send(f"FAILING — {r.name}: {r.detail}")
            state[r.name] = {"failing": True, "last_sent": now}
        elif not r.ok and now - prev.get("last_sent", 0) >= remind_seconds:
            send(f"STILL FAILING — {r.name}: {r.detail}")
            state[r.name] = {"failing": True, "last_sent": now}
        elif r.ok and was_failing:
            send(f"RECOVERED — {r.name}: {r.detail}")
            state[r.name] = {"failing": False, "last_sent": now}
        elif not r.ok:
            state[r.name] = {"failing": True, "last_sent": prev.get("last_sent", now)}

    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
```

**The state file lives outside the vault.** `/var/lib/vault-watchdog/state.json`,
not `memory/`. If it were in the vault, restoring a backup would resurrect stale
alert state, and the watchdog would announce failures that were fixed weeks ago —
undermining exactly the channel it exists to keep credible.

## Write the summary into the vault too

Alerts are ephemeral. A short generated file lets the agent answer "is anything
broken" from its own context, and gives you a place to look that is not a chat
history.

```python
def write_summary(vault: Path, results: list[Result]) -> None:
    lines = [
        "---",
        "title: \"System health\"",
        f"updated: {time.strftime('%Y-%m-%dT%H:%M:%S')}",
        "type: reference",
        "---",
        "",
        "# System health",
        "",
        "| Check | Status | Detail |",
        "|---|---|---|",
    ]
    for r in results:
        lines.append(f"| {r.name} | {'ok' if r.ok else 'FAILING'} | {r.detail} |")
    (vault / "memory" / "system_health.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
```

Note the `updated` field. A health summary without a timestamp is the exact
failure mode from chapter 02 — a file that can reassure you indefinitely after the
process writing it has died. The watchdog's own freshness is the one thing the
watchdog cannot check, so it must at least be visible.

## Running it

A timer every fifteen minutes, running as a user that can read the whole vault:

```ini
# /etc/systemd/system/vault-watchdog.timer
[Unit]
Description=Vault health checks

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
```

Fifteen minutes is not about detection speed — most of these failures have a
tolerance measured in hours. It is that a frequent, cheap run means a check that
starts failing produces its first alert while you are still near the change that
caused it.

Credentials for the alert channel go in a root-owned mode-`0600` environment file
outside the vault, never in the repository and never in a note. Chapter 26 covers
the general rule.

## How a check set of thirteen actually happens

Not by design. Every check after the first four was added in response to something
that had already gone wrong, and that is the correct order.

The pattern, each time:

1. Notice a problem by eye, usually days late.
2. Ask what assertion about the vault would have caught it.
3. Write that assertion, baseline any pre-existing violations, deploy.
4. Add a line to a runbook saying what to do when it fires.

Two of the checks in this system exist because a day slipped through with no
journal entry and, separately, because dozens of notes had invalid frontmatter —
both discovered by accident, weeks after the fact. Neither would have been
predicted in advance.

So resist designing the full set up front. Start with the four that catch the
classes from chapter 20 — one freshness, one integrity, one completeness, one
capacity — and let incidents write the rest. A watchdog grown from real failures
covers your actual risks; one designed from imagination covers the failures you
found easy to imagine.

### What not to check

| Do not check | Because |
|---|---|
| Job exit codes | Chapter 20 exists because they are green during every failure that matters |
| Whether a process is running | An idle process passes. Check its output instead |
| Anything with no defined response | A check whose alert has no action is training to ignore alerts |
| More than one thing per check | A failing composite tells you nothing about which half broke |

The third row is the discipline that keeps the set small. Before adding a check,
write the runbook entry for it. If the entry is hard to write, the check is not
ready.

---

**Read next:** [22 — Idempotency and State](./22_idempotency-and-state.md), on
making the writes themselves safe to repeat.
