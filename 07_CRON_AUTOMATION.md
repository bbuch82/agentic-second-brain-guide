# Chapter 07: Cron Automation

[← Obsidian Setup](./06_OBSIDIAN_SETUP.md) | [Home](./README.md) | [Next: Subagent System →](./08_SUBAGENT_SYSTEM.md)

---

> **Goal:** Configure the `jobs.json` schedule so your SecondBrain works while you sleep, wakes you with a briefing, and wraps your day with a journal.

This is where your SecondBrain stops being a chatbot and starts being an autonomous system. Scheduled jobs run automatically -- no Telegram message needed. The Librarian processes your readings at 3am. The morning briefing arrives at 8am. The journal writes itself at 10pm. You wake up to a system that has already done two hours of work.

---

## Table of Contents

- [How Scheduled Jobs Work](#how-scheduled-jobs-work)
- [The jobs.json Schema](#the-jobsjson-schema)
- [Session Types: Main vs Isolated](#session-types-main-vs-isolated)
- [The Full Daily Schedule](#the-full-daily-schedule)
- [Job-by-Job Breakdown](#job-by-job-breakdown)
- [Custom One-Shot Reminders](#custom-one-shot-reminders)
- [Testing Jobs Manually](#testing-jobs-manually)
- [Monitoring and Debugging](#monitoring-and-debugging)

---

## How Scheduled Jobs Work

```
┌──────────┐     ┌────────────┐     ┌──────────────┐     ┌─────────┐
│ jobs.json│────►│ OpenClaw   │────►│ Agent Session │────►│ Vault   │
│ (cron)   │     │ Scheduler  │     │ (main or iso) │     │ + TG    │
└──────────┘     └────────────┘     └──────────────┘     └─────────┘
```

1. OpenClaw reads `jobs.json` from your workspace on startup
2. The built-in scheduler evaluates cron expressions against the server clock
3. When a job triggers, it creates an agent session with the job's payload as the initial message
4. The agent processes the payload, reads/writes vault files, and optionally sends a Telegram message
5. The session ends when the agent finishes

Jobs run in your server's timezone (`TZ=Europe/Berlin` in the Docker config from [Chapter 02](./02_OPENCLAW_INSTALL.md)).

---

## The jobs.json Schema

Place this file at the root of your vault: `/opt/SecondBrain/jobs.json`

Or copy it from [`examples/jobs.json`](./examples/jobs.json).

Each job has the following fields:

```json
{
  "id": "morning_briefing",
  "name": "Morning Briefing",
  "schedule": "0 8 * * *",
  "sessionTarget": "main",
  "wakeMode": "new",
  "payload": "Generate my morning briefing and send it via Telegram.",
  "delivery": {
    "telegram": true,
    "vault": true,
    "vaultPath": "10_Journal/Notes/"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier. Lowercase, underscores. Used in logs and manual triggers. |
| `name` | string | Human-readable name. Shown in logs and Telegram notifications. |
| `schedule` | string | Cron expression (minute hour day-of-month month day-of-week). |
| `sessionTarget` | string | `"main"` or `"isolated"`. See [Session Types](#session-types-main-vs-isolated). |
| `wakeMode` | string | `"new"` creates a fresh session. `"resume"` continues the last session (if one exists). |
| `payload` | string | The instruction sent to the agent. This is the "prompt" for the job. |
| `delivery` | object | Where to send the output: Telegram, vault file, or both. |

### Cron Expression Reference

```
┌───────── minute (0-59)
│ ┌─────── hour (0-23)
│ │ ┌───── day of month (1-31)
│ │ │ ┌─── month (1-12)
│ │ │ │ ┌─ day of week (0-7, 0 and 7 = Sunday)
│ │ │ │ │
* * * * *
```

Examples:

| Expression | When It Runs |
|-----------|--------------|
| `0 8 * * *` | Every day at 08:00 |
| `0 8 * * 1-5` | Weekdays at 08:00 |
| `30 14 * * *` | Every day at 14:30 |
| `0 4 * * 0` | Every Sunday at 04:00 |
| `30 9 * * 1` | Every Monday at 09:30 |
| `0 3 * * *` | Every day at 03:00 |
| `*/15 * * * *` | Every 15 minutes (use sparingly) |

---

## Session Types: Main vs Isolated

### Main Session (`"sessionTarget": "main"`)

- Runs in the primary agent session
- Has access to the full conversation history
- Good for jobs that benefit from context (e.g., morning briefing needs to know what happened yesterday)
- **Caution:** If a main session is already active (you are chatting with the bot), the job waits until it is free

### Isolated Session (`"sessionTarget": "isolated"`)

- Spawns a fresh session with no prior conversation history
- The agent reads system files from scratch
- Good for independent tasks (e.g., wisdom extraction does not need conversation context)
- Multiple isolated sessions can run concurrently (up to `max_concurrent`)
- **Recommended for most jobs** -- avoids blocking your interactive conversations

> **Alex's rule of thumb:** "If the job needs to know what I said yesterday, use main. If it just needs to process files, use isolated."

---

## The Full Daily Schedule

Here is Alex's complete schedule. Copy this as your starting point and adjust the times and payloads to your life.

```
00   01   02   03   04   05   06   07   08   09   10   ...   14   ...   22   23
 │    │    │    │    │    │    │    │    │    │    │          │          │    │
 │    │    ■    ■    ■    ■    │    │    ■    ■    │          ■          ■    │
 │    │    │    │    │    │    │    │    │    │    │          │          │    │
 │    │    │    │    │Sun │    │    │    │Mon │    │          │          │    │
 │    │    │    │    ■    │    │    │Wed │    │    │          │          │    │
 │    │    │    │    │    │    │    ■    │    │    │          │          │    │
```

| Time | Job | Frequency | Session |
|------|-----|-----------|---------|
| 02:00 | Nightly Session Reset | Daily | isolated |
| 03:00 | Nightly Wisdomizer | Daily | isolated |
| 04:00 | Weekly Librarian | Sunday | isolated |
| 05:00 | Daily Journal Creation | Daily | isolated |
| 07:00 | Weekly Scout | Wednesday | isolated |
| 08:00 | Morning Briefing | Daily | main |
| 09:30 | Weekly Chief of Staff | Monday | main |
| 14:00 | Midday Check | Daily | main |
| 22:00 | Evening Journal | Daily | main |

The logic behind the timing:

- **02:00-05:00 (isolated):** Heavy processing runs while you sleep. No conversation interference.
- **08:00 (main):** Morning briefing needs conversation context to feel personal.
- **09:30 (main):** Weekly planning benefits from knowing your recent messages.
- **14:00 (main):** Midday check is a light touch -- same session as your active chat.
- **22:00 (main):** Evening journal wraps up the day in the context of your conversations.

---

## Job-by-Job Breakdown

### 1. Nightly Session Reset

```json
{
  "id": "nightly_session_reset",
  "name": "Nightly Session Reset",
  "schedule": "0 2 * * *",
  "sessionTarget": "isolated",
  "wakeMode": "new",
  "payload": "Perform nightly maintenance: compact the MEMORY.md file by removing stale entries older than 30 days, verify all system files are intact, and log a maintenance summary to 99_Assets/Logs/maintenance.md.",
  "delivery": {
    "telegram": false,
    "vault": true,
    "vaultPath": "99_Assets/Logs/"
  }
}
```

**What it does:** Housekeeping. Cleans stale memory entries, verifies system file integrity, writes a log. Runs silently -- no Telegram notification.

**Why 02:00:** No one is awake. Maintenance can take its time without blocking conversations.

---

### 2. Nightly Wisdomizer

```json
{
  "id": "nightly_wisdomizer",
  "name": "Nightly Wisdomizer",
  "schedule": "0 3 * * *",
  "sessionTarget": "isolated",
  "wakeMode": "new",
  "payload": "Run the wisdom extraction pipeline: scan 11_Readings/ for notes tagged #unprocessed, extract key insights and quotes, create or update wisdom entries in 05_Wisdom/, add cross-links to relevant projects and people, remove the #unprocessed tag from processed notes. Summarize what you processed to the log.",
  "delivery": {
    "telegram": false,
    "vault": true,
    "vaultPath": "99_Assets/Logs/"
  }
}
```

**What it does:** Processes reading notes you dropped during the day. Extracts wisdom, cross-links it, and files it. This is the [Librarian agent](./08_SUBAGENT_SYSTEM.md) in action.

**Why 03:00:** Runs after maintenance, before the journal creation. Wisdom extracted here can be referenced in the morning briefing.

> **Alex's example:** "I highlight a passage from a book during lunch, send it to Telegram with `#reading`. By morning, the Wisdomizer has extracted the insight, linked it to Project Compass, and tagged it. I never touched a filing system."

---

### 3. Weekly Librarian

```json
{
  "id": "weekly_librarian",
  "name": "Weekly Librarian",
  "schedule": "0 4 * * 0",
  "sessionTarget": "isolated",
  "wakeMode": "new",
  "payload": "Perform weekly library maintenance: audit the vault structure for orphan notes (files with no inbound links), check for broken wikilinks, verify tag consistency, update the MOC (Map of Content) files in each top-level folder, generate a library health report. Save the report to 99_Assets/Logs/librarian-report.md.",
  "delivery": {
    "telegram": true,
    "vault": true,
    "vaultPath": "99_Assets/Logs/"
  }
}
```

**What it does:** Deep maintenance of the knowledge base. Finds orphan notes, fixes broken links, updates Maps of Content. Sends a summary to Telegram so you can review on Sunday morning.

**Why Sunday 04:00:** Weekly cadence prevents accumulation of vault entropy. Sunday gives you time to review the report over coffee.

---

### 4. Daily Journal Creation

```json
{
  "id": "daily_journal_creation",
  "name": "Daily Journal Creation",
  "schedule": "0 5 * * *",
  "sessionTarget": "isolated",
  "wakeMode": "new",
  "payload": "Create today's daily journal file at 10_Journal/YYYY/MM/YYYY-MM-DD.md using the daily template. Pre-populate it with: weather for Berlin (if available), scheduled meetings from 00_Start/Calendar.md, active projects status, any reminders due today, and a 'Day Ahead' section. Do NOT fill in reflections or accomplishments -- those come in the evening.",
  "delivery": {
    "telegram": false,
    "vault": true,
    "vaultPath": "10_Journal/YYYY/MM/"
  }
}
```

**What it does:** Creates the skeleton for today's journal entry. Pre-fills it with context so the evening journal routine has something to build on.

**Why 05:00:** Ready before you wake up. The morning briefing at 08:00 can reference it.

---

### 5. Weekly Scout

```json
{
  "id": "weekly_scout",
  "name": "Weekly Scout",
  "schedule": "0 7 * * 3",
  "sessionTarget": "isolated",
  "wakeMode": "new",
  "payload": "Perform weekly intelligence gathering: review the watch list in 20_Projects/watchlist.md, check for updates on tracked topics (industry trends, competitor moves, technology developments relevant to the user's projects), compile findings into a scout report at 20_Projects/reports/YYYY-MM-DD-scout.md. Highlight anything that connects to active projects or goals.",
  "delivery": {
    "telegram": true,
    "vault": true,
    "vaultPath": "20_Projects/reports/"
  }
}
```

**What it does:** Scans your watch list and compiles intelligence. The Scout agent looks at topics you are tracking and writes a brief.

**Why Wednesday 07:00:** Mid-week gives you time to act on findings before Friday. Early enough to arrive before your workday starts.

---

### 6. Morning Briefing

```json
{
  "id": "morning_briefing",
  "name": "Morning Briefing",
  "schedule": "0 8 * * *",
  "sessionTarget": "main",
  "wakeMode": "resume",
  "payload": "Generate my morning briefing. Include: today's schedule and meetings, top 3 priorities, any follow-ups due today, project status summaries for active projects, any reminders or deadlines within the next 48 hours, and one piece of wisdom from the vault that's relevant to today's focus. Format it cleanly and send via Telegram.",
  "delivery": {
    "telegram": true,
    "vault": true,
    "vaultPath": "10_Journal/Notes/"
  }
}
```

**What it does:** Your daily briefing delivered to Telegram. Pulls together everything you need to know for the day.

**Why 08:00 main session:** This is the start of your conversational day. Using the main session means it has context from yesterday. `resume` mode continues the existing conversation.

> **What Alex sees on Telegram at 08:00:**
>
> ```
> Good morning, Alex. Here is your briefing for Wednesday, March 12.
>
> SCHEDULE
> - 09:00 Stand-up with engineering
> - 11:00 1:1 with Sarah Kim (CTO) -- discuss Atlas timeline
> - 14:00 Product review: Compass Q2 roadmap
>
> PRIORITIES
> 1. Finalize Compass Q2 feature list before the 14:00 review
> 2. Follow up with Marcus on the auth migration (due Friday)
> 3. Review Priya's design mockups for the onboarding flow
>
> FOLLOW-UPS DUE
> - Reply to investor update email from Monday
> - Send Emma the restaurant link for Saturday
>
> WISDOM
> "Strategy is about making choices, trade-offs; it's about
> deliberately choosing to be different." -- Michael Porter
> (from your reading notes on Competitive Strategy)
> ```

---

### 7. Weekly Chief of Staff

```json
{
  "id": "weekly_chief_of_staff",
  "name": "Weekly Chief of Staff",
  "schedule": "30 9 * * 1",
  "sessionTarget": "main",
  "wakeMode": "resume",
  "payload": "Run the weekly Chief of Staff review. Analyze the past week: review completed tasks, assess project progress (especially Project Compass and Atlas), identify blockers, check on follow-ups that were not completed, review the week's journal entries for patterns or recurring themes. Then propose the top 5 priorities for this week with rationale. Ask me to confirm or adjust before saving.",
  "delivery": {
    "telegram": true,
    "vault": true,
    "vaultPath": "10_Journal/Notes/"
  }
}
```

**What it does:** Your Monday morning strategy session. Reviews the past week and proposes priorities. Crucially, it **asks for confirmation** -- this is interactive, not automated.

**Why Monday 09:30 main session:** After the morning briefing, after your first coffee, right when you are ready to plan the week. Main session so it can reference your recent conversations.

---

### 8. Midday Check

```json
{
  "id": "midday_check",
  "name": "Midday Check-in",
  "schedule": "0 14 * * *",
  "sessionTarget": "main",
  "wakeMode": "resume",
  "payload": "Quick midday check-in. Review today's priorities from the morning briefing. What should I focus on this afternoon? Any meetings coming up that need preparation? Keep it brief -- 3-4 bullet points max. Send via Telegram.",
  "delivery": {
    "telegram": true,
    "vault": false
  }
}
```

**What it does:** A lightweight afternoon nudge. No vault writes -- just a Telegram message.

**Why 14:00:** After lunch, when focus often drifts. A brief reminder of what matters keeps the afternoon productive.

---

### 9. Evening Journal

```json
{
  "id": "evening_journal",
  "name": "Evening Journal",
  "schedule": "0 22 * * *",
  "sessionTarget": "main",
  "wakeMode": "resume",
  "payload": "Complete today's journal entry at 10_Journal/YYYY/MM/YYYY-MM-DD.md. Review the day: what was accomplished, what conversations happened (both via Telegram and any meetings noted), key decisions made, things learned, and an 'Evening Reflection' section with a brief narrative of how the day went. If there are incomplete tasks, add them to tomorrow's priorities. Keep the tone personal and honest -- this is a journal, not a report.",
  "delivery": {
    "telegram": true,
    "vault": true,
    "vaultPath": "10_Journal/YYYY/MM/"
  }
}
```

**What it does:** Completes the daily journal. Pulls from the morning skeleton, adds everything that happened during the day, and writes a personal reflection.

**Why 22:00 main session:** End of day. Main session has the full context of everything you discussed. The journal reads like it was written by someone who was there for all of it -- because it was.

---

## Custom Recurring Reminders

You can add your own project-specific recurring reminders as jobs. For example, if Wanderly has a Monday morning investor sync that Alex needs to prepare for:

```json
{
  "id": "wanderly_investor_prep",
  "name": "Wanderly Investor Prep Reminder",
  "schedule": "0 9 * * 1",
  "sessionTarget": "main",
  "wakeMode": "resume",
  "payload": "Reminder: Wanderly investor sync is today. Check 20_Projects/Wanderly/ for open items, recent metrics, and anything Alex committed to last week. Summarize what needs attention before the call. Send via Telegram.",
  "delivery": {
    "telegram": true,
    "vault": false
  }
}
```

Add as many of these as you need. Each project, recurring meeting, or periodic check can have its own job. Keep the payloads specific so the agent knows exactly what to do.

---

## Custom One-Shot Reminders

Not everything is recurring. Sometimes you need a one-time reminder.

### Via Telegram

Just tell your bot:

```
Remind me on Friday at 09:00 to send the quarterly report to the board.
```

The agent creates a one-shot job entry in `jobs.json`:

```json
{
  "id": "reminder_20260315_0900",
  "name": "One-shot: Send quarterly report to board",
  "schedule": "0 9 15 3 *",
  "sessionTarget": "main",
  "wakeMode": "resume",
  "payload": "Reminder: Send the quarterly report to the board. (This was requested on March 12.)",
  "delivery": {
    "telegram": true,
    "vault": false
  },
  "oneShot": true
}
```

The `oneShot: true` flag tells the scheduler to delete the job after it fires once.

### Via Direct Edit

You can also add one-shot reminders by editing `jobs.json` directly on the server or through Obsidian.

---

## Testing Jobs Manually

You do not have to wait until 03:00 to test the Wisdomizer. Trigger any job manually via the gateway API:

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_GATEWAY_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"job_id": "nightly_wisdomizer"}' \
  http://localhost:3578/api/jobs/trigger
```

Expected response:

```json
{
  "status": "triggered",
  "job_id": "nightly_wisdomizer",
  "session_id": "sess_abc123",
  "session_target": "isolated"
}
```

Or use the Telegram shortcut:

```
/trigger nightly_wisdomizer
```

The agent runs the job immediately and reports back.

### Testing Tips

1. **Test isolated jobs first** -- they do not interfere with your active conversation
2. **Check the logs** after triggering:
   ```bash
   docker compose logs --tail 50 | grep "nightly_wisdomizer"
   ```
3. **Verify vault output** -- check that files were created/modified:
   ```bash
   ls -la /opt/SecondBrain/99_Assets/Logs/
   ```
4. **Run in dry-run mode** by adding `"(DRY RUN -- describe what you would do but make no changes)"` to the payload

---

## Monitoring and Debugging

### View Scheduled Jobs

```bash
curl -H "Authorization: Bearer YOUR_GATEWAY_TOKEN_HERE" \
  http://localhost:3578/api/jobs
```

Returns all jobs with their next scheduled run time.

### View Job History

```bash
curl -H "Authorization: Bearer YOUR_GATEWAY_TOKEN_HERE" \
  http://localhost:3578/api/jobs/history?limit=20
```

Shows the last 20 job executions with status, duration, and any errors.

### Common Issues

**Job did not run at the expected time:**
- Check timezone: `docker compose exec openclaw date`
- Verify cron expression with [crontab.guru](https://crontab.guru/)
- Check if `jobs.json` has valid JSON: `cat /opt/SecondBrain/jobs.json | python3 -m json.tool`

**Job ran but produced no output:**
- Check the payload is clear enough for the agent to act on
- Review the session log: `docker compose logs --tail 100`
- Verify the target directories exist in the vault

**Main session job is stuck waiting:**
- A main session job waits if you are actively chatting. Finish your conversation or switch the job to `isolated`.

**Too many concurrent isolated sessions:**
- Check `max_concurrent` in `openclaw.json` (default: 3)
- Stagger job times to avoid overlap (notice how the schedule above spaces jobs 1 hour apart)

---

## What We Built

```
02:00 ─── Maintenance (cleanup, verify)
03:00 ─── Wisdomizer (process readings)
04:00 ─── Librarian (vault health, Sunday only)
05:00 ─── Journal skeleton (pre-fill today)
07:00 ─── Scout (intelligence, Wednesday only)
08:00 ─── Morning briefing → Telegram ☀
09:30 ─── Chief of Staff (plan week, Monday only)
14:00 ─── Midday check → Telegram
22:00 ─── Evening journal → Telegram + vault 🌙
```

Your SecondBrain now runs on a schedule. It processes your inputs overnight, briefs you in the morning, nudges you at midday, and journals your day at night. All without you lifting a finger.

Nine jobs, covering overnight processing, daily briefings, and weekly reviews. Adjust the times and payloads to match your schedule.

---

[← Obsidian Setup](./06_OBSIDIAN_SETUP.md) | [Home](./README.md) | [Next: Subagent System →](./08_SUBAGENT_SYSTEM.md)
