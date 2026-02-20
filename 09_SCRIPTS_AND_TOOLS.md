# Chapter 9: Scripts and Tools

← [Previous: Subagent System](./08_SUBAGENT_SYSTEM.md) | [Home](./README.md) | [Next: Daily Workflow](./10_DAILY_WORKFLOW.md) →

---

These scripts handle the automated maintenance tasks.

The agents handle the heavy lifting -- parsing messages, extracting wisdom, managing your journal. But some tasks need specialized logic that runs on a schedule or on demand. That's where custom scripts come in: lightweight Node.js utilities that live in your vault and extend what your agents can do.

This chapter walks through three battle-tested scripts and shows you how to add your own.

---

## Table of Contents

- [Overview](#overview)
- [wisdomizer.js -- Extract Wisdom from Reading Notes](#wisdomizer-js----extract-wisdom-from-reading-notes)
- [sync_people_index.js -- Build Your Network Map](#sync_people_index-js----build-your-network-map)
- [sync_habits.js -- Visualize Your Habit Grid](#sync_habits-js----visualize-your-habit-grid)
- [Adding Your Own Scripts](#adding-your-own-scripts)
- [Running Scripts on a Schedule](#running-scripts-on-a-schedule)

---

## Overview

All scripts live in one place:

```
SecondBrain/
└── 99_Assets/
    └── Scripts/
        ├── wisdomizer.js
        ├── sync_people_index.js
        └── sync_habits.js
```

They share a few conventions:

- **Pure Node.js** -- no external dependencies beyond `fs` and `path` (uses `fs.readdirSync` with manual filtering for file discovery)
- **Vault-aware** -- they read and write Markdown files directly in your Obsidian vault
- **Idempotent** -- safe to run multiple times; they won't duplicate entries
- **Logged** -- each run prints what it did so you can debug

The scripts use environment variables for configuration:

```bash
export VAULT_PATH="/home/alex/SecondBrain"
export SCRIPTS_PATH="$VAULT_PATH/99_Assets/Scripts"
```

---

## wisdomizer.js -- Extract Wisdom from Reading Notes

The Wisdomizer scans your `11_Readings/` folder for reading notes that haven't been processed yet, extracts key insights, and creates individual wisdom entries in `05_Wisdom/`.

### What It Does

1. Finds all `.md` files in `11_Readings/` that lack a `wisdomized: true` tag
2. Parses highlighted passages (lines starting with `==` or inside `> [!quote]` callouts)
3. Creates one wisdom entry per highlight in `05_Wisdom/`
4. Marks the source file as processed

### The Script

See the full implementation: [examples/scripts/wisdomizer.js](./examples/scripts/wisdomizer.js)

Here's the core logic:

```javascript
const fs = require('fs');
const path = require('path');

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';
const RESOURCES_DIR = path.join(VAULT_PATH, '11_Readings');
const WISDOM_DIR = path.join(VAULT_PATH, '05_Wisdom');

function findFilesRecursive(dir, ext) {
  let results = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results = results.concat(findFilesRecursive(fullPath, ext));
    } else if (entry.name.endsWith(ext)) {
      results.push(fullPath);
    }
  }
  return results;
}

function findUnprocessedNotes() {
  const files = findFilesRecursive(RESOURCES_DIR, '.md');
  return files.filter(file => {
    const content = fs.readFileSync(file, 'utf-8');
    return !content.includes('wisdomized: true');
  });
}

function extractHighlights(content) {
  const highlights = [];

  // Match ==highlighted text==
  const inlinePattern = /==(.*?)==/g;
  let match;
  while ((match = inlinePattern.exec(content)) !== null) {
    highlights.push(match[1].trim());
  }

  // Match > [!quote] callout blocks
  const lines = content.split('\n');
  let inQuote = false;
  let quoteBuffer = '';

  for (const line of lines) {
    if (line.startsWith('> [!quote]')) {
      inQuote = true;
      quoteBuffer = '';
    } else if (inQuote && line.startsWith('> ')) {
      quoteBuffer += line.slice(2) + ' ';
    } else if (inQuote) {
      if (quoteBuffer.trim()) highlights.push(quoteBuffer.trim());
      inQuote = false;
      quoteBuffer = '';
    }
  }

  if (inQuote && quoteBuffer.trim()) highlights.push(quoteBuffer.trim());
  return highlights;
}

function createWisdomEntry(highlight, sourceFile, index) {
  const sourceName = path.basename(sourceFile, '.md');
  const date = new Date().toISOString().split('T')[0];
  const slug = sourceName.replace(/\s+/g, '_').toLowerCase();
  const filename = `${date}_${slug}_${index}.md`;
  const filepath = path.join(WISDOM_DIR, filename);

  if (fs.existsSync(filepath)) return null; // Idempotent

  const content = `---
source: "[[${sourceName}]]"
extracted: ${date}
tags:
  - wisdom
  - pending-review
---

# Wisdom: ${sourceName}

> ${highlight}

## My Take

_Review this wisdom nugget and add your interpretation._

## Action Items

- [ ] Reflect on this insight
- [ ] Connect to existing knowledge
- [ ] Apply in practice
`;

  fs.writeFileSync(filepath, content);
  return filename;
}

function markAsProcessed(filePath) {
  let content = fs.readFileSync(filePath, 'utf-8');
  if (content.startsWith('---')) {
    content = content.replace(/^---\n/, '---\nwisdomized: true\n');
  } else {
    content = `---\nwisdomized: true\n---\n\n${content}`;
  }
  fs.writeFileSync(filePath, content);
}

// Main
const unprocessed = findUnprocessedNotes();
console.log(`Found ${unprocessed.length} unprocessed reading notes.`);

let totalWisdom = 0;
for (const file of unprocessed) {
  const content = fs.readFileSync(file, 'utf-8');
  const highlights = extractHighlights(content);
  console.log(`  ${path.basename(file)}: ${highlights.length} highlights`);

  highlights.forEach((h, i) => {
    const created = createWisdomEntry(h, file, i + 1);
    if (created) {
      console.log(`    -> Created ${created}`);
      totalWisdom++;
    }
  });

  markAsProcessed(file);
}

console.log(`\nDone. Created ${totalWisdom} new wisdom entries.`);
```

### Example Run

```bash
$ node 99_Assets/Scripts/wisdomizer.js
Found 3 unprocessed reading notes.
  Deep_Work_Cal_Newport.md: 5 highlights
    -> Created 2026-02-20_deep_work_cal_newport_1.md
    -> Created 2026-02-20_deep_work_cal_newport_2.md
    -> Created 2026-02-20_deep_work_cal_newport_3.md
    -> Created 2026-02-20_deep_work_cal_newport_4.md
    -> Created 2026-02-20_deep_work_cal_newport_5.md
  Thinking_in_Systems_Meadows.md: 2 highlights
    -> Created 2026-02-20_thinking_in_systems_meadows_1.md
    -> Created 2026-02-20_thinking_in_systems_meadows_2.md
  Atomic_Habits_James_Clear.md: 3 highlights
    -> Created 2026-02-20_atomic_habits_james_clear_1.md
    -> Created 2026-02-20_atomic_habits_james_clear_2.md
    -> Created 2026-02-20_atomic_habits_james_clear_3.md

Done. Created 10 new wisdom entries.
```

---

## sync_people_index.js -- Build Your Network Map

This script scans all contact files in `40_Network/People/` and generates a single `PEOPLE_INDEX.md` -- a master directory of everyone in your network, organized by relationship type, with quick stats and links.

### What It Does

1. Reads every `.md` file in `40_Network/People/`
2. Parses YAML frontmatter for name, role, company, relationship type, and last-contact date
3. Groups contacts by relationship type (colleague, friend, mentor, etc.)
4. Generates `PEOPLE_INDEX.md` with links, stats, and a "needs attention" section for stale contacts

### The Script

See the full implementation: [examples/scripts/sync_people_index.js](./examples/scripts/sync_people_index.js)

Core logic:

```javascript
const fs = require('fs');
const path = require('path');

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';
const PEOPLE_DIR = path.join(VAULT_PATH, '40_Network', 'People');
const INDEX_PATH = path.join(VAULT_PATH, '40_Network', 'PEOPLE_INDEX.md');

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};

  const meta = {};
  match[1].split('\n').forEach(line => {
    const [key, ...rest] = line.split(':');
    if (key && rest.length) {
      meta[key.trim()] = rest.join(':').trim().replace(/^["']|["']$/g, '');
    }
  });
  return meta;
}

function daysSince(dateStr) {
  if (!dateStr) return Infinity;
  const d = new Date(dateStr);
  const now = new Date();
  return Math.floor((now - d) / (1000 * 60 * 60 * 24));
}

function buildIndex() {
  const files = fs.readdirSync(PEOPLE_DIR)
    .filter(f => f.endsWith('.md') && f !== 'PEOPLE_INDEX.md')
    .map(f => path.join(PEOPLE_DIR, f));

  const contacts = files.map(file => {
    const content = fs.readFileSync(file, 'utf-8');
    const meta = parseFrontmatter(content);
    return {
      file: path.basename(file, '.md'),
      name: meta.name || path.basename(file, '.md'),
      role: meta.role || '',
      company: meta.company || '',
      type: meta.relationship || 'uncategorized',
      lastContact: meta['last-contact'] || null,
      daysSinceContact: daysSince(meta['last-contact']),
    };
  });

  // Group by relationship type
  const groups = {};
  for (const c of contacts) {
    if (!groups[c.type]) groups[c.type] = [];
    groups[c.type].push(c);
  }

  // Sort each group alphabetically
  for (const type of Object.keys(groups)) {
    groups[type].sort((a, b) => a.name.localeCompare(b.name));
  }

  // Stale contacts (>30 days since last contact)
  const stale = contacts
    .filter(c => c.daysSinceContact > 30 && c.daysSinceContact < Infinity)
    .sort((a, b) => b.daysSinceContact - a.daysSinceContact);

  // Build markdown
  const date = new Date().toISOString().split('T')[0];
  let md = `---\nupdated: ${date}\ntotal_contacts: ${contacts.length}\n---\n\n`;
  md += `# People Index\n\n`;
  md += `> Auto-generated by \`sync_people_index.js\` on ${date}\n\n`;
  md += `**${contacts.length}** contacts across **${Object.keys(groups).length}** categories\n\n`;

  // Needs attention section
  if (stale.length > 0) {
    md += `## Needs Attention\n\n`;
    md += `These contacts haven't been reached in over 30 days:\n\n`;
    md += `| Name | Days Silent | Last Contact | Role |\n`;
    md += `|------|-------------|--------------|------|\n`;
    for (const c of stale.slice(0, 10)) {
      md += `| [[${c.file}\\|${c.name}]] | ${c.daysSinceContact}d | ${c.lastContact} | ${c.role} |\n`;
    }
    md += `\n`;
  }

  // Contact groups
  const typeOrder = ['colleague', 'friend', 'mentor', 'client', 'family', 'uncategorized'];
  const sortedTypes = Object.keys(groups).sort((a, b) => {
    const ai = typeOrder.indexOf(a);
    const bi = typeOrder.indexOf(b);
    return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
  });

  for (const type of sortedTypes) {
    const icon = { colleague: 'briefcase', friend: 'heart', mentor: 'star',
                   client: 'handshake', family: 'home' }[type] || 'user';
    md += `## ${type.charAt(0).toUpperCase() + type.slice(1)}s (${groups[type].length})\n\n`;
    md += `| Name | Role | Company | Last Contact |\n`;
    md += `|------|------|---------|-------------|\n`;
    for (const c of groups[type]) {
      md += `| [[${c.file}\\|${c.name}]] | ${c.role} | ${c.company} | ${c.lastContact || 'N/A'} |\n`;
    }
    md += `\n`;
  }

  fs.writeFileSync(INDEX_PATH, md);
  console.log(`People Index updated: ${contacts.length} contacts, ${stale.length} need attention.`);
}

buildIndex();
```

### Example Output

The generated `PEOPLE_INDEX.md` looks like this in Obsidian:

```markdown
## Needs Attention

| Name | Days Silent | Last Contact | Role |
|------|-------------|--------------|------|
| [[Weber_Marcus|Marcus Weber]] | 45d | 2026-01-06 | Lead Engineer |
| [[Park_David|David Park]] | 38d | 2026-01-13 | Angel Investor |

## Colleagues (12)

| Name | Role | Company | Last Contact |
|------|------|---------|-------------|
| [[Weber_Marcus|Marcus Weber]] | Lead Engineer | Wanderly | 2026-01-06 |
| [[Patel_Priya|Priya Patel]] | Lead Designer | Wanderly | 2026-02-18 |
| [[Kim_Sarah|Sarah Kim]] | CTO | Wanderly | 2026-02-20 |
```

---

## sync_habits.js -- Visualize Your Habit Grid

This script reads habit checkboxes from your journal files and builds a monthly tracker table -- showing completion status per day for each habit.

### What It Does

1. Scans `10_Journal/` for daily entries from the current month
2. Parses habit checkboxes (e.g., `- [x] Meditation`, `- [ ] Exercise`)
3. Builds a monthly table showing completion per day
4. Writes `00_Start/HABITS_TRACKER.md`

### The Script

See the full implementation: [examples/scripts/sync_habits.js](./examples/scripts/sync_habits.js)

Core logic:

```javascript
const fs = require('fs');
const path = require('path');

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';
const JOURNAL_DIR = path.join(VAULT_PATH, '10_Journal');
const GRID_PATH = path.join(VAULT_PATH, '00_Start', 'HABITS_TRACKER.md');

function parseHabits(content) {
  const habits = {};
  const lines = content.split('\n');
  let inHabitSection = false;

  for (const line of lines) {
    if (line.match(/^#{1,3}\s.*[Hh]abit/)) {
      inHabitSection = true;
      continue;
    }
    if (inHabitSection && line.match(/^#{1,3}\s/)) {
      inHabitSection = false;
      continue;
    }
    if (inHabitSection) {
      const checked = line.match(/^- \[x\]\s+(.+)/i);
      const unchecked = line.match(/^- \[ \]\s+(.+)/i);
      if (checked) habits[checked[1].trim()] = true;
      if (unchecked) habits[unchecked[1].trim()] = false;
    }
  }
  return habits;
}

function buildGrid(monthData, habits, year, month) {
  const daysInMonth = new Date(year, month, 0).getDate();
  const monthName = new Date(year, month - 1).toLocaleString('en', { month: 'long' });

  let grid = `## ${monthName} ${year}\n\n`;
  grid += `| Habit |`;
  for (let d = 1; d <= daysInMonth; d++) {
    grid += ` ${String(d).padStart(2)} |`;
  }
  grid += '\n|-------|';
  for (let d = 1; d <= daysInMonth; d++) {
    grid += '----|';
  }
  grid += '\n';

  for (const habit of habits) {
    grid += `| ${habit.substring(0, 12).padEnd(12)} |`;
    for (let d = 1; d <= daysInMonth; d++) {
      const dateKey = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const val = monthData[dateKey]?.[habit];
      if (val === true) grid += '  x |';        // Done
      else if (val === false) grid += '    |';   // Open (empty cell)
      else grid += '    |';                       // No data
    }
    grid += '\n';
  }

  return grid;
}

function main() {
  const now = new Date();
  const year = now.getFullYear();
  const month = now.getMonth() + 1;

  // Scan journal files for the current month
  const prefix = `${year}-${String(month).padStart(2, '0')}-`;
  const files = fs.readdirSync(JOURNAL_DIR)
    .filter(f => f.startsWith(prefix) && f.endsWith('.md'))
    .map(f => path.join(JOURNAL_DIR, f));

  const monthData = {};
  const allHabits = new Set();

  for (const file of files) {
    const dateKey = path.basename(file, '.md'); // e.g., 2026-02-15
    const content = fs.readFileSync(file, 'utf-8');
    const habits = parseHabits(content);
    monthData[dateKey] = habits;
    Object.keys(habits).forEach(h => allHabits.add(h));
  }

  const habitList = [...allHabits].sort();
  console.log(`Parsed ${files.length} journal entries, tracking ${habitList.length} habits.`);

  // Calculate streaks
  const streaks = {};
  for (const habit of habitList) {
    let current = 0;
    let max = 0;
    const sortedDates = Object.keys(monthData).sort();
    for (const date of sortedDates) {
      if (monthData[date]?.[habit] === true) {
        current++;
        max = Math.max(max, current);
      } else {
        current = 0;
      }
    }
    streaks[habit] = { current, max };
  }

  // Build output
  const date = new Date().toISOString().split('T')[0];
  let md = `---\nupdated: ${date}\n---\n\n`;
  md += `# Habit Tracker\n\n`;
  md += `> Auto-generated by \`sync_habits.js\` on ${date}\n\n`;

  // Streak summary
  md += `## Current Streaks\n\n`;
  md += `| Habit | Current Streak | Best Streak | Rate |\n`;
  md += `|-------|---------------|-------------|------|\n`;
  for (const habit of habitList) {
    const total = Object.values(monthData).filter(d => d[habit] === true).length;
    const tracked = Object.values(monthData).filter(d => habit in d).length;
    const rate = tracked > 0 ? Math.round((total / tracked) * 100) : 0;
    md += `| ${habit} | ${streaks[habit].current}d | ${streaks[habit].max}d | ${rate}% |\n`;
  }
  md += `\n`;

  // Visual grid
  md += buildGrid(monthData, habitList, year, month);

  md += `\n---\n\n`;
  md += `*Legend: \`x\` = done, empty = open/no entry*\n`;

  fs.writeFileSync(GRID_PATH, md);
  console.log(`Habit grid written to ${GRID_PATH}`);
}

main();
```

### What the Grid Looks Like

In Obsidian (with a monospace font), you get a monthly tracker:

```
## Current Streaks

| Habit        | Current Streak | Best Streak | Rate |
|--------------|---------------|-------------|------|
| Meditation   | 5d            | 12d         | 78%  |
| Exercise     | 2d            | 8d          | 65%  |
| Reading      | 5d            | 14d         | 85%  |
| Deep Work    | 3d            | 6d          | 72%  |
| Journaling   | 18d           | 18d         | 100% |
```

The monthly table uses `x` for completed days and empty cells for open/missed days, matching the vault's HABITS_TRACKER format.

---

## Adding Your Own Scripts

Adding new scripts is straightforward. Here's the pattern:

### 1. Create the Script

Place your script in `99_Assets/Scripts/`:

```bash
touch /home/alex/SecondBrain/99_Assets/Scripts/my_new_script.js
```

### 2. Follow the Convention

Every script should follow this template:

```javascript
const fs = require('fs');
const path = require('path');

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';

// Your paths
const INPUT_DIR = path.join(VAULT_PATH, 'your/input/folder');
const OUTPUT_PATH = path.join(VAULT_PATH, 'your/output/file.md');

function main() {
  console.log('Starting my_new_script...');

  // 1. Read input files
  // 2. Process data
  // 3. Write output
  // 4. Log what you did

  console.log('Done.');
}

main();
```

### 3. Test Locally

```bash
# Set your vault path
export VAULT_PATH="/home/alex/SecondBrain"

# Run it
node 99_Assets/Scripts/my_new_script.js
```

### 4. Script Ideas

Here are some scripts that Alex has on his roadmap:

| Script | Purpose |
|--------|---------|
| `sync_projects.js` | Aggregate todos across all project files into a master PROJECT_STATUS.md |
| `weekly_digest.js` | Summarize the week's journal entries, wisdom, and contacts into a weekly report |
| `tag_cleanup.js` | Find orphan tags and inconsistent naming across the vault |
| `link_checker.js` | Detect broken internal wiki-links |
| `reading_stats.js` | Track books/articles read per month with completion rates |

---

## Running Scripts on a Schedule

You can run these scripts automatically using cron on your server, or let your Claude agent trigger them.

### Option A: Cron Jobs

```bash
# Edit crontab
crontab -e

# Run wisdomizer every night at 2am
0 2 * * * cd /home/alex/SecondBrain && node 99_Assets/Scripts/wisdomizer.js >> /var/log/secondbrain/wisdomizer.log 2>&1

# Rebuild people index every Monday at 6am
0 6 * * 1 cd /home/alex/SecondBrain && node 99_Assets/Scripts/sync_people_index.js >> /var/log/secondbrain/people.log 2>&1

# Update habit grid every night at 11pm
0 23 * * * cd /home/alex/SecondBrain && node 99_Assets/Scripts/sync_habits.js >> /var/log/secondbrain/habits.log 2>&1
```

### Option B: Agent-Triggered

Add a tool to your Claude agent that can invoke scripts:

```json
{
  "type": "function",
  "function": {
    "name": "run_vault_script",
    "description": "Run a maintenance script in the SecondBrain vault",
    "parameters": {
      "type": "object",
      "properties": {
        "script_name": {
          "type": "string",
          "enum": ["wisdomizer.js", "sync_people_index.js", "sync_habits.js"],
          "description": "Which script to run"
        }
      },
      "required": ["script_name"]
    }
  }
}
```

Then your agent can run scripts in response to natural language:

> **You:** "Update my people index"
> **Agent:** Running sync_people_index.js... Done. 47 contacts indexed, 3 need attention.

### Option C: Systemd Timer (Recommended for Servers)

More reliable than cron, with built-in logging:

```bash
# /etc/systemd/system/secondbrain-wisdomizer.service
[Unit]
Description=SecondBrain Wisdomizer
After=network.target

[Service]
Type=oneshot
User=alex
WorkingDirectory=/home/alex/SecondBrain
ExecStart=/usr/bin/node 99_Assets/Scripts/wisdomizer.js
Environment=VAULT_PATH=/home/alex/SecondBrain

[Install]
WantedBy=multi-user.target
```

```bash
# /etc/systemd/system/secondbrain-wisdomizer.timer
[Unit]
Description=Run Wisdomizer nightly

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# Enable the timer
sudo systemctl enable --now secondbrain-wisdomizer.timer

# Check status
systemctl list-timers | grep secondbrain
```

---

These scripts cover the core maintenance tasks. Your Second Brain is a Markdown vault with a well-defined structure -- any script that reads and writes `.md` files can extend it. Start with these three, then build your own as you discover patterns in how you use your vault.

---

← [Previous: Subagent System](./08_SUBAGENT_SYSTEM.md) | [Home](./README.md) | [Next: Daily Workflow](./10_DAILY_WORKFLOW.md) →
