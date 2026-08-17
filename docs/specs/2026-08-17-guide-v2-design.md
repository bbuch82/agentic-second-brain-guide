# Design Spec — The Agentic Second Brain (Guide v2)

Date: 2026-08-17
Status: approved, pending implementation plan
Repository: `bbuch82/agentic-second-brain-guide`

---

## 1. Summary

Guide v1 is an eleven-chapter installation manual (~8,350 lines) describing how to
run a self-hosted AI agent against an Obsidian vault: a Hetzner VPS, OpenClaw in
Docker, Telegram as the interface. It has 79 stars and 12 forks after six months.

v2 is a different document. Six months of continuous operation changed what the
interesting problem is. Installing an agent is no longer hard. Making one you can
*trust* — one whose failures are visible, whose state survives concurrent writers,
whose capabilities are versioned artifacts rather than prompt text — is hard, and
almost nobody writes about it.

v2 therefore has two deliverables:

1. **A playbook** — six parts, principles before procedure, built around one thesis.
2. **A starter kit** — a directory that can be cloned and run, shipping a vault
   skeleton, system files, four reference skills, two dashboard pages, and a
   watchdog.

### Thesis

> A second brain is not a note system. It is a distributed system, and it has to be
> engineered like one.

Multiple runtimes, shared mutable state, concurrency, partial failure, recovery.
Build it as a note system and you get a demo. Build it as a distributed system and
you get infrastructure.

Every part of the guide follows from that sentence: the data format is the contract,
runtimes are replaceable clients, governance is code, failure is normal, and
monitoring is not optional.

---

## 2. Goals

- Explain the architecture well enough that a reader who never installs anything
  still leaves with a usable mental model.
- Ship code that runs, so a reader who wants to build has a working system in
  thirty minutes and a full one in an afternoon.
- Document operational reality — failure modes, observability, recovery — because
  that is the material that does not exist elsewhere and the reason practitioners
  will share the document.
- Cover the complete sensor loop end to end: device API to append-only log to
  journal to tag to dashboard. This is the most-requested and least-documented
  part of the whole category.
- Preserve the existing repository's reach (stars, forks, inbound links).

## 3. Non-goals

- No German edition. That is a separate project.
- No hosted service, no installer binary, no web UI.
- No coverage of every integration the author runs. Four patterns are enough for a
  reader to build the fifth themselves; a large surface of external APIs is
  maintenance debt for the repository owner.
- No autobiography. See section 4.

---

## 4. Privacy constraints (hard requirements)

The guide describes a system the author operates. It must not describe the author.

**The rule: the form is real, the content is invented, the author is invisible.**

Prohibited in every file that ships:

| Category | Examples of what is excluded |
|---|---|
| Identity | Author name and variants, family members, colleagues, any real person |
| Organizations | Employers, clients, mandates, brand names, product names from the author's work |
| Vault content | Real note text, real area names, real project names, real meeting content |
| Infrastructure identifiers | Server hostnames, private repository names, absolute local paths, launch-agent identifiers, container names that encode a name |
| Contact and account data | Email addresses, chat IDs, bot tokens, domains, API keys |
| Personal measurements | Body weight, VO2max, resting heart rate, sleep values, any health reading |
| Private habit categories | Anything touching partnership, sexuality, conflict, or children |
| Screenshots | None at all, in any chapter |

Permitted:

- Rounded, aggregate system metrics phrased as properties of the system rather than
  facts about a person: "past roughly ten thousand notes, the following happens"
  rather than "my vault contains 2,591 distilled notes".
- Named third-party products (OpenClaw, Claude Code, Obsidian, Dataview, Syncthing,
  Hetzner, Garmin, Docker). These are tools, not personal data, and a guide that
  refuses to name its tools is useless.
- Real failure narratives, de-identified. A silent journal skip, a corrupted
  frontmatter batch, or a wrong-person calendar attribution are engineering stories.
  They keep all their instructional value with the anecdote removed.

### Voice

Third person and second person. No first-person singular, no experience report, no
persona. v1 followed a fictional "Alex Chen"; v2 has no character at all. Examples
use structurally realistic but obviously synthetic content and neutral placeholders
(`Acme`, `<Area>`, `Doe_Jane`, `<baseline>`, `<target>`).

Authority comes from precision, not from proximity.

### Enforcement

A pre-commit hook runs `tools/privacy-check.sh` over every tracked file.

- The denylist itself **must not live in the repository**. It contains exactly the
  strings that must never be published; committing it would publish them. It lives
  at a path outside the repository, referenced by environment variable
  `ASBG_DENYLIST` and defaulting to `~/.config/asbg/denylist.txt`.
- The repository contains `tools/privacy-check.sh` and
  `tools/denylist.example.txt`, the latter holding category comments and generic
  patterns only (email addresses, IPv4 literals, `/Users/<name>/`, `ssh <host>`,
  bearer-token shapes).
- The check is case-insensitive, matches on word boundaries where the term is a
  name, and exits non-zero on any hit. A hit blocks the commit; there is no
  bypass flag documented in the repository.
- `tools/privacy-check.sh` also runs as the final step of every delivery stage,
  not only at commit time.

---

## 5. Repository layout

```
README.md                     Hook, numbers, architecture diagram, three reading
                              paths, quickstart. Must stand alone.
LICENSE                       MIT (unchanged)
CHANGELOG.md                  What changed from v1 to v2, and why
PART_1_PRINCIPLES/
PART_2_BUILD/
PART_3_SKILLS/
PART_4_SENSORS/
PART_5_TRUST/
PART_6_OPERATE/
starter/                      The clonable kit (section 7)
assets/
  architecture.md             Canonical diagrams, ASCII, screenshot-friendly
docs/
  specs/                      This file and successors
tools/
  privacy-check.sh
  denylist.example.txt
v1/                           Frozen v1, verbatim
01_SERVER_SETUP.md            Redirect stubs — original filenames, ~10 lines each,
02_OPENCLAW_INSTALL.md        pointing at both the v1 archive and the v2 equivalent
… (all eleven v1 filenames)
```

v1 is additionally preserved as git tag `v1.0` at commit `4692d67`.

Redirect stubs exist because external links to `01_SERVER_SETUP.md` and friends are
in the wild across forks and posts. Each stub is a short file: one sentence that v2
superseded it, a link to `v1/<same-file>`, and a link to the v2 chapter covering the
same ground.

---

## 6. Content architecture

Chapters are numbered continuously across parts so a reader can cite "chapter 17"
without naming a part.

### README

The single most important file. A reader who reads only this must understand the
mental model and be able to decide whether to build.

Contents, in order:

1. Title and one-line thesis.
2. A cold open of at most 150 words that states the problem operationally: an agent
   that writes to your files while you sleep is a distributed system with a shared
   mutable store, and the interesting failures are the quiet ones.
3. Numbers table — rounded, unpersonal: order of magnitude of notes, months of
   continuous operation, monthly cost, number of skills, number of health checks,
   number of scheduled jobs. Every figure is confirmed with the repository owner
   before it ships; none is inferred, and none is stated more precisely than the
   nearest round number that is still true.
4. The canonical architecture diagram (see below).
5. Three reading paths: *understand it* (Part 1), *build it* (README quickstart then
   Part 2), *operate it* (Parts 5 and 6).
6. Quickstart — the thirty-minute path, inline, copy-pasteable.
7. Table of contents for all six parts.
8. What this is not: not a hosted product, not a plugin, not zero-maintenance.

### The canonical diagram

One diagram, ASCII so it survives being pasted anywhere, designed to be
screenshotted. It shows the two-layer model with the vault as the only shared
truth:

```
        AUTONOMOUS                        COLLABORATIVE
        (runs without you)                (runs with you)

  ┌────────────────────────┐        ┌────────────────────────┐
  │ OpenClaw on a VPS      │        │ Claude Code (local)    │
  │  · cron jobs           │        │  · builds skills       │
  │  · scheduled syncs     │        │  · refactors the vault │
  │  · watchdog + alerts   │        │  · governance edits    │
  │  · Telegram interface  │        │ Desktop agent w/ MCP   │
  │                        │        │  · live work context   │
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

The point the diagram makes: no arrow goes runtime-to-runtime. Everything meets in
the file tree. That is what makes any single runtime replaceable.

---

### PART 1 — PRINCIPLES (chapters 01–04)

The part that gets quoted. Ideas, not commands.

**01 — The vault is the API.** Markdown plus YAML frontmatter as an interface
contract between programs. What it buys: any language can read it, git gives you
history and diffs for free, no migration path is ever needed, and the human can
edit the same bytes as the agent. What it costs: no referential integrity, no
transactions, no schema enforcement — so validation has to be a separate check
(forward reference to chapter 21). Naming and frontmatter conventions presented as
a contract with a stated reason per field, not as a style preference.

**02 — Two layers.** The autonomous layer runs on a schedule and must never require
a human; the collaborative layer runs in a session and must never be required by a
schedule. Which work belongs where, and the failure that follows from getting it
wrong: a scheduled job that needs a decision hangs silently, and an interactive
task encoded as cron produces confident garbage. The vault is the seam. Includes
the desktop-agent-with-MCP case: live systems (mail, chat, tickets) are read at
session time and only their *conclusions* are written to the vault, because live
systems are not durable state.

**03 — Governance as code.** Nine system files form a written constitution the agent
reads on every run: identity and tone, philosophy and refusals, capability
inventory, scheduled routines, user profile, memory index, sub-agent registry, the
security boundary, and the harness-level instruction file that the coding agent
itself obeys. Concrete rules with their rationale:

- Read-only zones — which files an agent must never rewrite, and why the ones that
  define its behaviour are exactly that set.
- Append-only zones — structured logs where overwriting destroys history.
- Never delete, only archive — because an agent's mistaken deletion is unrecoverable
  from the agent's own perspective.
- Documented exceptions — the pattern where a specific script gets a specific,
  dated, written exemption from a general rule, recorded next to the script rather
  than in someone's memory.
- Dashboards that are queries, not files: never hand-edit generated output.

**04 — An honest comparison.** Against hosted note-AI products, chat-assistant
memory, and commercial second-brain tools. Where this system wins: data ownership,
queryability across life domains, cost, no vendor deprecation risk, and the ability
to add a capability in an afternoon. Where it loses, stated plainly: you are now on
call for it; there is no mobile-native experience beyond Obsidian and a chat
window; setup takes real time; and a hosted product will beat it on polish forever.
A comparison chapter that only lists wins destroys the credibility of everything
around it.

---

### PART 2 — BUILD (chapters 05–08)

Staged. Each stage ends with a system that works and is useful on its own, so a
reader can stop at any stage and still have something.

**05 — Stage 0, thirty minutes.** Vault skeleton, minimal system files, Claude Code
locally, one working skill. No server, no Docker, no Telegram. The reader ends with
an agent that can classify and file a note. This ordering is deliberate: the lowest
possible barrier to a first working loop, before any infrastructure exists.

**06 — Stage 1, make it autonomous.** Provision and harden a VPS, install Docker,
deploy OpenClaw with compose, connect Telegram, add the first two scheduled jobs
(a morning briefing and a nightly journal). Security hardening covered as it is
performed rather than deferred to an appendix: non-root user, key-only SSH,
firewall, no secrets in the compose file, `0600` env files owned by root.

**07 — Stage 2, close the loop.** git as history and remote backup, file sync as
propagation, Obsidian as the human view, mobile. The concurrency discussion belongs
here, at the moment two writers first exist: what sync conflict files are, why they
appear, why two schedulers must never target one vault, and how git and a
continuous file-sync tool coexist without fighting.

**08 — Stage 3, the system files.** Each of the nine files: what it is for, what
goes in it, what breaks when it is wrong, and a complete synthetic example. The
"what breaks" column is the valuable one — a vague identity file produces a
sycophantic agent, a missing security file produces a destructive one, an
over-stuffed capability file blows the context budget on every single run.

---

### PART 3 — SKILLS (chapters 09–13)

The largest architectural delta from v1. v1 had six agent profiles defined in
prose. v2 has skills: versioned, specified, sometimes tested capability artifacts.

**09 — Anatomy of a skill.** A skill is a directory with a `SKILL.md` contract and
optionally an implementation. The contract states purpose, trigger, inputs,
outputs, invariants, and failure behaviour. The decision rule for code versus
specification only: if the operation needs judgment, keep it a specification and
let the agent execute it; if it needs determinism, idempotency, or runs unattended
on a schedule, write code. Mixed cases — the agent decides *what*, the script
guarantees *how*.

**10 — Design, plan, implement.** Why a non-trivial skill gets a dated design
document and a plan document before any code. The argument is not process
fetishism: the design document is the artifact that lets an agent implement the
skill correctly in a later session with no memory of this one, and it is the only
place the *reason* for a decision survives. Includes a full synthetic design
document and its plan, plus the pattern of a `Historie`-style section on the
contract recording what changed, when, and what incident caused it.

**11 — Four patterns.** Each with complete, runnable code and its own failure
discussion.

| Pattern | Teaches |
|---|---|
| LLM classification and routing | Classification matrix, move-never-copy, filing rules, ambiguity escalation to the human |
| Batch pipeline on a schedule | Selecting unprocessed input, bounded batch size, resumability, cost control |
| Sensor sync with a state file | Catch-up from last known state, idempotency, token reuse, partial-data days — detailed in Part 4 |
| Test-driven importer | Fixtures from real export formats, unit tests per parser, guarded output blocks that preserve agent-authored content across re-imports |

The guarded-block idea gets its own section: a generated region delimited by
markers so a script can rewrite its own output on every run without destroying
prose an agent or human wrote in the same file. This is the mechanism that makes
repeated imports safe.

**12 — Skill inventory.** A table of every skill category in a mature system:
purpose, trigger, code or spec, schedule, and what it writes. Around thirty rows.
Built to be screenshotted, and functioning as an idea menu — most readers will
recognise five they want and build those.

**13 — Composing pipelines.** Skills are not features, they are stages. The capture
pipeline: arbitrary input to inbox to classification to filing to cross-linking to
distillation to deepening to publishable output. Each arrow is a contract; each
stage is independently runnable and independently testable. What makes composition
work is that every stage's output is a file that satisfies the vault contract from
chapter 01 — which is the thesis, demonstrated.

---

### PART 4 — SENSORS AND DASHBOARDS (chapters 14–19)

The complete device-to-visualization loop. Documented nowhere else in one piece.

**14 — The sensor loop.** Device to vendor API to append-only JSONL to journal
section to tag to dashboard query. Why each hop exists. Why measurements go to
append-only JSONL rather than into frontmatter: they are time series, they are
written by a machine, they must never be silently rewritten, and one line per day
survives partial failure. Why a human-readable summary *also* lands in the journal:
so the number sits next to the day it belongs to and the agent reads it as context.

**15 — Building the sync.** Full implementation walkthrough of a real health sync,
Garmin as the worked example.

- Authentication without a password in the script: reuse OAuth tokens written by
  another tool, and what to do when they expire roughly annually.
- Catch-up logic: read the last date in the log, fetch forward to yesterday. No
  cursor file to corrupt, because the output *is* the cursor.
- Days with no data: skip and retry later rather than writing an empty record —
  a watch left on the charger must not become a permanent gap.
- Idempotency: a marker section in the journal means a re-run is a no-op.
- Partial data: fields the vendor only exposes for the most recent day get written
  only for that day, and the dashboard is written to tolerate nulls.
- Two logs, not one, when two datasets have different catch-up semantics.
- The documented-exception pattern: this script writes to zones the general rules
  reserve, so the exemption is written down, dated, and scoped next to the script.
- An adapter seam so Oura, Whoop, or Fitbit can replace Garmin: the boundary is a
  function returning one normalized record per day.

**16 — Tags as the interface.** A habit tag is written by three independent
producers — the sync script, the agent during a conversation, and the human typing
in Obsidian — and consumed by one query. That works only because the tag vocabulary
is a documented contract, not an emergent convention. Tag naming, the thresholds
that turn a measurement into a boolean habit, and why the threshold belongs in the
producer rather than the query.

**17 — Dataview mechanics.** The techniques the archetypes rely on, each isolated:
loading and parsing JSONL from a query block; de-duplicating records through a map
keyed by date so a re-import cannot double-count; bucketing days into ISO weeks;
deriving metrics that the vendor does not provide; spanning gaps so untracked days
do not break a line; and tolerating nulls everywhere, because a sensor dataset is
never complete. Prerequisites and their versions stated once, here.

**18 — Dashboard archetypes.** Six, each with complete runnable code, a screenshot-
free description of what it shows, and the reason it is built that way.

| Archetype | Shows | Technique |
|---|---|---|
| KPI table | Seven-day aggregate at a glance | Table plus averages over a filtered window |
| Stacked weekly bars | Training volume by category | Week bucketing, category mapper |
| Dual-axis load vs. recovery | Whether a rest day is due | Two y-axes, bars plus line |
| Efficiency chart | Same pace at lower heart rate as progress | Inverted y-axis, derived metric |
| Streaks and year heatmap | Habit consistency over months | Tag aggregation across journal files |
| Goal progress bars | Computed distance to a target | Baseline and target to percentage, inline markup |

All labels in English. All goal values as `<baseline>` and `<target>`. The habit
vocabulary is a neutral set — movement, sleep, reading, focus, nutrition,
screen-free — with an explicit instruction that the reader defines their own, and
an explicit note that a private habit set is a reason to keep this system
self-hosted.

**19 — Why not the vendor app.** The strongest argument in the guide, and the one
that answers "why not just use a hosted product" for the whole document.

The vendor has the sensor data. The vendor does not have the journal. Once both
live in one vault behind one query engine, questions become answerable that no
fitness application can answer — sleep quality against days a conflict was logged,
training volume against self-reported focus, resting heart rate against travel
weeks. Not because the analysis is clever, but because the data is finally in one
place. Generalized: the value of a second brain is proportional to how many domains
share one query surface, which is why the vault is the center and the agent is not.

---

### PART 5 — TRUST (chapters 20–23)

The differentiator. This is the part that does not exist elsewhere.

**20 — Failure modes of agentic systems.** A catalogue from real operation,
de-identified, each row expanded into symptom, why no alarm fired, diagnosis, and
fix.

| Failure mode | Symptom | Why nothing alarmed | Fix |
|---|---|---|---|
| Silent skip | A day with no generated entry | The job succeeded; it simply did nothing | Completion marker per unit of work, checked externally |
| Silent corruption | Dozens of notes with invalid frontmatter | Nothing parses frontmatter until something needs it | Vault-wide parse check |
| Wrong attribution | Events from a shared calendar assigned to the wrong person | Technically correct, semantically wrong | Explicit attribution rule in the prompt contract |
| Stale source treated as truth | The agent guesses instead of reporting staleness | The file existed; it was merely old | Freshness field plus a mandatory degraded path |
| Concurrency artifacts | Sync conflict files accumulate | No check knew the filename pattern | Baseline existing ones, alarm only on new |
| Two schedulers, one target | Duplicate sections, conflict files | A laptop scheduler and a server cron ran the same job against one vault | Exactly one scheduler per job; the other is disabled, not merely unused |
| Silent sensor outage | Dashboards show gaps, nobody notices | Expired token, job exits cleanly with zero rows | Freshness check on the log file |
| Tool conflict in a scheduled job | A daily error nobody reads | The error went to a log, not to a channel | Restrict tool scope per job; route errors to a human channel |

The chapter's argument: every one of these is a *success-shaped* failure. The
process exited zero. This is why success exit codes are not evidence and why the
checks in chapter 21 assert on outcomes in the vault rather than on job status.

**21 — The watchdog.** A single scheduled process that asserts on the state of the
vault, not on the state of the jobs. Around thirteen checks across four families:

- *Freshness* — a file that should have changed recently did.
- *Integrity* — everything that should parse, parses.
- *Completeness* — every unit of work has its completion marker.
- *Capacity* — disk, container health.

Design decisions with rationale: every threshold is an environment variable so
tuning does not require a deploy; alert cadence is one alert at onset, one reminder
per interval while failing, and one explicit recovery message, because a check that
alerts every run trains you to ignore it; state lives outside the vault so a vault
restore cannot resurrect stale alerts; pre-existing violations are baselined on
first run so a new check does not open with a wall of noise; and the health summary
is also written into the vault so the agent can read its own status.

The chapter includes a walkthrough of adding a check in response to an incident,
which is how a check set of thirteen actually comes into existence.

**22 — Idempotency and state.** How a scheduled writer survives running twice.
Marker sections, guarded blocks, derive-the-cursor-from-the-output, append-only
logs with a keyed de-duplicating reader, and move rather than copy-then-delete.
Each with the concrete corruption it prevents.

**23 — Recovery runbooks.** Short, imperative, one per plausible failure: sync
stopped, token expired, conflict files appeared, git diverged, container will not
start, a scheduled job errors daily, the vault has invalid frontmatter, a day is
missing. Format is fixed — symptom, one diagnostic command, fix, verification.
The chapter also argues that the runbook belongs next to the script in the
repository, because a runbook nobody can find during an incident is not a runbook.

---

### PART 6 — OPERATE (chapters 24–27)

**24 — Scale.** What roughly ten thousand notes does to the system. Which
operations stay constant-time and which degrade. Why a full-text grep beats an
embedding index for most retrieval in a vault this size, and where that flips.
The context budget as the real constraint: every file the agent reads on every run
is a recurring cost, which is what forces the system files to stay small and the
memory index to be an index rather than a store. Concrete techniques: index files,
scoped searches, per-area context files, and pre-computed dashboards.

**25 — Cost and model routing.** Where the money actually goes, which is almost
never where readers expect: unattended batch pipelines dominate, interactive
sessions are noise. Routing by job rather than by preference — cheap models for
classification and extraction, expensive models for synthesis and judgment,
no model at all for anything deterministic. The per-job cost table and how to
measure it in your own setup rather than trusting the guide's numbers.

**26 — Privacy in practice.** What never leaves the machine and what necessarily
does. Secrets handling: root-owned mode-`0600` environment files outside the vault,
never in the repository, never in the compose file, never in a note. What a
sensitive-content classification rule actually looks like in a governance file.
The backup question: an encrypted vault backup that the agent cannot read is worth
more than a convenient one it can.

**27 — What is still wrong.** The credibility chapter, written last and honestly.
What remains fragile, which decisions would be made differently now, which
integrations are not worth their maintenance cost, and where the system genuinely
does not deliver. Concretely includes: the guide's own untestable installation
path, the maintenance cost of every external API, the fact that nothing here
removes the operator, and the unresolved question of what happens to a system like
this when its owner stops maintaining it.

---

## 7. Starter kit

```
starter/
  README.md                 What this is, what it needs, what it does not do
  setup.sh                  Interactive, idempotent, safe to re-run
  .env.example
  compose.yml
  vault/
    <PARA skeleton>         Empty numbered directories with a README each
    system/                 Nine system-file templates, {{PLACEHOLDER}} markers
    templates/              Frontmatter templates: note, person, meeting, reading,
                            journal, project
    dashboards/
      HABITS.md             Six query blocks, neutral habit vocabulary
      SPORTS.md             Seven query blocks, placeholder goals
  skills/
    process-inbox/          Pattern: LLM classification and routing
    distill/                Pattern: scheduled batch pipeline
    sensor-sync/            Pattern: real, working Garmin sync with an adapter seam
    importer/               Pattern: TDD, real tests, real fixtures
  watchdog/
    check.py                Generalized checks, env-var thresholds, alert cadence
    README.md               Runbook
```

Design decisions:

- **`setup.sh` is idempotent and interactive.** It asks, it never overwrites without
  asking, and running it twice is a no-op. Every write it performs is echoed. It
  refuses to run against a non-empty directory unless explicitly confirmed.
- **The skills are rewrites, not copies.** The author's implementations are coupled
  to the author's life; these are written from the same patterns against a clean
  vault contract.
- **`sensor-sync` ships as a real Garmin sync**, not a fictional service. A fake
  integration teaches nothing about token expiry, partial data, or catch-up. The
  adapter seam is documented so another device can be substituted, and the chapter
  states plainly that this is the one component with a third-party dependency that
  can break.
- **Every skill has a `SKILL.md`** that matches the contract format taught in
  chapter 09, so the kit demonstrates its own convention.
- **`importer` ships with real passing tests** and fixtures in a common export
  format, because "write tests for your skills" is unconvincing without a runnable
  example.

---

## 8. Style rules

- English throughout, including code comments, chart labels, and file names.
- No AI-writing tells. After drafting, every file gets a pass with the `humanizer`
  skill: no rule-of-three lists, no "not only X but Y", no inflated adjectives, no
  em-dash storms, no vague attributions, no promotional summary paragraphs. v1 has
  a measurable amount of this and it reads as generated.
- One quotable sentence per chapter, set as a blockquote, positioned so it can be
  copied without context.
- Code blocks are complete and runnable, never elided with an ellipsis comment. If
  a snippet is too long for prose, it lives in `starter/` and the chapter links it.
- Tables over paragraphs whenever the content is a mapping.
- Every chapter opens with the problem it solves in two sentences and ends with
  what to read next.
- No emoji in headings. Emoji only where they are data, such as a legend.

## 9. Virality mechanics, deliberately built in

1. The README works standalone: model, numbers, diagram, decision.
2. Two artifacts designed to be shared on their own — the failure-mode matrix
   (chapter 20) and the skill inventory (chapter 12).
3. One canonical ASCII diagram that survives being pasted into any medium.
4. A pull-quote per chapter.
5. Chapter 27 as the credibility anchor. Documents that admit what is broken get
   forwarded by practitioners; documents that only sell do not.
6. A thirty-minute first success in Stage 0, before any infrastructure, so the
   conversion from reader to user does not require a credit card.

## 10. Verification

What will be verified before publication:

- Every skill in `starter/skills/` runs against a scratch vault; `importer` tests
  pass.
- `setup.sh` runs twice in a row against an empty directory and against a populated
  one, with the second run a no-op.
- Watchdog checks fire correctly against a deliberately broken scratch vault.
- Every dashboard query block is syntax-checked; query blocks are additionally
  loaded in Obsidian against a synthetic dataset with gaps and nulls.
- Every internal link resolves.
- `tools/privacy-check.sh` passes on the full tree.

What cannot be verified by the author of this document, and is therefore marked in
the plan as **requires owner verification before publication**:

- A from-scratch VPS provision, Docker install, OpenClaw deploy, and Telegram
  pairing. These steps are transcribed from a running installation and have not been
  re-run from zero. A starter kit whose installation path has never executed is the
  fastest way to lose the credibility the rest of the document earns.
- Real Garmin authentication against a live account.
- Mobile file-sync setup.

## 11. Delivery stages

| Stage | Output | Gate |
|---|---|---|
| 1 | Repository skeleton, README, canonical diagram, `v1/` archive, redirect stubs, `v1.0` tag, privacy check and hook | Owner reviews README and diagram |
| 2 | Part 1 and Part 5 | Owner reviews the two load-bearing parts |
| 3 | Part 3 and Part 4 | Owner reviews skills and sensor loop |
| 4 | Part 2 and Part 6 | Owner reviews build path and operations |
| 5 | `starter/` complete, verification run, `humanizer` pass, `CHANGELOG.md` | Owner verifies the unverifiable steps, then publish |

Estimated size: 15,000–20,000 lines of prose plus the kit, against v1's 8,349.

## 12. Risks

| Risk | Mitigation |
|---|---|
| Privacy leak through an overlooked detail | Denylist hook plus a manual read-through of every file in stage 5; denylist stored outside the repository |
| Untested installation path damages credibility | Explicitly gated on owner verification in stage 5; steps marked in the document until confirmed |
| Scope growth turns this into a book that never ships | Five staged deliveries, each independently publishable; no chapter added after this spec without an explicit decision |
| The Garmin dependency breaks | Adapter seam documented; chapter 27 names it as a known maintenance cost |
| Length deters readers | Three reading paths in the README; every part readable independently |
| v1 link rot | Redirect stubs at the original filenames plus the `v1/` archive plus the git tag |
