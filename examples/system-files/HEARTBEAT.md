# HEARTBEAT

## Purpose

This file defines the rhythm of your SecondBrain -- the automated routines that run on schedule without any prompting. Think of it as the heartbeat: steady, reliable, always running in the background.

The actual cron schedule is in `jobs.json`. This file describes WHAT each routine does and WHY.

## Daily Rhythm

### 02:00 -- Nightly Maintenance
- Compact MEMORY.md (remove entries older than 30 days)
- Verify all 8 system files are present and non-empty
- Check disk usage and log warnings if vault exceeds 500 MB
- Write maintenance log to `99_Assets/Logs/maintenance.md`

### 03:00 -- Wisdom Extraction
- Scan `11_Readings/` for notes tagged `#unprocessed`
- For each unprocessed note:
  - Extract key insights, quotes, and takeaways
  - Create or update entries in `05_Wisdom/`
  - Add `[[wikilinks]]` to relevant projects, people, and concepts
  - Remove `#unprocessed` tag
- Log processing summary

### 05:00 -- Journal Skeleton
- Create `10_Journal/YYYY/MM/YYYY-MM-DD.md` from template
- Pre-fill: date, weather, scheduled meetings, active projects, reminders
- Leave reflection sections empty for the evening routine

### 08:00 -- Morning Briefing
- Compile: schedule, top 3 priorities, follow-ups due, project statuses
- Include one relevant wisdom quote
- Send via Telegram
- Save to `10_Journal/Notes/`

### 14:00 -- Midday Check-in
- Brief Telegram message: afternoon focus, upcoming meetings
- No vault writes

### 22:00 -- Evening Journal
- Complete today's daily entry
- Add: accomplishments, conversations, decisions, lessons
- Write evening reflection narrative
- Carry over incomplete tasks to tomorrow
- Send summary via Telegram

## Weekly Rhythm

### Sunday 04:00 -- Library Audit
- Find orphan notes (no inbound links)
- Check for broken `[[wikilinks]]`
- Verify tag consistency
- Update Maps of Content in each top-level folder
- Generate health report

### Monday 09:30 -- Chief of Staff Review
- Review past week: completed tasks, missed goals, blockers
- Analyze journal entries for patterns
- Propose top 5 priorities for the week
- Wait for Alex to confirm before saving

### Wednesday 07:00 -- Scout Report
- Review watch list topics
- Compile intelligence findings
- Connect insights to active projects
- Send report via Telegram

## Routine Behavior Rules

1. **Isolated routines run silently.** No Telegram notification unless explicitly configured.
2. **Main session routines may interact.** The Chief of Staff waits for confirmation.
3. **Never skip a routine without logging why.** If a routine fails, log the error and continue.
4. **Routines do not stack.** If a routine is still running when the next one triggers, the scheduler queues it.
5. **All vault writes must be committed.** Every routine that changes files runs `git add -A && git commit` at the end.
