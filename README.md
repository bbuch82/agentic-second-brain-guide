# The Agentic Second Brain

*A second brain is not a note system. It is a distributed system, and it has to be
engineered like one.*

---

An agent that writes to your files on a schedule is not a chatbot with file access. It
is a distributed system: several writers, shared mutable state, no transactions, and
partial failure as the normal case. Treated as a note-taking setup, it produces a
convincing demo that quietly rots. Treated as infrastructure, it produces something you
can rely on for years.

The difference is not which agent you pick. It is that the data format is the contract,
the runtimes are replaceable clients, the rules live in files, and the failures that
matter exit zero — so you build something that watches for them.

This guide is the architecture, the code, and the operational practice. Twenty-seven
chapters, all written.

## Scale

Properties of a running installation, given to set the size of what follows.

| | |
|---|---|
| Markdown notes | ~7,800 |
| Files under management | ~11,000 |
| Skills | 27, of which 14 have an implementation |
| Health checks | 13 |
| Continuous operation | ~12 months |
| Running cost | ~15 € / month |

## The architecture

```
        AUTONOMOUS                        COLLABORATIVE
        (runs without you)                (runs with you)

  ┌────────────────────────┐        ┌────────────────────────┐
  │ Agent runtime on a VPS │        │ Coding agent, local    │
  │  · scheduled jobs      │        │  · builds capabilities │
  │  · device and API syncs│        │  · refactors the vault │
  │  · health checks       │        │  · edits the rules     │
  │  · chat interface      │        │ Desktop agent with MCP │
  │                        │        │  · reads live systems  │
  └───────────┬────────────┘        └───────────┬────────────┘
              │                                 │
              └───────────────┬─────────────────┘
                              │
                  ┌───────────▼────────────┐
                  │   THE VAULT            │  ← the only contract
                  │   plain Markdown       │
                  │   YAML frontmatter     │
                  │   append-only JSONL    │
                  │   git + file sync      │
                  └───────────┬────────────┘
                              │
                  ┌───────────▼────────────┐
                  │ Obsidian (you, reading)│
                  └────────────────────────┘
```

No arrow runs from one runtime to the other. Everything meets in the file tree, which
is what makes any single runtime replaceable without touching the rest. The remaining
diagrams — the capture pipeline, the sensor loop, the watchdog's position — are in
[`assets/architecture.md`](./assets/architecture.md).

## Three ways to read this

| You want to | Start at | Why |
|---|---|---|
| Understand the model | [Part 1 — Principles](./PART_1_PRINCIPLES/README.md) | Four chapters, no commands. Transferable to any stack |
| Build it | [Quickstart](#quickstart), then [the full install](#the-full-install) | Thirty minutes with no server, then the autonomous layer |
| Operate it | [Part 5 — Trust](./PART_5_TRUST/README.md) and [Part 6 — Operate](./PART_6_OPERATE/README.md) | The failures, the monitoring, the real costs |

## Quickstart

Stage 0: thirty minutes, no server, no scheduler. At the end an agent files your notes for you.

```bash
mkdir -p secondbrain/{00_Start/Inbox,05_Wisdom,10_Journal,11_Readings,20_Areas,30_Life,40_Network/People,90_Archive,99_Assets/Templates,memory,skills}
cd secondbrain
git init && git add -A && git commit -m "Empty vault skeleton"
```

Write two rule files at the root — `IDENTITY.md` for voice and refusals, `SECURITY.md`
for read-only zones, never-delete and stop-on-ambiguity. Add
`99_Assets/Templates/CONVENTIONS.md` with the filename and frontmatter contract. Add one
skill directory, `skills/quick-capture/SKILL.md`, that routes prefixed messages. Point
your coding agent at the root with a `CLAUDE.md` telling it to read those files first.

Then:

```
n: the two-layer split is the thing I keep having to re-explain
t: write the freshness check before adding another integration
p: Jane Doe, head of platform at Acme, met at the meetup
```

Three messages, three files in the right places with valid frontmatter.

[Chapter 05](./PART_2_BUILD/05_stage-0-thirty-minutes.md) has the full contents of every
file above, and the integrity check to run afterwards.

That is the destination built, and nothing running on a schedule yet. The rest of this
section is the autonomous layer.

## The full install

An always-on host, an agent runtime, a chat interface reachable from a phone, and
scheduled jobs. This is the part that makes the system produce things you did not ask
for that morning. [Chapter 06](./PART_2_BUILD/06_stage-1-autonomous.md) does it properly
— hardening first, with the reasoning; below is the shape.

**Harden before anything runs.** A non-root user, key-only SSH, a closed firewall,
unattended security updates. Do not defer this: the window between provisioning and
hardening is the one that gets used, and the machine holds a decade of your notes plus a
model API key.

**Secrets outside the repository**, root-owned and mode `0600`:

```bash
sudo install -m 600 -o root -g root /dev/null /etc/vault-secrets.env
sudo tee /etc/vault-secrets.env > /dev/null <<'EOF'
MODEL_API_KEY=...
CHAT_BOT_TOKEN=...
CHAT_ALLOWED_ID=...
EOF
```

**The runtime**, with the vault mounted as its workspace:

```yaml
services:
  agent:
    image: ghcr.io/openclaw/openclaw:latest
    container_name: agent
    restart: unless-stopped
    env_file:
      - /etc/vault-secrets.env        # never inline secrets in this file
    volumes:
      - /opt/vault:/workspace         # the vault, read-write
      - ./config:/config
    ports:
      - "127.0.0.1:3578:3578"         # loopback only — see below
    healthcheck:
      test: ["CMD", "curl", "-fsS", "http://localhost:3578/health"]
      interval: 60s
      timeout: 5s
      retries: 3
```

```bash
docker compose up -d && docker compose ps
```

Two details that are not cosmetic:

**The `127.0.0.1:` prefix on the port.** Docker publishes ports by editing the firewall
directly, so `- "3578:3578"` exposes the service to the internet *past* your `ufw`
rules. Binding to loopback is what keeps it private, and this is the most common way a
self-hosted agent ends up reachable by strangers.

**An allow-list of exactly your own account ID on the chat bot.** A bot with no sender
check is an open door to everything in the vault.

**Then exactly two scheduled jobs**, not six:

```
0 7  * * * docker exec agent /usr/local/bin/run-skill morning-briefing >> /var/log/agent-cron.log 2>&1
0 21 * * * docker exec agent /usr/local/bin/run-skill evening-weave   >> /var/log/agent-cron.log 2>&1
```

The evening job writes a completion marker into the day's note. That marker is what the
health checks in [chapter 21](./PART_5_TRUST/21_the-watchdog.md) assert on, and until
something writes it there is nothing to check.

**From here the system can fail without telling you.** Two jobs and a couple of days of
reading the output is manageable by eye; six is not. If you add nothing else, add the
watchdog before the third scheduled job — that is the whole argument of
[Part 5](./PART_5_TRUST/README.md).

Getting the vault onto your laptop and phone without the two copies fighting is
[chapter 07](./PART_2_BUILD/07_stage-2-close-the-loop.md).

## Contents

| Part | Chapters | Covers |
|---|---|---|
| [1 — Principles](./PART_1_PRINCIPLES/README.md) | 01–04 | Why a file tree, why two layers, governance as code, and where this loses |
| [2 — Build](./PART_2_BUILD/README.md) | 05–08 | Four stages, each useful on its own, from thirty minutes to a full installation |
| [3 — Skills](./PART_3_SKILLS/README.md) | 09–13 | Capabilities as versioned artifacts, four patterns with code, composing them |
| [4 — Sensors and Dashboards](./PART_4_SENSORS/README.md) | 14–19 | Device API to query block, complete, with six runnable dashboards |
| [5 — Trust](./PART_5_TRUST/README.md) | 20–23 | Nine real failure modes, the watchdog, idempotency, runbooks |
| [6 — Operate](./PART_6_OPERATE/README.md) | 24–27 | Scale, cost, privacy, and what is still wrong |

## Prerequisites

| | Needed for | Cost |
|---|---|---|
| A local coding agent | Everything from stage 0 | Whatever you already pay |
| A small VPS, 2 vCPU / 4 GB | Stage 1 onward | ~5 € / month |
| An API key for a model provider | The autonomous layer | Usage-based |
| A messaging account with a bot API | The chat interface | Free |
| Obsidian, with Dataview and Charts | Part 4's dashboards | Free |

## What this is not

- **Not a hosted product.** Nothing here is installed for you.
- **Not a plugin.** It is a directory layout, a set of rules, and some scripts.
- **Not zero-maintenance.** You become the operator. Chapter 04 puts numbers on that,
  and chapter 27 says what is still broken.
- **Not a replacement for deciding what matters.** It removes friction from capture and
  retrieval. The thinking stays yours.

## Contributing

Corrections and additions are welcome by issue or pull request. Note that this
repository runs a publication check before every commit; if it blocks your change,
read the reported rule.

## License

[MIT](./LICENSE). Use it, adapt it, ship your own.

---

Guide v1 is archived unedited under [`v1/`](./v1/README_ARCHIVE.md) and tagged `v1.0`.
Its original filenames still resolve.
