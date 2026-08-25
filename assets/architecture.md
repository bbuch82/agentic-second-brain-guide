# Architecture

Plain ASCII throughout, so every diagram survives being pasted into a terminal, an
issue, a chat window, or a slide. The two-layer diagram is canonical and appears
byte-identically in the README.

---

## 1. The two-layer model

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

No arrow runs runtime to runtime. Every path goes through the file tree, which is what
makes any single runtime replaceable without touching the other — the whole architecture
in one property.

Detail: [chapter 02](../PART_1_PRINCIPLES/02_two-layers.md).

## 2. The capture pipeline

Each arrow is labelled with the contract it satisfies, not with a verb — because what
travels between stages is a file, never a call.

```
  anything                                        something you reread
      │                                                    ▲
      ▼                                                    │
  ┌────────┐   ┌──────────┐   ┌────────┐   ┌─────────┐  ┌──┴───┐
  │ inbox  │──▶│ classify │──▶│  file  │──▶│  link   │─▶│distil│
  └────────┘   └──────────┘   └────────┘   └─────────┘  └──┬───┘
   a file       a decision      a path      a graph        │
   exists       recorded        that is     that is     ┌──▼───┐
                                stable     traversable │deepen│
                                                        └──┬───┘
                                                        ┌──▼───┐
                                                        │compile│
                                                        └──────┘
```

Detail: [chapter 13](../PART_3_SKILLS/13_composing-pipelines.md).

## 3. The sensor loop

Marked with the property that makes each hop safe to repeat.

```
  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────────┐
  │  device  │───▶│  vendor  │───▶│   sync   │───▶│ measurements │
  │          │    │   API    │    │   job    │    │ .jsonl       │
  └──────────┘    └──────────┘    └────┬─────┘    └──────┬───────┘
     you wear it     you don't        │ scheduled       │ append-only
                     control it       │ idempotent      │
                                      │                 │
                                      ▼                 │
                              ┌──────────────┐          │
                              │ day's note   │          │
                              │ ## Device    │          │
                              │ + #habit/... │          │
                              └──────┬───────┘          │
                                 idempotent             │
                                 via marker             │
                                      │                 │
                                      └────────┬────────┘
                                               │
                                        ┌──────▼───────┐
                                        │  dashboard   │
                                        │  query block │
                                        └──────────────┘
                                          derived, never edited
```

Detail: [chapter 14](../PART_4_SENSORS/14_the-sensor-loop.md).

## 4. Where the watchdog sits

```
   ┌───────────────┐        ┌───────────────┐
   │ scheduled job │        │ scheduled job │
   └───────┬───────┘        └───────┬───────┘
           │  writes                │  writes
           └────────────┬───────────┘
                        ▼
              ┌───────────────────┐
              │    THE VAULT      │
              └─────────┬─────────┘
                        │  reads
                        ▼
              ┌───────────────────┐        ┌──────────────┐
              │     watchdog      │───────▶│  you, alerted│
              │  every 15 min     │        └──────────────┘
              └───────────────────┘
                        │  also writes
                        ▼
              ┌───────────────────┐
              │ system_health.md  │  ← so the agent can read its own status
              └───────────────────┘
```

The arrow points at the vault, not at the jobs. A job's exit code reports whether it
ran, and every interesting failure in this system is one where the job ran and exited
zero.

Detail: [chapter 21](../PART_5_TRUST/21_the-watchdog.md).
