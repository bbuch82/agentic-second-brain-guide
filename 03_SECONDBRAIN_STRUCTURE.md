# Chapter 03: SecondBrain Structure

[← OpenClaw Install](./02_OPENCLAW_INSTALL.md) | [Home](./README.md) | [Next: System Files →](./04_SYSTEM_FILES.md)

---

> **Goal:** Design a vault folder hierarchy that scales from day one to decade ten.

A SecondBrain is only as good as its structure. Too flat and you drown in files. Too nested and you never find anything. The architecture below is inspired by Tiago Forte's PARA method (Projects, Areas, Resources, Archives) but adapted for an AI agent that reads, writes, and cross-links files on your behalf.

The key insight: your agent needs predictable paths. When a cron job writes a daily journal entry, it must know exactly where to put it. When the Librarian files a reading note, it must follow a naming convention every other agent can search. Structure is not bureaucracy -- it is the API between you and your AI.

---

## Table of Contents

- [The Folder Tree](#the-folder-tree)
- [Folder-by-Folder Breakdown](#folder-by-folder-breakdown)
- [File Naming Conventions](#file-naming-conventions)
- [Journal Structure](#journal-structure)
- [Knowledge Flow](#knowledge-flow)
- [Tag Taxonomy](#tag-taxonomy)
- [Creating the Structure](#creating-the-structure)

---

## The Folder Tree

```
/opt/SecondBrain/
├── IDENTITY.md                    ← Agent persona (root-level system files)
├── SOUL.md                        ← Philosophy & values
├── SECURITY.md                    ← Data protection rules
├── AGENTS.md                      ← Agent registry
├── TOOLS.md                       ← Tool inventory
├── HEARTBEAT.md                   ← Background pulse checklist
├── USER.md                        ← User profile
├── MEMORY.md                      ← Brain index & context pointers
│
├── 00_Start/                      ← Dashboard & hub
│   ├── Inbox/                     ← Quick capture landing zone
│   ├── Goals.md                   ← Quarterly OKRs & personal goals
│   ├── HABITS_TRACKER.md          ← Monthly habit matrix
│   ├── TASKS_DASHBOARD.md         ← Obsidian Tasks aggregation view
│   ├── MASTER_TODOS_Private.md    ← Private task list
│   └── Calendar.md                ← Schedule & upcoming events
│
├── 05_Wisdom/                     ← Distilled principles & mental models
│   ├── Leadership/
│   ├── Product/
│   ├── Psychology/
│   ├── Economics/
│   ├── AI_Mastery/
│   ├── Architecture/
│   ├── Science/
│   ├── Quotes/
│   │   └── MASTER_QUOTES.md
│   └── WISDOM_INDEX.md
│
├── 10_Journal/                    ← Daily entries
│   ├── Notes/                     ← Standalone reflections
│   └── 2026/
│       └── 02/
│           ├── 2026-02-18.md
│           ├── 2026-02-19.md
│           └── 2026-02-20.md
│
├── 11_Readings/                   ← Articles, books, papers
│   ├── Tech_AI/
│   ├── Business_Leadership/
│   ├── Design_Product/
│   ├── Lifestyle_Health/
│   ├── Marketing/
│   ├── Science_Nature/
│   └── 00_Directories/           ← Curated link collections
│
├── 12_Podcasts/                   ← Podcast highlights
│   └── Snipd/
│       └── Data/
│           ├── Founders/
│           ├── Lex_Fridman_Podcast/
│           └── The_Knowledge_Project/
│
├── 20_Projects/                   ← Active projects with deadlines
│   ├── Wanderly/
│   │   ├── Notes/
│   │   ├── People/
│   │   ├── Meetings/
│   │   └── Tech/
│   └── Side_Projects/
│       └── Kitchen_Renovation/
│
├── 30_Life/                       ← Personal life (no end date)
│   ├── Health/
│   │   ├── Health_Notes.md
│   │   ├── Meals_Log.md
│   │   ├── Fitness_Log.md
│   │   └── Body_Stats.md
│   ├── Finances/
│   ├── Travel/
│   ├── Intimate/
│   ├── Lists/
│   ├── Recipes/
│   └── Notes/
│
├── 40_Network/                    ← People & relationships
│   ├── People/
│   │   ├── Kim_Sarah.md
│   │   ├── Weber_Marcus.md
│   │   └── Patel_Priya.md
│   ├── Groups/
│   └── PEOPLE_INDEX.md
│
├── 90_Archive/                    ← Completed & inactive items
│   ├── Projects/
│   ├── Readings/
│   └── Areas/
│
└── 99_Assets/                     ← Templates, scripts, media
    ├── Templates/
    │   └── Daily_Journal.md
    ├── Scripts/
    │   ├── wisdomizer.js
    │   ├── sync_people_index.js
    │   └── sync_habits.js
    ├── Agent_Profiles/
    │   ├── CHIEF_OF_STAFF.md
    │   ├── LIBRARIAN.md
    │   ├── SCOUT.md
    │   ├── CONFIDANTE.md
    │   ├── STRATEGIST.md
    │   └── CODER.md
    ├── Images/
    ├── Images_Private/
    ├── Transcripts/
    └── Attachments/
```

---

## Folder-by-Folder Breakdown

### System Files (Root Level)

**Purpose:** The agent's DNA. These files live at the vault root so OpenClaw loads them automatically as system prompt context.

You write these once and update them occasionally. The agent reads them constantly but rarely modifies them (except `MEMORY.md`, which it updates actively).

Files: `IDENTITY.md`, `SOUL.md`, `SECURITY.md`, `AGENTS.md`, `TOOLS.md`, `HEARTBEAT.md`, `USER.md`, `MEMORY.md`

See [Chapter 04: System Files](./04_SYSTEM_FILES.md) for the complete breakdown.

---

### 00_Start

**Purpose:** Your command center. The first thing you see when you open Obsidian.

| File | Purpose |
|------|---------|
| `Goals.md` | Quarterly OKRs with progress tracking, linked to related files |
| `HABITS_TRACKER.md` | Monthly grid of daily habits (emoji columns, x/empty tracking) |
| `TASKS_DASHBOARD.md` | Obsidian Tasks plugin queries across the entire vault |
| `MASTER_TODOS_Private.md` | Private task list not exposed to shared dashboards |
| `Calendar.md` | Schedule overview, meeting links, and upcoming events |
| `Inbox/` | Landing zone for quick captures before they're filed properly |

The `Inbox/` folder is the only place where unstructured content is acceptable. The agent checks it regularly and files items into their proper folders.

---

### 05_Wisdom

**Purpose:** Distilled principles, mental models, and frameworks extracted from your readings, experiences, and conversations.

This is the most valuable folder in your vault. While `11_Readings/` captures what you read, `05_Wisdom/` captures what you _learned_. Each wisdom entry is a single, actionable principle.

**Structure:** Organized by category subfolder, with a central `WISDOM_INDEX.md` that links to everything.

**Example** (`05_Wisdom/Leadership/Reference_Class_Forecasting.md`):

```markdown
# Reference-Class Forecasting
#wisdom #strategy #decision-making

## Principle
The most reliable way to predict the outcome of a project is to look at
how similar projects actually performed, rather than building estimates
from the inside out.

## Key Disciplines
1. **Outside View First:** Find 5-10 comparable projects and check their
   actual timelines, budgets, and outcomes.
2. **Anchor on Base Rates:** Your project is not special. The base rate
   of similar projects is a better predictor than your gut feeling.
3. **Adjust for Uniqueness Last:** Only after anchoring on the outside
   view, adjust for truly unique factors.

---
**Source:** [[11_Readings/Business_Leadership/2026-02-18_How_Big_Things_Get_Done]]
```

The Librarian agent runs the [Wisdomizer script](./09_SCRIPTS_AND_TOOLS.md) nightly, scanning unprocessed readings for wisdom candidates.

---

### 10_Journal

**Purpose:** A chronological record of your days.

Structure: `10_Journal/YYYY/MM/YYYY-MM-DD.md`

Journal entries are created automatically via cron jobs. Each entry follows this format:

**Template** (`99_Assets/Templates/Daily_Journal.md`):

```markdown
# {{date}}
#journal #daily #work #private #health

## Fokus & Stimmung
-

## Ernaehrung & Health
- **Total kcal:**
- **Mahlzeiten:**
- **Bewertung:**

## Recap & Entscheidungen
-

## Highlights & Tomorrow
-
```

**Filled example** (`10_Journal/2026/02/2026-02-20.md`):

```markdown
# 2026-02-20
#journal #daily #work #private #health

## Fokus & Stimmung
- **Thema:** Atlas Demo Day & Collaborative Filtering Breakthrough.
- **Vibe:** Energized. Demo went great, Sarah backed me up strongly.

## Ernaehrung & Health
- **Total kcal:** ~2100 kcal
- **Mahlzeiten:**
  - Breakfast: Porridge (oats, banana, walnuts, honey) (550)
  - Lunch: Pad Kra Pao + Thai iced tea @ Khao San (750)
  - Snack: Apple + almonds (200)
  - Dinner: Emma's mushroom risotto, salad (600)
- **Bewertung:** 🟢 (Balanced, no junk, good hydration)

## Recap & Entscheidungen
- **Product:** Atlas demo to stakeholders -- crushed it. [[Kim_Sarah|Sarah]]
  framed it as "reducing decision fatigue" instead of "ML recommendations."
- **Insight:** Dwell time as implicit signal for travel recommendations.
- **Social:** [[Park_David|David Park]] showed interest in AI-native travel.
  Follow up within 48h.

## Highlights & Tomorrow
- **Highlights:** Atlas Demo (standing ovation from the CRO).
- **Tomorrow:** Follow up David Park, start collaborative filtering doc.
- **Todo:** Block Lily's school concert next Thursday 4pm.
```

**Weekly reviews** are standalone notes in `10_Journal/Notes/`.

---

### 11_Readings

**Purpose:** Structured notes from articles, books, and papers.

Naming: `YYYY-MM-DD_Title.md` (date = when you processed it)

Organized by topic subfolders: `Tech_AI/`, `Business_Leadership/`, `Design_Product/`, `Lifestyle_Health/`, `Marketing/`, `Science_Nature/`

**Example** (`11_Readings/Business_Leadership/2026-02-18_How_Big_Things_Get_Done.md`):

```markdown
---
title: "How Big Things Get Done"
date: 2026-02-18
source: https://www.amazon.com/dp/0593239512
tags: [strategy, decision-making, project-management, leadership]
---

# How Big Things Get Done

*From Bent Flyvbjerg & Dan Gardner*

## The Planning Fallacy at Scale

Most big projects fail -- not because of bad luck, but because of bad
planning. Flyvbjerg's research across thousands of megaprojects shows
a consistent pattern: optimistic timelines, underestimated costs.

## Reference-Class Forecasting

Instead of building bottom-up estimates, look at how similar projects
actually performed. 9 out of 10 megaprojects exceed their budget.

## Key Insight

The single best predictor of project success is whether the project was
planned with reference-class forecasting and modular design.

## Application
- Apply reference-class forecasting to [[Atlas_AI_Initiative]] timelines
- Discuss modularity with [[Weber_Marcus|Marcus]] for the search rewrite
```

Reading notes use YAML frontmatter (`title`, `date`, `source`, `tags` array). The Librarian creates them when you drop a URL or book title in Telegram.

---

### 12_Podcasts

**Purpose:** Podcast highlights, primarily from Snipd auto-imports.

Structure: `12_Podcasts/Snipd/Data/{Show_Name}/{Episode_Title}.md`

Files are auto-generated by the Snipd plugin with rich frontmatter (episode metadata, guest list, mentioned books, snip counts). Each file contains timestamped audio clips with embedded players.

You can enrich these manually or let the Librarian extract wisdom from the highlights.

---

### 20_Projects

**Purpose:** Active initiatives with a clear goal and deadline.

Projects use subfolders for their supporting documents:

```
20_Projects/
├── Wanderly/
│   ├── Atlas_AI_Initiative.md    ← Project brief
│   ├── Project_Compass.md        ← Core product
│   ├── Notes/                    ← Working documents
│   ├── People/                   ← Team profiles & 360 reviews
│   ├── Meetings/                 ← Meeting notes
│   └── Tech/                     ← Technical specs
└── Side_Projects/
    └── Kitchen_Renovation/
```

A project file includes: objective, key results, timeline, stakeholders, status updates, and links to related people and meetings.

When a project finishes, move it to `90_Archive/Projects/`.

---

### 30_Life

**Purpose:** Personal life -- ongoing areas that have no end date.

Life areas are different from projects. "Launch Atlas" is a project (it ends). "Stay healthy" is a life area (it never ends). Family contacts live in `40_Network/`, not here.

```
30_Life/
├── Health/
│   ├── Health_Notes.md           ← Symptoms, doctor visits, medications
│   ├── Meals_Log.md              ← Daily calorie tracking table
│   ├── Fitness_Log.md            ← Workout tracking
│   └── Body_Stats.md             ← Weight progression
├── Finances/
├── Travel/
├── Intimate/
├── Lists/
├── Recipes/
└── Notes/
```

**Health_Notes.md example:**

```markdown
# Health Notes
_General health observations, symptoms, doctor visits, medications._

---

### 2026-02-20
- **Status:** Good (8/10). High energy day.
- **Note:** 20-min walk after lunch helped with afternoon dip.

### 2026-02-18
- **Status:** Slight cold (6/10).
- **Symptoms:** Mild sore throat, stuffy nose.
- **Todo:** Schedule annual checkup.
```

**Meals_Log.md** uses a table format with calorie tracking and traffic-light ratings:

```markdown
# Meals Log
#health #nutrition

_Daily calorie tracking for [[Goals|Goal: Get fitter & lose 10kg]]_

**Calorie target:** ~1800-2000 kcal/day

---

## 2026-02

| Datum     | Zeit  | Mahlzeit  | Was                              | kcal     | Rating |
| --------- | ----- | --------- | -------------------------------- | -------- | ------ |
| 20.02     | 07:15 | Breakfast | Porridge (banana, walnuts)       | 550      | 🟢     |
| 20.02     | 12:30 | Lunch     | Pad Kra Pao @ Khao San          | 750      | 🟡     |
| 20.02     | 15:30 | Snack     | Apple + almonds                  | 200      | 🟢     |
| 20.02     | 19:30 | Dinner    | Mushroom risotto, salad          | 600      | 🟢     |
| **20.02** |       |           | **TOTAL**                        | **2100** | 🟢     |
```

---

### 40_Network

**Purpose:** Contact profiles for everyone important in your life.

Naming: `Lastname_Firstname.md` in `40_Network/People/`

**Example** (`40_Network/People/Kim_Sarah.md`):

```markdown
# Sarah Kim
#person #work #colleague #index

**Role:** CTO
**Relation:** Co-Founder / Close Collaborator

---

## Akten / Dokumente
- [[20_Projects/Wanderly/People/Kim_Sarah/Performance_Review_Q1|Q1 Review]]

---

## Stammdaten & Notes
- Ex-Google, Ex-Stripe. Distributed Systems.
- Prefers async communication (docs over meetings).
- Morning person -- best meetings before 11am.
- Daughter Mia (3). Favorite cafe: The Barn.

## Work Docs
- [[20_Projects/Wanderly/People/Kim_Sarah]]
```

The `PEOPLE_INDEX.md` is auto-generated by `sync_people_index.js` -- a markdown table of all contacts with their tags.

The Chief of Staff agent surfaces follow-up reminders: "You haven't talked to Marcus in 3 weeks."

---

### 90_Archive

**Purpose:** Completed projects and outdated material.

Nothing is deleted. When a project finishes or material becomes irrelevant, it moves here. The Archive mirrors the active folder structure:

```
90_Archive/
├── Projects/
├── Readings/
└── Areas/
```

All agents can still search archived content.

---

### 99_Assets

**Purpose:** Templates, automation scripts, agent profiles, and media.

```
99_Assets/
├── Templates/
│   └── Daily_Journal.md          ← Journal template (used by cron job)
├── Scripts/
│   ├── wisdomizer.js             ← Extract wisdom from unprocessed readings
│   ├── sync_people_index.js      ← Rebuild PEOPLE_INDEX.md
│   ├── sync_habits.js            ← Parse journal habits into tracker grid
│   └── garmin_sync.py            ← Import Garmin health data
├── Agent_Profiles/
│   ├── CHIEF_OF_STAFF.md
│   ├── LIBRARIAN.md
│   ├── SCOUT.md
│   ├── CONFIDANTE.md
│   ├── STRATEGIST.md
│   └── CODER.md
├── Images/
├── Images_Private/               ← Private/sensitive images
├── Transcripts/                  ← Meeting and call transcripts
├── Attachments/                  ← Misc file attachments
└── Processed/                    ← Staging area for processed files
```

See [Chapter 09: Scripts & Tools](./09_SCRIPTS_AND_TOOLS.md) for script details.

---

## File Naming Conventions

| Folder | Convention | Example |
|--------|-----------|---------|
| Journal | `YYYY-MM-DD.md` | `2026-02-20.md` |
| Readings | `YYYY-MM-DD_Title.md` | `2026-02-18_How_Big_Things_Get_Done.md` |
| People | `Lastname_Firstname.md` | `Kim_Sarah.md` |
| Projects | `Project_Name.md` or subfolder | `Atlas_AI_Initiative.md` |
| Wisdom | `Principle_Title.md` | `Reference_Class_Forecasting.md` |
| Podcasts | `Episode_Title.md` (auto-generated) | `_374 Rare Jeff Bezos Interview.md` |

**Rules:**
- Use underscores, not spaces (some tools struggle with spaces in paths)
- Capitalize each word in the filename
- Dates always in ISO 8601: `YYYY-MM-DD`
- Keep filenames under 60 characters

---

## Journal Structure

The journal uses a year/month hierarchy to prevent any single folder from becoming unmanageable:

```
10_Journal/
├── Notes/                    ← Standalone reflections (not date-bound)
├── 2025/
│   ├── 11/
│   │   ├── 2025-11-01.md
│   │   └── ...
│   └── 12/
│       ├── 2025-12-01.md
│       └── ...
└── 2026/
    ├── 01/
    │   ├── 2026-01-01.md
    │   └── ...
    └── 02/
        ├── 2026-02-01.md
        └── 2026-02-20.md
```

After one year you will have ~365 daily entries. The nested structure keeps each folder to about 30-35 files -- comfortable to browse in Obsidian or the terminal.

---

## Knowledge Flow

Information flows through your vault in a predictable pipeline:

```
Input                    Processing               Storage
─────                    ──────────               ───────

Book/Article/URL    ──►  11_Readings/         ──►  Structured note
                              │
                              ▼
                         05_Wisdom/           ──►  Distilled principle
                              │
                              ▼
                    Cross-links to 20_Projects/,
                    30_Life/, 40_Network/

Podcast highlight   ──►  12_Podcasts/         ──►  Snipd auto-import
                              │
                              ▼
                         05_Wisdom/           ──►  Extracted insight

Daily activity      ──►  10_Journal/          ──►  Daily entry
                              │
                              ▼
                    Updates to 30_Life/Health/
                    (meals, habits, health notes)

Quick capture       ──►  00_Start/Inbox/      ──►  Triage by agent
                              │
                              ▼
                    Filed to correct folder
```

The key principle: **information enters once and flows outward**. You never manually copy information between files. The agents handle cross-linking, extraction, and updates.

---

## Tag Taxonomy

Tags provide a secondary organization layer on top of folders. Keep the taxonomy small and consistent.

### Context Tags (on every file)

| Tag | Meaning |
|-----|---------|
| `#work` | Professional life |
| `#private` | Personal, family, non-work |
| `#health` | Physical or mental health |
| `#journal` | Daily journal entry |
| `#wisdom` | Extracted principle |

### Type Tags

| Tag | Meaning |
|-----|---------|
| `#person` | Contact profile |
| `#meeting` | Meeting notes |
| `#idea` | Something to explore later |
| `#article` | Unprocessed reading in queue |
| `#todo` | Task (used by Obsidian Tasks plugin) |

### Status Tags

| Tag | Meaning |
|-----|---------|
| `#index` | Indexed / fully processed |
| `#wisdomized` | Wisdom extracted from this reading |
| `#someday` | Not now, but maybe later |

### Habit Tags (in journal entries)

Used by `sync_habits.js` to build the monthly tracker grid:

| Tag | Meaning |
|-----|---------|
| `#habit/healthy` | Ate healthy |
| `#habit/workout` | Worked out |
| `#habit/running` | Running |
| `#habit/sleep` | Slept well |
| `#habit/reading` | Read 30+ minutes |
| `#habit/meditate` | Meditation |
| `#habit/deepwork` | 2+ hours deep work |
| `#habit/social` | Social activity |
| `#habit/family` | Quality family time |

**Rules:**
- Tags go right after the `# Title` line (not at the bottom)
- Readings use YAML frontmatter `tags: [array]` instead
- The `#todo` tag is required for Obsidian Tasks plugin queries
- The Chief of Staff enforces consistent tagging on people profiles

---

## Creating the Structure

Run this on your server to create the full folder tree:

```bash
cd /opt/SecondBrain

# Dashboard
mkdir -p 00_Start/Inbox

# Knowledge
mkdir -p 05_Wisdom/{Leadership,Product,Psychology,Economics,AI_Mastery,Architecture,Science,Quotes}

# Journal
mkdir -p 10_Journal/{Notes,2026/02}

# Input
mkdir -p 11_Readings/{Tech_AI,Business_Leadership,Design_Product,Lifestyle_Health,Marketing,Science_Nature,00_Directories}
mkdir -p 12_Podcasts/Snipd/Data

# Active
mkdir -p 20_Projects
mkdir -p 30_Life/{Health,Finances,Travel,Intimate,Lists,Recipes,Notes}
mkdir -p 40_Network/{People,Groups}

# Archive & Assets
mkdir -p 90_Archive/{Projects,Readings,Areas}
mkdir -p 99_Assets/{Templates,Scripts,Agent_Profiles,Images,Images_Private,Transcripts,Attachments,Processed}

# Set ownership
chown -R openclaw:openclaw /opt/SecondBrain

# Initial commit
git add -A
git commit -m "Initialize SecondBrain vault structure"
```

Verify:

```bash
find /opt/SecondBrain -type d | sort
```

Your vault skeleton is ready. Next, we fill the root with the system files that give your agent its personality.

---

## What We Built

```
Root level   → System files (IDENTITY, SOUL, SECURITY, AGENTS, TOOLS, ...)
00_Start     → Dashboard hub (Goals, Habits Tracker, Tasks, Inbox)
05_Wisdom    → Distilled principles by category + WISDOM_INDEX.md
10_Journal   → Daily entries (YYYY/MM/YYYY-MM-DD.md) + standalone notes
11_Readings  → Articles & books by topic (YAML frontmatter)
12_Podcasts  → Podcast highlights (Snipd auto-imports)
20_Projects  → Active work with subfolders (Notes, People, Meetings, Tech)
30_Life      → Personal life (Health, Finances, Travel, Intimate, Lists, Recipes, Notes)
40_Network   → People profiles (Lastname_Firstname.md) + PEOPLE_INDEX.md
90_Archive   → Completed/inactive items
99_Assets    → Templates, Scripts, Agent Profiles, Images
```

---

[← OpenClaw Install](./02_OPENCLAW_INSTALL.md) | [Home](./README.md) | [Next: System Files →](./04_SYSTEM_FILES.md)
