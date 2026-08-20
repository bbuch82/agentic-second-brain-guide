# 07 — Stage 2: Close the Loop

The vault now exists in two places: on the server where the agent writes it, and on
your laptop where you read it. Two copies of a shared mutable store is the moment
this stops being a folder and starts being a distributed system.

> Continuous sync and version control solve different problems. Running one instead of the other is how people lose a week of notes.

---

## Two mechanisms, two jobs

| | Git | Continuous file sync |
|---|---|---|
| Answers | What changed, when, and can it be undone | Is this file the same everywhere |
| Latency | Minutes, on a schedule | Seconds |
| Conflict handling | Explicit, with history | A duplicate file with a marker |
| Good for | History, backup, recovery | Working across devices |
| Bad at | Being current on a phone | Telling you what changed last Tuesday |

Run both. They are not alternatives, and each covers the other's weakness. Git is
your recovery story; sync is your working experience.

## 1. Git: history and backup

On the server, commit and push on a short interval. Small frequent commits are more
useful than tidy ones here, because the value is in recovery granularity rather than
a readable log.

`/usr/local/bin/vault-git-sync.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

VAULT=/opt/vault
cd "$VAULT"

git add -A
if git diff --cached --quiet; then
  exit 0                                    # nothing changed; log nothing
fi

git commit -q -m "vault: auto-sync $(date '+%Y-%m-%d %H:%M')"
if git push -q origin main; then
  echo "$(date '+%F %T') ok pushed $(git rev-parse --short HEAD)"
else
  echo "$(date '+%F %T') PUSH FAILED" >&2
  exit 1
fi
```

```
*/5 * * * * /usr/local/bin/vault-git-sync.sh >> /var/log/vault-git-sync.log 2>&1
```

Three deliberate choices:

**Quiet runs log nothing.** A log with 288 "no changes" lines per day is a log nobody
reads, and chapter 21's freshness check gives you the liveness signal instead.

**A failed push exits non-zero and says so.** A push that fails silently leaves the
server as the only copy, which is exactly the state the backup existed to prevent.

**The remote is private.** The vault contains everything. If you want the provider not
to be able to read it, encrypt before pushing — chapter 26 covers the trade.

## 2. Continuous sync: working across devices

A file-level sync tool — Syncthing is the usual choice, being peer-to-peer with no
cloud in the middle — keeps the laptop, phone and server current within seconds.

Two configuration details matter more than the rest:

**Exclude what must not sync.** Git internals, OS clutter, and anything volatile:

```
# .stignore
.git
.DS_Store
.obsidian/workspace*
99_Assets/tmp
```

Syncing `.git` between machines is the one that causes real damage: two peers
overwriting each other's index and object store produces a repository that is
corrupt in a way neither machine can repair. Exclude it and let each copy keep its
own history.

**Decide the send-receive direction per device.** The server and laptop are
bidirectional. A phone is usually better as send-receive too, but if you only ever
read on it, receive-only removes a whole class of accident.

## 3. Obsidian

Point Obsidian at the local copy. It needs no configuration to be useful — the vault
is already Markdown — but three plugins earn their place:

| Plugin | For |
|---|---|
| Dataview, with JavaScript queries enabled | Every dashboard in chapter 18 |
| Charts | The chart blocks in chapter 18 |
| Tasks | Collecting `- [ ] … #todo` lines across the vault into one view |

The Tasks plugin deserves a note, because it demonstrates chapter 03's rule about
generated output. Tasks live in the file where they arose — in the meeting note, next
to the context that produced them — and the dashboard is a *query* that gathers them.
That dashboard must never be hand-edited: the next render discards the edit silently,
which is among the most confusing failures in the system because nothing errors.

## 4. The concurrency rules

Two writers now exist. Three rules, and the first one is the expensive lesson.

### Exactly one scheduler per job

The same sync can run on the laptop and on the server. Running both produces
duplicate journal sections and a steady trickle of conflict files.

**Disable the loser, do not merely stop using it.** A scheduler you have stopped
invoking is still a scheduler; it fires again after a reboot, or on the day you
restore a machine from backup. Remove the timer, or rename its definition so it
cannot load.

Write down which host owns each job, next to the job. Chapter 23's runbook format has
a row for it, and it is the fact you will want at the exact moment you have no
patience for archaeology.

### Conflict files are a symptom, not the problem

A sync conflict means two copies changed the same file before they met. Resolving the
file is five minutes; the interesting question is which two writers were involved.

```bash
find . -name "*sync-conflict*" -newermt "-7 days"
```

Baseline the ones that already exist and alarm only on new arrivals — chapter 21's
rule for any accumulating artifact. Without a baseline, the check opens with a wall
of old findings and gets muted.

### Let the machine write, then read

The habit that prevents most conflicts: do not edit a note that a scheduled job is
about to write. If the evening job assembles today's entry at 21:00, write your own
notes before or after, not during. This is not a technical control, and it works.

## 5. Mobile

Two ways in, and they are for different things:

| Route | Good for |
|---|---|
| The chat interface from chapter 06 | Capture. One-handed, on a train, in seconds |
| Obsidian mobile over the sync tool | Reading and reviewing |

Be realistic about the second one. Obsidian on a phone is workable; dashboards with
several chart blocks are slow, and editing is fiddly. Chapter 04 named this as one of
the places this system plainly loses, and stage 2 does not change that.

The chat route is the one that gets used, because capture has to be frictionless or it
does not happen. Chapter 12 puts `quick-capture` first in the build order for the same
reason.

## 6. Verify recovery, once

A backup nobody has restored is a hypothesis. Do it now, deliberately, while nothing
is wrong:

```bash
# Clone the remote into a scratch directory and confirm it is complete and current.
git clone <your-private-remote> /tmp/vault-restore-test
cd /tmp/vault-restore-test
ls 10_Journal/$(date +%Y)/$(date +%m)/
git log --oneline -5
rm -rf /tmp/vault-restore-test
```

Two things this reliably surfaces: a `.gitignore` entry excluding something you
assumed was backed up, and a remote that has not received a push in longer than you
thought. Both are silent until the day you need them.

---

## What you have

A vault that exists on three devices, keeps its own history, backs itself up every
five minutes, and is readable and editable from anywhere. Two writers, with rules
about how they coexist.

And a new failure surface: everything in this chapter can stop working quietly. A
push that fails, a sync peer that goes offline, a conflict file accumulating unnoticed.
Chapter 21's checks cover all three, and this is the last stage where you can
reasonably operate without them.

---

**Read next:** [08 — Stage 3: The System Files](./08_stage-3-system-files.md), which
replaces the two rule files from stage 0 with the full set.
