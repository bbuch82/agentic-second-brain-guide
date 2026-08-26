# 07 — Stage 2: Close the Loop

The vault now exists in two places: on the server where the agent writes it, and on
your laptop where you read it. Two copies of a shared mutable store is the moment this
stops being a folder and starts being a distributed system.

> Sync is not backup, and backup is not sync. Running one instead of the other is how people lose a week of notes.

---

## Two mechanisms, two jobs

| | Sync | Git |
|---|---|---|
| Answers | Is this file the same everywhere | What changed, when, and can it be undone |
| Latency | Seconds | Minutes, on a schedule |
| Conflict handling | A duplicate file, or a merge you did not see | Explicit, with history |
| Good for | Working across devices | History, backup, recovery |
| Bad at | Telling you what changed last Tuesday | Being current on a phone |

Run both. Git is the recovery story; sync is the working experience. Neither substitutes
for the other, and the failure of treating them as alternatives is silent in both
directions.

## 1. Sync: a headless client on the server

The straightforward choice is your editor's own sync service, with the server running a
**headless instance of that editor as just another peer**. Obsidian Sync is the case
worked here.

Why that beats a general-purpose file syncer, having run both:

| | A file syncer | An editor peer |
|---|---|---|
| Knows what a vault is | No — it sees files | Yes — it understands the config, the plugin list, the trash |
| Conflicts | Duplicate files you clean up by hand | Resolved by the client, per-file |
| Ignore rules | A separate file to maintain | Sync categories in the client's own settings |
| Encryption | Whatever the transport gives you | End-to-end, if the service offers it |
| Mobile | A second app to configure | Already installed |
| Operational surface | A daemon per device | A container on the server, nothing new on your devices |

The last row is the real win. A file syncer means a service to maintain on every device
including the phone. An editor peer means the server is the only unusual participant,
and every other device does what it already did.

```yaml
# /opt/sync/docker-compose.yml
services:
  editor:
    image: lscr.io/linuxserver/obsidian:latest
    container_name: editor
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - /opt/vault:/vault              # the content vault, and nothing else
      - /opt/sync/config:/config
    ports:
      - "127.0.0.1:3000:3000"          # GUI for setup only, loopback bound
    mem_limit: 2048m                   # see below
    shm_size: 1gb
```

Two resource settings that are not guesses. **`mem_limit: 2048m`** — the initial sync of
a large vault is the memory peak of the container's whole life, and a limit that is
comfortable afterwards will get the process OOM-killed mid-download. Half of this was
not enough for a vault of about ten thousand files. **`shm_size: 1gb`** — the browser
engine inside the image needs shared memory and fails obscurely without it.

And on the host: **add swap if the machine has none.** A small VPS running both an agent
runtime and a browser-based editor will touch its ceiling, and swap turns an OOM kill
into a slow minute.

```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### Setting it up through the GUI, once

The container exposes a desktop on loopback. Reach it by tunnel rather than opening a
port:

```bash
ssh -f -N -L 3000:localhost:3000 <host>
# then http://localhost:3000
```

Sign in, enable sync, and select the vault. Four things to get right, each of which cost
real time to learn:

**Open `/vault` directly.** Do not let the client create a vault *inside* the mount. A
new vault at `/vault/<name>` will pull the remote down as a nested copy inside the real
vault, and you get every note twice at a deeper path. Untangling that is an afternoon.

**Turn off plugin and appearance sync categories on the server peer.** The server is
headless and has no business voting on your plugin list. Left on, the list sloshes
between devices and a plugin disabled on the server disappears on your laptop.

**Never use File → Quit in the GUI.** It exits the application inside the container and
leaves you a black screen with a healthy-looking container. Recovery is
`docker restart editor`, but the sync was down until you noticed.

**Then stop using the GUI.** It exists for setup and inspection. Everything else happens
through the files.

### The silent stall

The failure this transport actually has: the client stops syncing while reporting no
error. Pending changes sit in a queue that no longer drains. Observed on both the server
peer and the desktop.

Two consequences worth building around:

**A nightly restart of the server peer, as prophylaxis.**

```
30 4 * * * docker restart editor >> /var/log/editor-restart.log 2>&1
```

**Diagnosis is a file count, not a log.** Compare both sides; the log will tell you
nothing.

```bash
# On the server
find /opt/vault -name '*.md' | wc -l
# On the laptop
find ~/vault -name '*.md' | wc -l
```

A persistent divergence is a stalled peer. Find what is missing:

```bash
comm -23 <(cd ~/vault && find . -name '*.md' | sort) \
         <(ssh <host> 'cd /opt/vault && find . -name "*.md" | sort')
```

Note which side to restart. If the desktop's queue is stuck, restarting the *server*
container does nothing — quit and reopen the editor on the desktop. Getting this
backwards costs an hour of restarting the wrong thing.

Chapter 21 turns "is the peer alive" into a check: container running **and** the
application process inside it alive. The second half matters, because the black-screen
state is a running container with a dead app.

## 2. Git: history and backup

Sync makes devices agree. It does not tell you what a note said last month, and a
deletion that syncs is a deletion everywhere. So the server also commits and pushes on a
short interval — as backup and history, never as transport.

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /opt/vault

git add -A
if git diff --cached --quiet; then
  exit 0                                    # quiet runs log nothing
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

Quiet runs log nothing, because 288 daily "no changes" lines are a log nobody reads —
chapter 21's freshness check gives you liveness instead. A failed push exits non-zero and
says so, because a silent push failure leaves the server as the only copy.

**Do not let sync carry `.git`.** Two peers overwriting each other's index and object
store produce a repository that is corrupt in a way neither can repair. With an editor
peer this is handled for you; with a file syncer, exclude it explicitly.

## 3. Splitting content from configuration

Once sync is reliable, a problem surfaces that was invisible before: **the governance
files should not be on your devices at all.**

Chapter 03's nine files define what the agent may do. They are read on every run, edited
rarely, and there is no reason for them to sit on a laptop, a tablet and a phone — where
a stray edit or a sync conflict changes the system's behaviour. The same is true of
skills, agent state, and logs.

So split the tree in two:

| Layer | Contains | Synced | Edited |
|---|---|---|---|
| **Content vault** | The numbered directories and nothing else | Yes, to every device | Everywhere |
| **Agent layer** | Governance files, skills, agent state, logs | No | Server-side only |

The agent still needs to see one tree. Docker mounts do that, and **the direction
matters more than it looks.**

```yaml
services:
  agent:
    volumes:
      # The agent layer IS the workspace root.
      - /opt/agent:/home/node/workspace:rw
      # The content directories are mounted into it, one line each.
      - /opt/vault/00_Start:/home/node/workspace/00_Start:rw
      - /opt/vault/05_Wisdom:/home/node/workspace/05_Wisdom:rw
      - /opt/vault/10_Journal:/home/node/workspace/10_Journal:rw
      - /opt/vault/11_Readings:/home/node/workspace/11_Readings:rw
      - /opt/vault/20_Areas:/home/node/workspace/20_Areas:rw
      - /opt/vault/30_Life:/home/node/workspace/30_Life:rw
      - /opt/vault/40_Network:/home/node/workspace/40_Network:rw
      - /opt/vault/90_Archive:/home/node/workspace/90_Archive:rw
      - /opt/vault/99_Assets:/home/node/workspace/99_Assets:rw
      # Exception: two measurement logs live in the vault, because the
      # dashboards read them. Mounted as files, not directories.
      - /opt/vault/memory/measurements.jsonl:/home/node/workspace/memory/measurements.jsonl:rw
      - /opt/vault/memory/derived.jsonl:/home/node/workspace/memory/derived.jsonl:rw
```

For the agent, **no path changes.** Every skill, prompt and scheduled job keeps working
against the layout it already knew, which is what makes this refactor safe to do on a
running system.

### Why the other direction fails

The obvious first attempt is the reverse: keep the vault as the workspace root and mount
the agent's files into it. It does not work, and the way it fails is instructive.

Docker creates a mount point before mounting over it. Mounting `IDENTITY.md` into the
vault bind therefore creates a **zero-byte `IDENTITY.md` inside the vault**, and an empty
`skills/` directory beside it. Those stubs are real files on the host. Sync then
faithfully distributed them to every device.

The result: empty governance files appearing on a laptop and a phone, in a tree that was
supposed to no longer contain them, produced by the very change meant to remove them.

Inverting the direction fixes it. Stubs still appear — but in the agent layer, which is
not synced, so nothing sees them and nothing cares.

**The general form:** when overlaying two trees, the *unsynced* one must be the root. Its
mount-point litter is invisible; the synced one's is broadcast.

### The consequence to write down

A **new top-level content directory needs a new mount line**, plus a recreate of the
container. Otherwise the agent simply cannot see it, and the symptom is a capability that
reports finding nothing while the directory is plainly there on your laptop.

```bash
# after editing the compose file
docker compose up -d agent
```

Put that sentence in the runbook. It is a five-second fix and an hour of confusion.

## 4. Deletions happen on a device, never on the server

The rule that costs the most to learn:

> Perform deletions and mass renames on a connected end device with the editor running. Never through the filesystem on the server.

The mechanism: sync tracks state per peer. A file removed from the server's disk while
the peer is stopped is, on restart, a file the peer believes it has *lost*. It repairs
the loss by downloading it again. Your careful cleanup is undone, silently, and it looks
like the deletion never happened.

Delete in the editor on your laptop, let it propagate, and the server follows. Chapter
03's never-delete-only-archive rule already keeps the agent out of this; this rule keeps
*you* out of it.

## 5. Obsidian

Point the editor at the local copy. Three plugins earn their place:

| Plugin | For |
|---|---|
| Dataview, with JavaScript queries enabled | Every dashboard in chapter 18 |
| Charts | The chart blocks in chapter 18 |
| Tasks | Collecting `- [ ] … #todo` lines across the vault into one view |

Tasks demonstrates chapter 03's rule about generated output. Tasks live in the file where
they arose — in the meeting note, next to the context that produced them — and the
dashboard is a *query* that gathers them by path. Hand-editing that dashboard works
perfectly until the next render discards it, with nothing to debug.

## 6. The concurrency rules

**Exactly one scheduler per job.** The same sync can run on a laptop and on the server;
running both produces duplicate sections and conflicts. Disable the loser rather than
merely stopping it — a scheduler you no longer invoke still fires after a reboot.

Write down which host owns each job, next to the job. Chapter 23's runbook format has a
row for it.

**Let the machine write, then read.** Do not edit a note that a scheduled job is about to
write. If the evening job assembles today's entry at 21:00, write before or after. Not a
technical control, and it works.

## 7. Mobile

| Route | Good for |
|---|---|
| The chat interface from chapter 06 | Capture. One-handed, on a train, in seconds |
| The editor on the phone, over sync | Reading and reviewing |

Be realistic about the second. Dashboards with several chart blocks are slow, and editing
is fiddly. Chapter 04 named mobile as a place this system plainly loses, and stage 2 does
not change that. The chat route is the one that gets used.

## 8. Verify recovery, once

A backup nobody has restored is a hypothesis.

```bash
git clone <your-private-remote> /tmp/vault-restore-test
cd /tmp/vault-restore-test
ls 10_Journal/$(date +%Y)/$(date +%m)/
git log --oneline -5
rm -rf /tmp/vault-restore-test
```

Two things this surfaces: an ignore rule excluding something you assumed was backed up,
and a remote that has not received a push in longer than you thought.

---

## What you have

A vault on every device within seconds, its own history every five minutes, and a
configuration layer that lives in exactly one place. The agent sees one tree; sync sees
only content.

And a new failure surface, all of it quiet: a stalled peer, a failed push, a missing
mount line, a deletion that undid itself. Chapter 21 covers each, and this is the last
stage where operating without those checks is defensible.

---

**Read next:** [08 — Stage 3: The System Files](./08_stage-3-system-files.md), which
replaces the two rule files from stage 0 with the full set — now living in the layer this
chapter just separated out.
