# 23 — Recovery Runbooks

An alert fires at an inconvenient moment, months after you wrote the thing that
broke. What you need then is not understanding — it is the next command.

> A runbook you cannot find during an incident is not a runbook. It lives next to the thing it recovers, in version control, or it does not exist.

---

## The format

Four fields, always in this order, no prose:

```markdown
### <what the alert says>

**Symptom** — what you observe.
**Diagnose** — one command.
**Fix** — the commands.
**Verify** — the command that proves it worked, and its expected output.
```

The constraints are what make it usable. **One diagnostic command**, because three
means choosing while stressed. **A verify step**, because "it seems fine now" is
how an incident gets closed twice. And **no explanation** — the reasoning belongs
in the chapter that designed the thing, and the runbook links to it.

Write the entry when you build the check, not when it first fires. Chapter 21 made
this a gate: if the runbook entry is hard to write, the check is not ready, because
an alert with no defined response trains you to ignore alerts.

---

## The runbook

### Sensor sync stale

**Symptom** — freshness alert on the measurement log; dashboards show gaps.

**Diagnose**
```bash
tail -5 memory/sync.log
```

**Fix** — three causes, in order of likelihood:

```bash
# 1. Expired OAuth token — re-authenticate interactively, once.
#    See chapter 15. The job never handles a password.
python -c "from garminconnect import Garmin; Garmin().login()"

# 2. The job is not scheduled where you think. Confirm the owner host.
systemctl list-timers | grep sync

# 3. Vendor API changed. Run one day manually and read the traceback.
python skills/sensor-sync/sync.py --from 2026-03-14 --to 2026-03-14 --dry-run
```

**Verify**
```bash
python skills/sensor-sync/sync.py && tail -1 memory/measurements.jsonl
```
Expected: the last line's `date` is yesterday.

---

### Invalid frontmatter

**Symptom** — integrity alert naming one or more notes.

**Diagnose**
```bash
python tools/check-frontmatter.py --list
```

**Fix** — the cause is almost always an unescaped colon or quote in a title.

```yaml
# Wrong
title: Planning: Q3

# Right
title: "Planning: Q3"
```

Fix the named files by hand. Do not let an agent bulk-fix frontmatter unattended;
the failure mode is a plausible-looking guess at what a corrupted field meant.

**Verify**
```bash
python tools/check-frontmatter.py
```
Expected: `all notes parse`.

---

### A day is missing its entry

**Symptom** — completeness alert naming one or more dates.

**Diagnose**
```bash
ls -la 10_Journal/2026/03/2026-03-14.md; grep -c "generated:" 10_Journal/2026/03/2026-03-14.md
```

**Fix**
```bash
# File exists but has no marker: the job ran and produced nothing. Re-run it
# for that date, then read the output before trusting it.
python skills/journal/weave.py --date 2026-03-14

# File does not exist: check whether the job is scheduled at all.
systemctl list-timers | grep journal
```

**Verify**
```bash
grep -q "generated:" 10_Journal/2026/03/2026-03-14.md && echo present
```

If the source data for that day is genuinely gone, write the entry by hand and
move on. A gap you know about is not a problem; a gap you do not is chapter 20.

---

### Sync-conflict files appearing

**Symptom** — a conflict alert; filenames containing `sync-conflict` or similar.

**Diagnose**
```bash
find . -name "*sync-conflict*" -newermt "-7 days"
```

**Fix**
```bash
# Compare each against its original, keep what belongs, delete the conflict copy.
diff "10_Journal/2026-03-14.md" "10_Journal/2026-03-14.sync-conflict-20260314.md"
```

Then find the cause, because conflicts are a symptom:

| Cause | Check |
|---|---|
| Two schedulers running one job | `systemctl list-timers` on every host that could |
| A disabled scheduler that is not actually disabled | Look for `.disabled` files that were merely renamed |
| Editing the same note on two devices while offline | No fix; it is the cost of continuous sync |

**Verify**
```bash
find . -name "*sync-conflict*" | wc -l
```
Expected: matches the baseline count the watchdog stored.

---

### Local git diverged from the remote

**Symptom** — a push-freshness alert; local ahead and behind.

**Diagnose**
```bash
git status -sb && git log --oneline --left-right --graph origin/main...HEAD
```

**Fix**
```bash
# Both sides are your own automated commits. Rebase, never merge — a merge commit
# in an auto-sync history makes it unreadable.
git pull --rebase origin main

# On conflict, prefer the version with more content and resolve by hand. These are
# notes, so both sides are usually additions rather than contradictions.
git status --short
```

**Verify**
```bash
git status -sb
```
Expected: `## main...origin/main` with no ahead or behind markers.

---

### The runtime container will not start

**Symptom** — capacity alert; the chat interface is unresponsive.

**Diagnose**
```bash
docker compose logs --tail 50
```

**Fix**
```bash
df -h /                                    # a full disk is the usual cause
docker system prune -f                     # reclaim, then retry
docker compose up -d
```

**Verify**
```bash
docker compose ps
```
Expected: the service is `Up` and healthy.

---

### A scheduled job errors every day

**Symptom** — no alert at all, usually. Found by reading logs.

**Diagnose**
```bash
grep -i error /var/log/*.log | tail -20
```

**Fix** — the common cause is a job with access to a tool it should not use for
that task, which then fails on every run. Narrow the job's tool scope rather than
handling the error. Chapter 03 covers where that scope is declared.

**Verify** — run the job once manually and read all of its output. Not the exit
code: the output.

---

## What belongs here and what does not

| In the runbook | Elsewhere |
|---|---|
| The command to run | Why the design is like that |
| The expected output | How the component works |
| Which host owns a job | The rationale for that host |
| A decision table when there are several causes | Anything that needs a paragraph |

The runbook is the only document in this guide written for someone who is annoyed
and in a hurry. Keep it that way.

## Practise one

A runbook that has never been executed is a hypothesis. Once, deliberately, break
something on purpose and recover from it using only the entry:

```bash
# Simulate a stale sync: move the log aside and let the watchdog notice.
mv memory/measurements.jsonl /tmp/measurements.bak
# ... wait for the alert, then recover using the runbook above ...
cp /tmp/measurements.bak memory/measurements.jsonl
```

Two things this reliably surfaces, both invisible on paper: a command that assumes
a working directory or a host you are not on, and a verify step that passes while
the underlying problem is still there.

Do it once per runbook, in the month you write it, and note the date at the top of
the file. An untested runbook and a tested one look identical until the day they
do not.

---

**Read next:** Part 6 opens with [24 — Scale](../PART_6_OPERATE/24_scale.md), on
what a vault of this size does to context, search and cost.
