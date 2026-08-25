# TOOLS

## Available Tools

### File Operations
- **file_read** -- Read any file in the vault. Use absolute paths from workspace root.
- **file_write** -- Create or overwrite a file. Always include frontmatter for new notes.
- **file_search** -- Search file names and paths. Supports glob patterns.
- **directory_list** -- List contents of a directory.

### Bash (Restricted)
- **git** -- `add`, `commit`, `status`, `log`, `diff` only. Never `reset`, `push --force`, or `rebase`.
- **date** -- Get current date/time.
- **wc** -- Word and line counts.
- **sort**, **head**, **tail** -- Text processing.
- **grep**, **find** -- Search within files and directories.

### Disabled
- **web_fetch** -- Disabled by default. Enable in openclaw.json for the reading pipeline.

## Vault Structure

```
SecondBrain/
├── SECURITY.md                  ← Security rules (system file)
├── IDENTITY.md                  ← Agent identity (system file)
├── SOUL.md                      ← Agent philosophy (system file)
├── AGENTS.md                    ← Subagent registry (system file)
├── TOOLS.md                     ← This file (system file)
├── HEARTBEAT.md                 ← Routine definitions (system file)
├── USER.md                      ← User profile (system file)
├── MEMORY.md                    ← Persistent memory (system file)
├── 00_Start/                    ← Dashboard hub
│   ├── Inbox/                   ← Unsorted captures, quick notes
│   ├── Goals.md
│   ├── HABITS_TRACKER.md
│   ├── TASKS_DASHBOARD.md
│   ├── MASTER_TODOS_Private.md
│   └── Calendar.md
├── 05_Wisdom/                   ← Distilled principles
│   ├── {Category}/              ← AI_Mastery, Leadership, Product, etc.
│   ├── Quotes/MASTER_QUOTES.md
│   └── WISDOM_INDEX.md
├── 10_Journal/                  ← Daily entries
│   ├── Notes/                   ← Standalone reflections, weekly reviews
│   └── YYYY/MM/YYYY-MM-DD.md
├── 11_Readings/                 ← Book/article/paper notes
│   ├── Tech_AI/, Business_Leadership/, Design_Product/, etc.
│   └── 00_Directories/
├── 12_Podcasts/                 ← Podcast notes
│   └── Snipd/Data/{Show}/{Episode}.md
├── 20_Projects/                 ← Active projects
│   └── {Company}/Notes/, People/, Meetings/, Tech/
├── 30_Life/                     ← Personal life
│   ├── Health/                  ← Health_Notes.md, Meals_Log.md, Fitness_Log.md
│   ├── Finances/
│   ├── Travel/
│   └── Notes/
├── 40_Network/                  ← People and relationships
│   ├── People/Lastname_Firstname.md
│   └── PEOPLE_INDEX.md
├── 90_Archive/                  ← Completed projects, old notes
│   ├── Projects/, Readings/, Areas/
├── 99_Assets/
│   ├── Templates/, Scripts/, Agent_Profiles/
│   ├── Images/, Images_Private/
│   ├── Transcripts/, Attachments/, Processed/
│   └── Logs/
├── memory/                      ← Agent memory
├── agent-profiles/              ← Specialist agent profiles
│   ├── chief-of-staff.md
│   ├── librarian.md
│   ├── scout.md
│   ├── confidante.md
│   ├── strategist.md
│   └── coder.md
└── jobs.json                    ← Scheduled job definitions
```

## Naming Conventions

### Files
- Daily journals: `YYYY-MM-DD.md` (e.g., `2026-03-15.md`)
- Weekly reviews: `YYYY-MM-DD_Weekly_Review.md` (e.g., `2026-03-15_Weekly_Review.md`)
- People: `Lastname_Firstname.md` (e.g., `Kim_Sarah.md`)
- Projects: `Project Name.md` (e.g., `Project Compass.md`)
- Readings: `title-in-kebab-case.md` (e.g., `the-mom-test.md`)
- Wisdom: `concept-name.md` (e.g., `customer-discovery.md`)

### Frontmatter
Every note must have YAML frontmatter:

```yaml
---
title: "Note Title"
date: 2026-03-15
tags: [tag1, tag2]
type: daily | weekly | person | project | reading | wisdom | meeting
status: active | completed | archived
---
```

### Wikilinks
Always use `[[wikilinks]]` for internal references. Use the full file name without extension:
- `[[Kim_Sarah]]`
- `[[Project Compass]]`
- `[[2026-03-15]]`

### Tags
Use lowercase, hyphenated tags:
- `#project`, `#reading`, `#person`, `#health`
- `#unprocessed` (for items awaiting pipeline processing)
- `#follow-up` (for items needing attention)
- `#archived` (for soft-deleted items)

## Git Workflow

After making changes to the vault:

1. Stage changes: `git add -A`
2. Commit with a descriptive message: `git commit -m "journal: add 2026-03-15 daily entry"`
3. Message format: `category: brief description`

Categories: `journal`, `reading`, `wisdom`, `people`, `project`, `health`, `maintenance`, `config`
