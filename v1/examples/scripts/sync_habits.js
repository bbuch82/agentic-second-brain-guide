#!/usr/bin/env node

/**
 * sync_habits.js -- Visualize Your Habit Grid
 *
 * Parses habit checkboxes from daily journal entries and builds a visual
 * contribution-style grid showing streaks and consistency.
 *
 * Usage:
 *   VAULT_PATH=/home/alex/SecondBrain node sync_habits.js
 *   VAULT_PATH=/home/alex/SecondBrain MONTH=2026-01 node sync_habits.js
 *
 * What it does:
 *   1. Scans 10_Journal/YYYY/MM/ for daily entries in the target month
 *   2. Parses habit checkboxes under ## Habits sections
 *   3. Calculates streaks, completion rates, and consistency
 *   4. Writes a visual grid to 00_Start/HABITS_TRACKER.md
 *
 * Journal format expected:
 *   ## Habits
 *   - [x] Meditation
 *   - [ ] Exercise
 *   - [x] Reading (30 min)
 */

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';
const JOURNAL_DIR = path.join(VAULT_PATH, '10_Journal');
const GRID_PATH = path.join(VAULT_PATH, '00_Start', 'HABITS_TRACKER.md');

// Allow overriding the target month (format: YYYY-MM)
const TARGET_MONTH = process.env.MONTH || null;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Get the year and month to process.
 * Uses TARGET_MONTH env var if set, otherwise defaults to current month.
 */
function getTargetMonth() {
  if (TARGET_MONTH) {
    const [year, month] = TARGET_MONTH.split('-').map(Number);
    return { year, month };
  }
  const now = new Date();
  return { year: now.getFullYear(), month: now.getMonth() + 1 };
}

/**
 * Get the number of days in a given month.
 */
function daysInMonth(year, month) {
  return new Date(year, month, 0).getDate();
}

/**
 * Find journal files matching a YYYY-MM pattern.
 * Expected path: 10_Journal/YYYY/MM/YYYY-MM-DD.md
 */
function findJournalFiles(dir, year, month) {
  const monthDir = path.join(dir, String(year), String(month).padStart(2, '0'));
  if (!fs.existsSync(monthDir)) return [];

  const prefix = `${year}-${String(month).padStart(2, '0')}-`;

  return fs.readdirSync(monthDir)
    .filter(name => name.startsWith(prefix) && name.endsWith('.md'))
    .map(name => path.join(monthDir, name))
    .sort();
}

/**
 * Parse habit checkboxes from a journal entry.
 *
 * Looks for a section starting with a heading containing "Habit" (case-insensitive),
 * then reads checkbox lines until the next heading or end of section.
 *
 * Returns: { "Meditation": true, "Exercise": false, ... }
 */
function parseHabits(content) {
  const habits = {};
  const lines = content.split('\n');
  let inHabitSection = false;

  for (const line of lines) {
    // Detect habit section heading (## Habits, ### Daily Habits, etc.)
    if (line.match(/^#{1,3}\s+.*[Hh]abit/)) {
      inHabitSection = true;
      continue;
    }

    // End of habit section when we hit another heading
    if (inHabitSection && line.match(/^#{1,3}\s+/) && !line.match(/[Hh]abit/)) {
      inHabitSection = false;
      continue;
    }

    if (!inHabitSection) continue;

    // Parse checked habits: - [x] Habit Name or - [X] Habit Name
    const checked = line.match(/^-\s+\[x\]\s+(.+)/i);
    if (checked) {
      // Strip parenthetical notes like "(30 min)" for cleaner habit names
      const name = checked[1].trim().replace(/\s*\(.*?\)\s*$/, '').trim();
      habits[name] = true;
      continue;
    }

    // Parse unchecked habits: - [ ] Habit Name
    const unchecked = line.match(/^-\s+\[\s\]\s+(.+)/);
    if (unchecked) {
      const name = unchecked[1].trim().replace(/\s*\(.*?\)\s*$/, '').trim();
      habits[name] = false;
    }
  }

  return habits;
}

/**
 * Calculate streak information for a habit across sorted dates.
 */
function calculateStreaks(monthData, habit, sortedDates) {
  let currentStreak = 0;
  let maxStreak = 0;
  let tempStreak = 0;

  for (const date of sortedDates) {
    if (monthData[date]?.[habit] === true) {
      tempStreak++;
      maxStreak = Math.max(maxStreak, tempStreak);
    } else {
      tempStreak = 0;
    }
  }

  // Current streak = streak ending on the most recent tracked day
  currentStreak = tempStreak;

  return { current: currentStreak, max: maxStreak };
}

/**
 * Build a visual grid for a month.
 */
function buildVisualGrid(monthData, habitList, year, month) {
  const days = daysInMonth(year, month);
  const monthName = new Date(year, month - 1).toLocaleString('en', { month: 'long' });

  let grid = `## ${monthName} ${year} -- Daily View\n\n`;

  // Header row with day numbers
  const padName = 14;
  grid += `| ${'Habit'.padEnd(padName)} |`;
  for (let d = 1; d <= days; d++) {
    grid += ` ${String(d).padStart(2)} |`;
  }
  grid += '\n';

  // Separator
  grid += `|${'-'.repeat(padName + 2)}|`;
  for (let d = 1; d <= days; d++) {
    grid += '----|';
  }
  grid += '\n';

  // One row per habit
  for (const habit of habitList) {
    const displayName = habit.length > padName
      ? habit.substring(0, padName - 1) + '.'
      : habit.padEnd(padName);

    grid += `| ${displayName} |`;

    for (let d = 1; d <= days; d++) {
      const dateKey = `${year}-${String(month).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const value = monthData[dateKey]?.[habit];

      if (value === true) {
        grid += '  x |';     // Completed
      } else if (value === false) {
        grid += '    |';     // Missed (empty cell)
      } else {
        grid += '    |';     // No data (future or no entry)
      }
    }
    grid += '\n';
  }

  return grid;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  const { year, month } = getTargetMonth();
  const monthName = new Date(year, month - 1).toLocaleString('en', { month: 'long' });

  console.log('sync_habits.js -- Visualize Your Habit Grid');
  console.log('================================================');
  console.log(`Vault:   ${VAULT_PATH}`);
  console.log(`Journal: ${JOURNAL_DIR}`);
  console.log(`Target:  ${monthName} ${year}`);
  console.log('');

  // Find and parse journal files
  const files = findJournalFiles(JOURNAL_DIR, year, month);
  console.log(`Found ${files.length} journal entries for ${monthName} ${year}.`);

  if (files.length === 0) {
    console.log('No journal entries found. Nothing to do.');
    return;
  }

  const monthData = {};
  const allHabits = new Set();

  for (const file of files) {
    const dateKey = path.basename(file, '.md'); // e.g., 2026-02-15
    const content = fs.readFileSync(file, 'utf-8');
    const habits = parseHabits(content);

    if (Object.keys(habits).length > 0) {
      monthData[dateKey] = habits;
      Object.keys(habits).forEach(h => allHabits.add(h));
    }
  }

  const habitList = [...allHabits].sort();
  const sortedDates = Object.keys(monthData).sort();

  console.log(`Tracking ${habitList.length} habits: ${habitList.join(', ')}`);
  console.log(`Days with habit data: ${sortedDates.length}`);
  console.log('');

  if (habitList.length === 0) {
    console.log('No habits found in journal entries. Make sure your journals have a ## Habits section.');
    return;
  }

  // Calculate stats for each habit
  const stats = {};
  for (const habit of habitList) {
    const completed = Object.values(monthData).filter(d => d[habit] === true).length;
    const tracked = Object.values(monthData).filter(d => habit in d).length;
    const rate = tracked > 0 ? Math.round((completed / tracked) * 100) : 0;
    const streaks = calculateStreaks(monthData, habit, sortedDates);

    stats[habit] = { completed, tracked, rate, ...streaks };
  }

  // -------------------------------------------------------------------------
  // Build Output
  // -------------------------------------------------------------------------

  const date = new Date().toISOString().split('T')[0];

  let md = '';

  // Frontmatter
  md += `---\n`;
  md += `updated: ${date}\n`;
  md += `month: ${year}-${String(month).padStart(2, '0')}\n`;
  md += `habits_tracked: ${habitList.length}\n`;
  md += `---\n\n`;

  // Header
  md += `# Habit Tracker -- ${monthName} ${year}\n\n`;
  md += `> Auto-generated by \`sync_habits.js\` on ${date}  \n`;
  md += `> Run \`node 99_Assets/Scripts/sync_habits.js\` to refresh\n\n`;

  // Summary stats
  const avgRate = habitList.length > 0
    ? Math.round(habitList.reduce((sum, h) => sum + stats[h].rate, 0) / habitList.length)
    : 0;
  md += `**Overall completion rate: ${avgRate}%** across ${habitList.length} habits over ${sortedDates.length} days\n\n`;

  // Streak table
  md += `## Streaks and Consistency\n\n`;
  md += `| Habit | Completed | Tracked | Rate | Current Streak | Best Streak |\n`;
  md += `|-------|-----------|---------|------|----------------|-------------|\n`;

  for (const habit of habitList) {
    const s = stats[habit];
    const rateBar = s.rate >= 80 ? '+++' : s.rate >= 50 ? '++' : s.rate >= 25 ? '+' : '';
    md += `| ${habit} | ${s.completed}/${s.tracked} | ${s.tracked}d | ${s.rate}% ${rateBar} | ${s.current}d | ${s.max}d |\n`;
  }
  md += `\n`;

  // Highlights
  const bestHabit = habitList.reduce((best, h) => stats[h].rate > stats[best].rate ? h : best, habitList[0]);
  const worstHabit = habitList.reduce((worst, h) => stats[h].rate < stats[worst].rate ? h : worst, habitList[0]);
  const longestStreak = habitList.reduce((best, h) => stats[h].max > stats[best].max ? h : best, habitList[0]);

  md += `### Highlights\n\n`;
  md += `- **Best habit:** ${bestHabit} (${stats[bestHabit].rate}% completion)\n`;
  md += `- **Needs work:** ${worstHabit} (${stats[worstHabit].rate}% completion)\n`;
  md += `- **Longest streak:** ${longestStreak} (${stats[longestStreak].max} days)\n\n`;

  // Visual grid
  md += buildVisualGrid(monthData, habitList, year, month);
  md += `\n`;

  // Legend
  md += `*Legend: x = done, empty = open/missed, blank = no entry*\n\n`;

  // Tips based on data
  md += `## Insights\n\n`;

  for (const habit of habitList) {
    const s = stats[habit];
    if (s.rate < 50 && s.tracked >= 5) {
      md += `- **${habit}** is below 50%. Consider: Is the bar too high? Can you make it smaller or easier?\n`;
    }
    if (s.current >= 5) {
      md += `- **${habit}** has a ${s.current}-day streak going. Keep it alive!\n`;
    }
    if (s.max > 0 && s.current === 0) {
      md += `- **${habit}** streak was broken. Your best was ${s.max} days -- time to start a new one.\n`;
    }
  }

  md += `\n---\n\n`;
  md += `*This file is auto-generated. Do not edit manually -- your changes will be overwritten.*\n`;

  // Write output
  fs.writeFileSync(GRID_PATH, md, 'utf-8');

  console.log('Habit grid written successfully.');
  console.log(`  Output: ${GRID_PATH}`);
  console.log(`  Average completion rate: ${avgRate}%`);
  console.log(`  Best habit: ${bestHabit} (${stats[bestHabit].rate}%)`);
  console.log(`  Longest streak: ${longestStreak} (${stats[longestStreak].max}d)`);
}

main();
