# 17 — Dataview Mechanics

Every dashboard in the next chapter is built from about six techniques. They are
short, they are not obvious, and each one exists because a sensor dataset is
never complete, never sorted the way you need it, and never quite the shape the
chart wants.

> A query over machine-written data spends more code tolerating absence than computing results. That ratio is correct.

---

## Prerequisites

Two Obsidian community plugins, and one setting people miss:

| Plugin | Why | Setting |
|---|---|---|
| **Dataview** | The query engine. Provides `dataview` and `dataviewjs` blocks. | Enable **JavaScript Queries** in its settings. Without it, `dataviewjs` blocks render as plain code and nothing works. |
| **Charts** | Renders Chart.js from a query block via `window.renderChart`. | None. |

Everything below uses `dataviewjs` rather than the declarative `dataview`
dialect. The declarative form is better for simple tables over frontmatter; it
cannot read an external file, which is where all the measurements live.

Add a note to the top of every dashboard page saying which plugins it needs.
Future you, opening the vault on a fresh machine and seeing walls of JavaScript,
will be grateful.

```markdown
---
obsidianUIMode: preview
---
# Health Dashboard

> Source: `memory/measurements.jsonl`, written daily by the sync job.
> Requires the **Dataview** plugin with JavaScript Queries enabled, and **Charts**.
```

The `obsidianUIMode: preview` frontmatter opens the page rendered rather than in
source view. On a page that is nothing but query blocks, that is the difference
between a dashboard and a wall of code.

## 1. Loading JSONL

`dv.io.load` reads any file in the vault as a string. JSONL then needs splitting
and parsing per line — with an empty-line guard, because a trailing newline is
normal and `JSON.parse("")` throws.

```javascript
const raw = await dv.io.load("memory/measurements.jsonl");
const days = [];
for (const line of raw.trim().split("\n")) {
  if (line.trim()) days.push(JSON.parse(line));
}
```

If the file may be absent — a fresh vault, a sync that has never run — guard it,
because an unhandled rejection in one block leaves the whole page half-rendered
with no clue why:

```javascript
const raw = await dv.io.load("memory/measurements.jsonl");
if (!raw) { dv.paragraph("No measurements yet. Run the sync."); return; }
```

## 2. De-duplicating by date

An append-only log can hold two lines for one date: a re-run after a manual fix,
a backfill overlapping existing data. Every reader must therefore key by date and
let the later line win.

```javascript
const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
const days = [...byDate.values()].sort((a, b) => a.date < b.date ? -1 : 1);
```

Three lines, and they are the reason the writer needs no locking. The precedence
is deliberate: a later append is a correction, so last-wins is the right rule and
not merely the convenient one.

Note the string comparison in the sort. ISO dates sort correctly as strings, so
there is no reason to construct `Date` objects — and constructing them invites
timezone bugs, where a date parsed as UTC and formatted locally lands on the
previous day.

## 3. Bucketing days into weeks

Weekly aggregates need every date mapped to its week. Compute the Monday of the
week containing a date, and use that Monday as the bucket key.

```javascript
const monday = (iso) => {
  const d = new Date(iso + "T12:00:00");        // midday avoids DST edges
  d.setDate(d.getDate() - (d.getDay() + 6) % 7); // Sunday=0 -> 6, Monday=1 -> 0
  return d.toISOString().slice(0, 10);
};
```

Two details worth the extra characters. Parsing at midday rather than midnight
means a daylight-saving shift cannot move the date across a boundary. The
`(getDay() + 6) % 7` rotation turns JavaScript's Sunday-first week into a
Monday-first one, which is what a weekly training or work total should use.

Bucket keys are ISO dates, so they sort lexically and the last N weeks are a
`slice(-N)`:

```javascript
const weeks = new Map();
for (const day of days) {
  const key = monday(day.date);
  weeks.set(key, (weeks.get(key) || 0) + (day.steps || 0));
}
const recent = [...weeks.keys()].sort().slice(-12);
```

## 4. Tolerating nulls, everywhere

A sensor dataset has holes: the device was not worn, a field was not computed, a
vendor stopped providing something. Every aggregate has to survive that.

```javascript
const avg = (values) => {
  const nums = values.filter((v) => v != null && !Number.isNaN(v));
  return nums.length ? nums.reduce((s, v) => s + v, 0) / nums.length : null;
};

const fmt = (v, digits = 0) =>
  v == null ? "–" : v.toLocaleString(undefined, {
    minimumFractionDigits: digits, maximumFractionDigits: digits,
  });
```

Two conventions that pay off across a whole dashboard:

- `v != null` rather than a truthiness check. `0` is a legitimate measurement —
  zero steps on a day the device was worn is a fact — and `if (v)` discards it.
- An explicit `–` for missing rather than `0` or a blank. A blank cell reads as a
  rendering bug; a zero reads as data. An en dash reads as "not measured", which
  is the truth.

## 5. Spanning gaps in a line chart

By default a line chart breaks at every null, so a week of untracked days turns a
trend into confetti. `spanGaps: true` draws through the hole instead.

```javascript
{
  label: "Resting HR",
  data: days.map((d) => d.resting_hr),
  spanGaps: true,
  pointRadius: 0,
  borderWidth: 2,
}
```

Use it on continuous physiological measures — heart rate, weight, a fitness
estimate — where the underlying quantity existed while you were not measuring it.
Do **not** use it on counts. Bridging a gap in daily steps draws activity that
never happened, and a chart that invents data is worse than one with a hole in
it.

## 6. Deriving what the vendor does not provide

The most useful metrics are usually the ones nobody ships, because they are
ratios of two things the vendor keeps in separate screens. Pace is duration over
distance:

```javascript
const pace = (run) => run.duration_min / run.distance_km;   // minutes per km

const paceLabel = (p) => {
  const m = Math.floor(p);
  return `${m}:${String(Math.round((p - m) * 60)).padStart(2, "0")} min/km`;
};
```

Derive at read time, not at write time. The log holds facts the device reported;
a ratio is an interpretation, and interpretations change. This is the exact
mirror of chapter 16's rule about thresholds, and the distinction is worth being
precise about:

| | Where it lives | Why |
|---|---|---|
| A **judgement** — "was this a good night" | Producer, at write time | It records a decision made under a rule in force at that moment |
| A **derivation** — "what was the pace" | Reader, at read time | It is arithmetic on facts, and recomputing it changes nothing about history |

## 7. Reading tags across notes

Tags live in notes rather than in the log, so they come from Dataview's page
index rather than from a file read. `file.etags` gives every tag on a page,
including nested ones.

```javascript
const since = new Date(); since.setDate(since.getDate() - 30);
const sinceKey = since.toISOString().slice(0, 10);

const counts = {};
for (const page of dv.pages('"10_Journal"')) {
  const name = page.file.name;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(name)) continue;   // dated notes only
  if (name < sinceKey) continue;                     // string compare, again
  for (const tag of page.file.etags ?? []) {
    const m = tag.match(/^#habit\/(.+)$/);
    if (m) counts[m[1].toLowerCase()] = (counts[m[1].toLowerCase()] || 0) + 1;
  }
}
```

Three guards, each earning its line:

- **The filename regex.** A journal directory contains weekly reviews, drafts and
  stray notes. Without the filter, a weekly review's tags count as an extra day.
- **The date-string comparison.** Filtering on the filename avoids parsing
  frontmatter for every page in the folder, which is what makes this fast enough
  to sit on a dashboard.
- **`.toLowerCase()`.** Belt and braces against the one mixed-case tag that will
  eventually get typed on a phone, despite chapter 16's rule.

## Performance, and when it stops being free

These queries re-run every time the page renders. At a few thousand notes and a
few hundred log lines, everything above is instant. What degrades, in order:

| Pattern | Cost | Fix |
|---|---|---|
| `dv.pages('"10_Journal"')` | Scales with notes in that folder | Scope to the narrowest folder; never `dv.pages()` with no argument |
| One `dv.io.load` per block | One file read per block, repeated | Acceptable up to a handful of blocks; beyond that, split the page |
| Parsing the whole log for a 7-day view | Scales with total history | Filter by date immediately after parsing, before any aggregation |
| Many charts on one page | Render time, not query time | Split into several pages by theme |

The pattern that actually bites is a dashboard that grew to twenty blocks, each
loading the same log. Split the page before optimising the queries; two focused
dashboards beat one exhaustive one for reading anyway.

---

**Read next:** [18 — Dashboard Archetypes](./18_dashboard-archetypes.md), which
assembles these techniques into six complete, runnable dashboards.
