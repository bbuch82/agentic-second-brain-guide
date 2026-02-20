#!/usr/bin/env node

/**
 * sync_people_index.js -- Build Your Network Map
 *
 * Scans all contact files in 40_Network/People/ and generates PEOPLE_INDEX.md,
 * a master directory organized by relationship type with quick stats,
 * links, and a "needs attention" section for stale contacts.
 *
 * Usage:
 *   VAULT_PATH=/home/alex/SecondBrain node sync_people_index.js
 *
 * What it does:
 *   1. Reads every .md file in 40_Network/People/ (except PEOPLE_INDEX.md itself)
 *   2. Parses YAML frontmatter for name, role, company, relationship, last-contact
 *   3. Groups contacts by relationship type
 *   4. Identifies stale contacts (>30 days since last interaction)
 *   5. Generates PEOPLE_INDEX.md with tables, stats, and links
 *
 * The script overwrites PEOPLE_INDEX.md on each run (it's auto-generated).
 */

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';
const PEOPLE_DIR = path.join(VAULT_PATH, '40_Network/People');
const INDEX_PATH = path.join(PEOPLE_DIR, 'PEOPLE_INDEX.md');

// Contacts not reached within this many days are flagged
const STALE_THRESHOLD_DAYS = 30;

// Maximum stale contacts to show in the "needs attention" section
const MAX_STALE_DISPLAY = 10;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Parse YAML-ish frontmatter from a Markdown file.
 * Returns an object with key-value pairs.
 *
 * Note: This is a simple parser. It handles flat key: value pairs
 * and basic tag lists. For complex YAML, use a proper parser.
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};

  const meta = {};
  const lines = match[1].split('\n');
  let currentKey = null;

  for (const line of lines) {
    // Simple key: value
    const kvMatch = line.match(/^([a-zA-Z_-]+):\s*(.+)/);
    if (kvMatch) {
      const key = kvMatch[1].trim();
      const value = kvMatch[2].trim().replace(/^["']|["']$/g, '');
      meta[key] = value;
      currentKey = key;
      continue;
    }

    // Array item (for tags, etc.)
    const arrayMatch = line.match(/^\s+-\s+(.+)/);
    if (arrayMatch && currentKey) {
      if (!Array.isArray(meta[currentKey])) {
        // Key exists as empty string from "tags:" line -- convert to array
        if (meta[currentKey] === '') meta[currentKey] = [];
        else meta[currentKey] = [meta[currentKey]];
      }
      meta[currentKey].push(arrayMatch[1].trim());
    }

    // Key with no value (like "tags:")
    const emptyKey = line.match(/^([a-zA-Z_-]+):\s*$/);
    if (emptyKey) {
      currentKey = emptyKey[1].trim();
      meta[currentKey] = '';
    }
  }

  return meta;
}

/**
 * Calculate days between a date string and now.
 * Returns Infinity if the date is invalid or missing.
 */
function daysSince(dateStr) {
  if (!dateStr) return Infinity;
  const date = new Date(dateStr);
  if (isNaN(date.getTime())) return Infinity;
  const now = new Date();
  return Math.floor((now - date) / (1000 * 60 * 60 * 24));
}

/**
 * Find all .md files in a directory (non-recursive).
 */
function findContactFiles(dir) {
  if (!fs.existsSync(dir)) return [];

  return fs.readdirSync(dir)
    .filter(name => name.endsWith('.md') && name !== 'PEOPLE_INDEX.md')
    .map(name => path.join(dir, name));
}

/**
 * Capitalize the first letter of a string.
 */
function capitalize(str) {
  return str.charAt(0).toUpperCase() + str.slice(1);
}

// ---------------------------------------------------------------------------
// Index Builder
// ---------------------------------------------------------------------------

function buildIndex() {
  const files = findContactFiles(PEOPLE_DIR);

  if (files.length === 0) {
    console.log('No contact files found in', PEOPLE_DIR);
    return;
  }

  // Parse all contacts
  const contacts = files.map(file => {
    const content = fs.readFileSync(file, 'utf-8');
    const meta = parseFrontmatter(content);
    const basename = path.basename(file, '.md');

    return {
      file: basename,
      name: meta.name || basename.replace(/_/g, ' '),
      role: meta.role || '',
      company: meta.company || '',
      location: meta.location || '',
      type: meta.relationship || 'uncategorized',
      lastContact: meta['last-contact'] || null,
      daysSinceContact: daysSince(meta['last-contact']),
      birthday: meta.birthday || null,
    };
  });

  // Group by relationship type
  const groups = {};
  for (const contact of contacts) {
    const type = contact.type.toLowerCase();
    if (!groups[type]) groups[type] = [];
    groups[type].push(contact);
  }

  // Sort each group alphabetically by name
  for (const type of Object.keys(groups)) {
    groups[type].sort((a, b) => a.name.localeCompare(b.name));
  }

  // Find stale contacts (contacted but not recently)
  const stale = contacts
    .filter(c => c.daysSinceContact > STALE_THRESHOLD_DAYS && c.daysSinceContact < Infinity)
    .sort((a, b) => b.daysSinceContact - a.daysSinceContact);

  // Find contacts with upcoming birthdays (next 14 days)
  const today = new Date();
  const upcomingBirthdays = contacts.filter(c => {
    if (!c.birthday) return false;
    const bd = new Date(c.birthday);
    const thisYear = new Date(today.getFullYear(), bd.getMonth(), bd.getDate());
    const diff = Math.floor((thisYear - today) / (1000 * 60 * 60 * 24));
    return diff >= 0 && diff <= 14;
  });

  // Define group display order
  const typeOrder = ['colleague', 'friend', 'mentor', 'client', 'family', 'uncategorized'];
  const sortedTypes = Object.keys(groups).sort((a, b) => {
    const ai = typeOrder.indexOf(a);
    const bi = typeOrder.indexOf(b);
    return (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
  });

  // -------------------------------------------------------------------------
  // Build Markdown
  // -------------------------------------------------------------------------

  const date = new Date().toISOString().split('T')[0];

  let md = '';

  // Frontmatter
  md += `---\n`;
  md += `updated: ${date}\n`;
  md += `total_contacts: ${contacts.length}\n`;
  md += `categories: ${Object.keys(groups).length}\n`;
  md += `---\n\n`;

  // Header
  md += `# People Index\n\n`;
  md += `> Auto-generated by \`sync_people_index.js\` on ${date}  \n`;
  md += `> Run \`node 99_Assets/Scripts/sync_people_index.js\` to refresh\n\n`;

  // Stats
  md += `**${contacts.length}** contacts across **${Object.keys(groups).length}** categories`;
  if (stale.length > 0) {
    md += ` | **${stale.length}** need attention`;
  }
  md += `\n\n`;

  // Quick navigation
  md += `## Quick Navigation\n\n`;
  for (const type of sortedTypes) {
    md += `- [${capitalize(type)}s](#${type}s-${groups[type].length}) (${groups[type].length})\n`;
  }
  md += `\n`;

  // Upcoming birthdays
  if (upcomingBirthdays.length > 0) {
    md += `## Upcoming Birthdays\n\n`;
    for (const c of upcomingBirthdays) {
      const bd = new Date(c.birthday);
      const month = bd.toLocaleString('en', { month: 'long' });
      const day = bd.getDate();
      md += `- **${month} ${day}** -- [[${c.file}|${c.name}]]`;
      if (c.role) md += ` (${c.role})`;
      md += `\n`;
    }
    md += `\n`;
  }

  // Needs attention section
  if (stale.length > 0) {
    md += `## Needs Attention\n\n`;
    md += `Contacts not reached in over ${STALE_THRESHOLD_DAYS} days:\n\n`;
    md += `| Name | Days Silent | Last Contact | Role | Company |\n`;
    md += `|------|-------------|--------------|------|--------|\n`;
    for (const c of stale.slice(0, MAX_STALE_DISPLAY)) {
      md += `| [[${c.file}\\|${c.name}]] | ${c.daysSinceContact}d | ${c.lastContact} | ${c.role} | ${c.company} |\n`;
    }
    if (stale.length > MAX_STALE_DISPLAY) {
      md += `\n*...and ${stale.length - MAX_STALE_DISPLAY} more.*\n`;
    }
    md += `\n`;
  }

  // Contact groups
  for (const type of sortedTypes) {
    const group = groups[type];
    md += `## ${capitalize(type)}s (${group.length})\n\n`;
    md += `| Name | Role | Company | Location | Last Contact |\n`;
    md += `|------|------|---------|----------|--------------|\n`;
    for (const c of group) {
      const lastStr = c.lastContact || 'N/A';
      md += `| [[${c.file}\\|${c.name}]] | ${c.role} | ${c.company} | ${c.location} | ${lastStr} |\n`;
    }
    md += `\n`;
  }

  // Footer
  md += `---\n\n`;
  md += `*This file is auto-generated. Do not edit manually -- your changes will be overwritten.*\n`;

  // Write the index
  fs.writeFileSync(INDEX_PATH, md, 'utf-8');

  // Summary
  console.log('People Index updated successfully.');
  console.log(`  Total contacts:     ${contacts.length}`);
  console.log(`  Categories:         ${Object.keys(groups).length}`);
  console.log(`  Need attention:     ${stale.length}`);
  console.log(`  Upcoming birthdays: ${upcomingBirthdays.length}`);
  console.log(`  Written to:         ${INDEX_PATH}`);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

console.log('sync_people_index.js -- Build Your Network Map');
console.log('================================================');
console.log(`Vault:  ${VAULT_PATH}`);
console.log(`People: ${PEOPLE_DIR}`);
console.log('');

buildIndex();
