# Second Brain -- Architecture Diagram

This document contains the full system architecture of the AI-powered Second Brain.

---

## High-Level Overview

```
 YOU (Human)
  |
  |  Telegram messages, voice notes,
  |  links, photos, commands
  |
  v
+======================== HETZNER VPS (CX22) ========================+
|                                                                     |
|  +-------------------+     +------------------------------------+   |
|  |  TELEGRAM BOT     |     |  CLAUDE CODE (Agent Runtime)       |   |
|  |  (Node.js)        |---->|                                    |   |
|  |                   |     |  System Prompt + Tools + Memory     |   |
|  |  - Receives msgs  |     |                                    |   |
|  |  - Sends replies  |     |  +------------------------------+  |   |
|  |  - Voice handling |     |  | AGENT PROFILES               |  |   |
|  |  - File uploads   |     |  |                              |  |   |
|  +-------------------+     |  |  - Chief of Staff            |  |   |
|          ^                 |  |  - Librarian                 |  |   |
|          |                 |  |  - Scout                     |  |   |
|          |  responses      |  |  - Confidante                |  |   |
|          |                 |  |  - Strategist                |  |   |
|          +-----------------+  |  - Coder                     |  |   |
|                            |  +------------------------------+  |   |
|                            |                                    |   |
|                            |  +------------------------------+  |   |
|                            |  | TOOLS                        |  |   |
|                            |  |                              |  |   |
|                            |  |  - read_file                 |  |   |
|                            |  |  - write_file                |  |   |
|                            |  |  - search_vault              |  |   |
|                            |  |  - list_directory            |  |   |
|                            |  |  - run_script                |  |   |
|                            |  |  - web_search                |  |   |
|                            |  +------------------------------+  |   |
|                            +------------------------------------+   |
|                                        |                            |
|                                        | reads/writes               |
|                                        v                            |
|  +--------------------------------------------------------------+   |
|  |                    OBSIDIAN VAULT                             |   |
|  |                    /home/alex/SecondBrain/                    |   |
|  |                                                              |   |
|  |  +------------+  +------------+  +-------------+             |   |
|  |  | 10_Journal |  | 20_Projects|  | 11_Readings |             |   |
|  |  |            |  |            |  |             |             |   |
|  |  | Daily logs |  | Compass    |  | Books       |             |   |
|  |  | Notes      |  | Atlas      |  | Articles    |             |   |
|  |  | YYYY/MM/DD |  | Meetings   |  | Highlights  |             |   |
|  |  +------------+  +------------+  +-------------+             |   |
|  |                                                              |   |
|  |  +------------+  +------------+  +-------------+             |   |
|  |  | 05_Wisdom  |  | 30_Life    |  | 40_Network  |             |   |
|  |  |            |  |            |  |             |             |   |
|  |  | Insights   |  | Health/    |  | People/     |             |   |
|  |  | Quotes     |  | Finances/  |  | PEOPLE_     |             |   |
|  |  | Principles |  | Travel/    |  |  INDEX.md   |             |   |
|  |  +------------+  +------------+  +-------------+             |   |
|  |                                                              |   |
|  |  +-------------------+  +----------------------------------+ |   |
|  |  | 00_Start          |  | 99_Assets                        | |   |
|  |  |                   |  |                                  | |   |
|  |  | Inbox/            |  | Scripts/  Templates/             | |   |
|  |  | Goals.md          |  | Agent_Profiles/                 | |   |
|  |  | HABITS_TRACKER.md |  | wisdomizer.js                   | |   |
|  |  | TASKS_DASHBOARD   |  | sync_people_index.js            | |   |
|  |  +-------------------+  | sync_habits.js                  | |   |
|  |                         +----------------------------------+ |   |
|  |                                                              |   |
|  |  Root files: IDENTITY.md, SOUL.md, SECURITY.md, AGENTS.md,  |   |
|  |              TOOLS.md, HEARTBEAT.md, USER.md, MEMORY.md      |   |
|  +--------------------------------------------------------------+   |
|                         |                                           |
|                         | git push (every 6h)                       |
|                         v                                           |
|  +--------------------+    +-------------------+                    |
|  | GIT REMOTE         |    | HETZNER SERVER    |                    |
|  | (GitHub/Gitea)     |    | SNAPSHOTS         |                    |
|  |                    |    |                   |                    |
|  | Full history       |    | Weekly full-disk  |                    |
|  | of all changes     |    | backup            |                    |
|  +--------------------+    +-------------------+                    |
|                                                                     |
+=========================== DOCKER NETWORK ==========================+
          |
          | Obsidian Git Sync (pull)
          v
+======================== YOUR LAPTOP / PHONE =======================+
|                                                                     |
|  +----------------------------+   +-----------------------------+   |
|  |  OBSIDIAN                  |   |  TELEGRAM                   |   |
|  |  (Desktop / Mobile)        |   |  (Mobile / Desktop)         |   |
|  |                            |   |                             |   |
|  |  - Browse vault            |   |  - Send messages            |   |
|  |  - Edit notes              |   |  - Voice notes              |   |
|  |  - Graph view              |   |  - Forward links            |   |
|  |  - Search                  |   |  - Receive briefings        |   |
|  |  - Review wisdom           |   |  - Quick capture            |   |
|  |  - Habit tracking          |   |  - Journal prompts          |   |
|  +----------------------------+   +-----------------------------+   |
|                                                                     |
+=====================================================================+
```

---

## Data Flow: Message Processing

```
User sends Telegram message
         |
         v
+------------------+
| Telegram Bot API |
| receives message |
+--------+---------+
         |
         v
+------------------+
| Message Router   |  Determines message type:
| (Agent Logic)    |  - Text, Voice, Photo, Link, Command
+--------+---------+
         |
    +----+----+----+----+----+
    |    |    |    |    |    |
    v    v    v    v    v    v
  Text Voice Photo Link Cmd  File
    |    |    |    |    |    |
    |    v    |    |    |    |
    |  Whisper|    |    |    |
    |  (STT)  |    |    |    |
    |    |    |    |    |    |
    +----+----+----+----+----+
         |
         v
+------------------+
| Intent Parser    |  Classifies intent:
| (Claude/Gemini)  |  thought, todo, meal, reading, contact,
+--------+---------+  journal, question, command
         |
    +----+----+----+----+----+
    |    |    |    |    |    |
    v    v    v    v    v    v
 Thought Todo  Meal Read  Contact Question
    |    |    |    |    |    |
    v    v    v    v    v    v
 10_    20_  30_   11_  40_  Search
 Journal Proj Life  Read Netw vault
    |    |    |    |    |    |
    +----+----+----+----+----+
         |
         v
+------------------+
| Response Builder |  Confirms action to user
+--------+---------+
         |
         v
+------------------+
| Telegram Reply   |  "Added to today's journal."
+------------------+
```

---

## Scheduled Jobs Flow

```
                     CRON / SYSTEMD TIMERS
                              |
         +--------------------+--------------------+
         |                    |                    |
         v                    v                    v
   [00:00 Daily]       [02:00 Nightly]      [06:30 Morning]
         |                    |                    |
         v                    v                    v
  Create tomorrow's    Run wisdomizer.js    Compile briefing:
  journal template     Run sync_habits.js   - Today's schedule
         |             Run sync_people.js   - Pending todos
         v                    |             - Habit streaks
  10_Journal/                 v             - Wisdom of day
  YYYY/MM/DD.md        05_Wisdom/ (new)          |
                       00_Start/                  v
                        HABITS_TRACKER.md  Send via Telegram
                       40_Network/
                        PEOPLE_INDEX.md
                              |
                              v
                     [00:15 Git Backup]
                              |
                              v
                     git add + commit + push
                              |
                              v
                     Remote repository

         +--------------------+--------------------+
         |                    |                    |
   [Weekly: Monday]    [Weekly: Wednesday]  [Weekly: Sunday]
         |                    |                    |
         v                    v                    v
   Network check       Intelligence         Hetzner server
   (stale contacts)    briefing              snapshot
                       (knowledge synthesis)
```

---

## Docker Container Layout

```
+=================== docker-compose.yml ====================+
|                                                            |
|  +------------------+     +---------------------------+    |
|  | telegram-bot     |     | agent-core                |    |
|  | (Node.js 20)     |<--->| (Claude Code / Python)    |    |
|  |                  |     |                           |    |
|  | Port: internal   |     | Env:                      |    |
|  | Env:             |     |  GEMINI_API_KEY            |    |
|  |  BOT_TOKEN       |     |  ANTHROPIC_API_KEY         |    |
|  |  AGENT_URL       |     |  VAULT_PATH                |    |
|  +------------------+     +---------------------------+    |
|           |                          |                     |
|           |    +---------------------+                     |
|           |    |                                           |
|           v    v                                           |
|  +--------------------------------------------------+     |
|  | vault-data (Docker Volume)                        |     |
|  |                                                   |     |
|  | Mounted at: /home/alex/SecondBrain                |     |
|  | Backed by:  Hetzner Volume (/dev/sdb1)            |     |
|  +--------------------------------------------------+     |
|                                                            |
|  +------------------+     +---------------------------+    |
|  | watchtower       |     | cron-runner               |    |
|  | (Auto-updates)   |     | (Scheduled jobs)          |    |
|  |                  |     |                           |    |
|  | Monitors all     |     | - Git backup (6h)         |    |
|  | containers       |     | - Nightly scripts (00:00) |    |
|  | Weekly check     |     | - Morning briefing (6:30) |    |
|  +------------------+     +---------------------------+    |
|                                                            |
+============================================================+

Network: secondbrain-net (bridge)
All containers communicate on internal network.
Only telegram-bot has external API access.
```

---

## Security Boundary Diagram

```
                        INTERNET
                           |
                      [ Firewall ]
                      UFW Rules:
                      - 22/tcp (SSH)
                      - 443/tcp (HTTPS)
                      - DROP all other
                           |
                    +------+------+
                    |             |
                    v             v
              [ fail2ban ]   [ SSH ]
              Ban after      Key-only auth
              3 failures     No passwords
              24h ban        No root login
                    |
                    v
         +-------------------+
         | Docker Network    |
         | (isolated bridge) |
         |                   |
         | Containers only   |
         | talk to each      |
         | other + Telegram  |
         | API               |
         +-------------------+
                    |
                    v
         +-------------------+
         | Vault Data        |
         |                   |
         | - File perms 600  |
         | - Owned by alex   |
         | - Git-encrypted   |
         |   sensitive files |
         | - .env files NOT  |
         |   in git          |
         +-------------------+
                    |
                    v
         +-------------------+
         | API Keys          |
         |                   |
         | Stored in:        |
         | ~/.env.secondbrain|
         | (chmod 600)       |
         |                   |
         | NEVER in:         |
         | - Git repo        |
         | - Vault files     |
         | - Docker images   |
         +-------------------+
```

---

## Vault Folder Structure (Complete)

```
SecondBrain/
|
+-- IDENTITY.md                    <- System identity and role
+-- SOUL.md                        <- Core values and principles
+-- SECURITY.md                    <- Security rules for agents
+-- AGENTS.md                      <- Agent registry
+-- TOOLS.md                       <- Tool definitions
+-- HEARTBEAT.md                   <- System health status
+-- USER.md                        <- User profile and preferences
+-- MEMORY.md                      <- Persistent agent memory
|
+-- 00_Start/
|   +-- Inbox/                     <- Uncategorized captures land here
|   +-- Goals.md
|   +-- HABITS_TRACKER.md          <- Auto-generated by sync_habits.js
|   +-- TASKS_DASHBOARD.md
|   +-- MASTER_TODOS_Private.md
|   +-- Calendar.md
|
+-- 05_Wisdom/
|   +-- {Category}/                <- Organized by topic
|   +-- Quotes/
|   |   +-- MASTER_QUOTES.md
|   +-- WISDOM_INDEX.md
|
+-- 10_Journal/
|   +-- Notes/
|   +-- 2026/
|       +-- 02/
|           +-- 2026-02-20.md      <- Daily journal entries
|           +-- 2026-02-19.md
|           +-- ...
|
+-- 11_Readings/
|   +-- Tech_AI/
|   +-- Business_Leadership/
|   +-- Design_Product/
|   +-- ...                        <- Reading notes by category
|
+-- 12_Podcasts/
|   +-- Snipd/
|       +-- Data/
|           +-- {Show}/
|               +-- {Episode}.md
|
+-- 20_Projects/
|   +-- {Company}/
|   |   +-- Notes/
|   |   +-- People/
|   |   +-- Meetings/
|   |   +-- Tech/
|   +-- ...
|
+-- 30_Life/
|   +-- Health/
|   +-- Finances/
|   +-- Travel/
|   +-- Intimate/
|   +-- Lists/
|   +-- Recipes/
|   +-- Notes/
|
+-- 40_Network/
|   +-- People/
|   |   +-- Kim_Sarah.md
|   |   +-- Weber_Marcus.md
|   |   +-- Patel_Priya.md
|   |   +-- Park_David.md
|   +-- PEOPLE_INDEX.md            <- Auto-generated by sync_people_index.js
|
+-- 90_Archive/
|   +-- Projects/
|   +-- Readings/
|   +-- Areas/
|
+-- 99_Assets/
|   +-- Scripts/
|   |   +-- wisdomizer.js
|   |   +-- sync_people_index.js
|   |   +-- sync_habits.js
|   |   +-- git_backup.sh
|   |   +-- build_index.sh
|   +-- Templates/
|   |   +-- daily_journal.md
|   |   +-- reading_note.md
|   |   +-- contact.md
|   |   +-- project.md
|   +-- Agent_Profiles/
|   +-- Images/
|   +-- Images_Private/
|   +-- Transcripts/
|   +-- Attachments/
|   +-- Processed/
|
+-- memory/
```

---

*This architecture diagram is part of the [Second Brain Guide](../README.md). For setup instructions, start with [Chapter 1](../01_SERVER_SETUP.md).*
