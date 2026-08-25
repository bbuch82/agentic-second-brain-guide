#!/usr/bin/env node

/**
 * wisdomizer.js -- Extract Wisdom from Reading Notes
 *
 * Scans 11_Readings/ for unprocessed reading notes, extracts highlighted
 * passages and quote callouts, and creates individual wisdom entries in
 * 05_Wisdom/.
 *
 * Usage:
 *   VAULT_PATH=/home/alex/SecondBrain node wisdomizer.js
 *
 * What it does:
 *   1. Finds .md files in 11_Readings/ without `wisdomized: true` in frontmatter
 *   2. Extracts ==highlighted text== and > [!quote] callout blocks
 *   3. Creates a wisdom entry for each highlight in 05_Wisdom/
 *   4. Marks the source file as processed (adds wisdomized: true to frontmatter)
 *
 * The script is idempotent -- running it multiple times won't create duplicates.
 */

const fs = require('fs');
const path = require('path');

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

const VAULT_PATH = process.env.VAULT_PATH || '/home/alex/SecondBrain';
const RESOURCES_DIR = path.join(VAULT_PATH, '11_Readings');
const WISDOM_DIR = path.join(VAULT_PATH, '05_Wisdom');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Recursively find all .md files in a directory.
 */
function findMarkdownFiles(dir) {
  const results = [];
  if (!fs.existsSync(dir)) return results;

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...findMarkdownFiles(fullPath));
    } else if (entry.isFile() && entry.name.endsWith('.md')) {
      results.push(fullPath);
    }
  }
  return results;
}

/**
 * Check if a file has already been processed by looking for
 * `wisdomized: true` in its YAML frontmatter.
 */
function isProcessed(content) {
  const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (!fmMatch) return false;
  return fmMatch[1].includes('wisdomized: true');
}

/**
 * Parse the title from frontmatter or first heading.
 */
function parseTitle(content) {
  // Try frontmatter title
  const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (fmMatch) {
    const titleLine = fmMatch[1].split('\n').find(l => l.startsWith('title:'));
    if (titleLine) {
      return titleLine.replace(/^title:\s*["']?/, '').replace(/["']?\s*$/, '');
    }
  }
  // Fall back to first heading
  const headingMatch = content.match(/^#\s+(.+)$/m);
  return headingMatch ? headingMatch[1].trim() : 'Untitled';
}

/**
 * Parse tags from frontmatter.
 */
function parseTags(content) {
  const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
  if (!fmMatch) return [];

  const tags = [];
  const lines = fmMatch[1].split('\n');
  let inTags = false;

  for (const line of lines) {
    if (line.match(/^tags:\s*$/)) {
      inTags = true;
      continue;
    }
    if (inTags && line.match(/^\s+-\s+/)) {
      tags.push(line.replace(/^\s+-\s+/, '').trim());
    } else if (inTags && !line.match(/^\s/)) {
      inTags = false;
    }
  }
  return tags;
}

/**
 * Extract highlighted passages from a reading note.
 *
 * Supports two formats:
 *   - Inline highlights: ==some text==
 *   - Quote callouts:   > [!quote]\n> text here
 */
function extractHighlights(content) {
  const highlights = [];

  // 1. Inline highlights: ==text==
  const inlinePattern = /==(.*?)==/gs;
  let match;
  while ((match = inlinePattern.exec(content)) !== null) {
    const text = match[1].trim();
    if (text.length > 10) { // Skip very short highlights
      highlights.push(text);
    }
  }

  // 2. Quote callout blocks: > [!quote]
  const lines = content.split('\n');
  let inQuote = false;
  let quoteBuffer = '';

  for (const line of lines) {
    if (line.match(/^>\s*\[!quote\]/i)) {
      inQuote = true;
      quoteBuffer = '';
      continue;
    }
    if (inQuote && line.startsWith('> ')) {
      quoteBuffer += line.slice(2).trim() + ' ';
    } else if (inQuote) {
      if (quoteBuffer.trim().length > 10) {
        highlights.push(quoteBuffer.trim());
      }
      inQuote = false;
      quoteBuffer = '';
    }
  }

  // Flush remaining quote buffer
  if (inQuote && quoteBuffer.trim().length > 10) {
    highlights.push(quoteBuffer.trim());
  }

  return highlights;
}

/**
 * Create a wisdom entry file in 05_Wisdom/.
 * Returns the filename if created, null if it already exists.
 */
function createWisdomEntry(highlight, sourceFile, index, sourceTags) {
  const sourceName = path.basename(sourceFile, '.md');
  const date = new Date().toISOString().split('T')[0];
  const slug = sourceName
    .replace(/[^a-zA-Z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .toLowerCase()
    .substring(0, 50);
  const filename = `${date}_${slug}_${index}.md`;
  const filepath = path.join(WISDOM_DIR, filename);

  // Idempotent: don't overwrite existing files
  if (fs.existsSync(filepath)) {
    return null;
  }

  // Build tags list: inherit source tags + add wisdom-specific ones
  const tags = ['wisdom', 'pending-review', ...sourceTags.filter(t => t !== 'wisdom')];
  const tagsYaml = tags.map(t => `  - ${t}`).join('\n');

  // Truncate highlight for the heading if it's very long
  const headingText = highlight.length > 80
    ? highlight.substring(0, 77) + '...'
    : highlight;

  const content = `---
source: "[[${sourceName}]]"
extracted: ${date}
tags:
${tagsYaml}
---

# ${headingText}

> ${highlight}

## My Take

_Review this wisdom nugget and add your interpretation._

## Connections

- Source: [[${sourceName}]]

## Action Items

- [ ] Reflect on this insight
- [ ] Connect to existing knowledge
- [ ] Apply in practice
`;

  fs.writeFileSync(filepath, content, 'utf-8');
  return filename;
}

/**
 * Mark a source file as processed by adding `wisdomized: true` to frontmatter.
 */
function markAsProcessed(filePath) {
  let content = fs.readFileSync(filePath, 'utf-8');

  if (content.startsWith('---')) {
    // Insert wisdomized: true after the opening ---
    content = content.replace(/^---\n/, '---\nwisdomized: true\n');
  } else {
    // No frontmatter -- add one
    content = `---\nwisdomized: true\n---\n\n${content}`;
  }

  fs.writeFileSync(filePath, content, 'utf-8');
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

function main() {
  console.log('Wisdomizer -- Extract Wisdom from Reading Notes');
  console.log('================================================');
  console.log(`Vault:     ${VAULT_PATH}`);
  console.log(`Resources: ${RESOURCES_DIR}`);
  console.log(`Wisdom:    ${WISDOM_DIR}`);
  console.log('');

  // Ensure output directory exists
  if (!fs.existsSync(WISDOM_DIR)) {
    fs.mkdirSync(WISDOM_DIR, { recursive: true });
    console.log(`Created wisdom directory: ${WISDOM_DIR}`);
  }

  // Find unprocessed reading notes
  const allFiles = findMarkdownFiles(RESOURCES_DIR);
  const unprocessed = allFiles.filter(file => {
    const content = fs.readFileSync(file, 'utf-8');
    return !isProcessed(content);
  });

  console.log(`Found ${allFiles.length} total reading notes.`);
  console.log(`Found ${unprocessed.length} unprocessed reading notes.`);
  console.log('');

  if (unprocessed.length === 0) {
    console.log('Nothing to process. All reading notes are up to date.');
    return;
  }

  let totalCreated = 0;
  let totalSkipped = 0;

  for (const file of unprocessed) {
    const content = fs.readFileSync(file, 'utf-8');
    const title = parseTitle(content);
    const tags = parseTags(content);
    const highlights = extractHighlights(content);

    console.log(`Processing: ${title}`);
    console.log(`  File: ${path.basename(file)}`);
    console.log(`  Highlights found: ${highlights.length}`);

    if (highlights.length === 0) {
      console.log('  No highlights to extract. Marking as processed.');
      markAsProcessed(file);
      continue;
    }

    for (let i = 0; i < highlights.length; i++) {
      const created = createWisdomEntry(highlights[i], file, i + 1, tags);
      if (created) {
        console.log(`  -> Created: ${created}`);
        totalCreated++;
      } else {
        console.log(`  -> Skipped (already exists): entry ${i + 1}`);
        totalSkipped++;
      }
    }

    markAsProcessed(file);
    console.log(`  Marked as processed.`);
    console.log('');
  }

  console.log('================================================');
  console.log(`Done.`);
  console.log(`  New wisdom entries created: ${totalCreated}`);
  console.log(`  Skipped (already existed):  ${totalSkipped}`);
  console.log(`  Source files processed:      ${unprocessed.length}`);
}

main();
