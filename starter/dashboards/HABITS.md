---
obsidianUIMode: preview
title: "Habits"
type: reference
---
# Habits

> Aggregated from `#habit/*` tags in dated notes under `10_Journal/`.
> Requires the **Dataview** plugin with JavaScript Queries enabled, and **Charts**.
> Edit the `HABITS` list below to your own vocabulary — see chapter 16.

## Streaks

```dataviewjs
const HABITS = ["movement", "sleep", "reading", "focus", "nutrition", "screenfree"];
const DAYS = 365;

const since = new Date(); since.setDate(since.getDate() - DAYS);
const sinceKey = since.toISOString().slice(0, 10);

const byDay = new Map();
for (const page of dv.pages('"10_Journal"')) {
  const name = page.file.name;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(name) || name < sinceKey) continue;
  const set = new Set();
  for (const tag of page.file.etags ?? []) {
    const m = tag.match(/^#habit\/(.+)$/);
    if (m) set.add(m[1].toLowerCase());
  }
  byDay.set(name, set);
}

// Today is excluded: an unfinished day would reset every streak each morning.
const streak = (habit) => {
  let n = 0;
  const d = new Date(); d.setDate(d.getDate() - 1);
  for (;;) {
    const key = d.toISOString().slice(0, 10);
    if (key < sinceKey || !(byDay.get(key)?.has(habit))) break;
    n += 1;
    d.setDate(d.getDate() - 1);
  }
  return n;
};

const total = (habit) => [...byDay.values()].filter((s) => s.has(habit)).length;

dv.table(
  ["Habit", "Current streak", `Days in ${DAYS}`, "Rate"],
  HABITS.map((h) => [
    h,
    `${streak(h)} d`,
    total(h),
    // Denominator is days with a note, not the calendar: a week off should not
    // count against you.
    `${Math.round(total(h) / Math.max(byDay.size, 1) * 100)} %`,
  ]),
);
```

## Thirty-day frequency

```dataviewjs
const HABITS = ["movement", "sleep", "reading", "focus", "nutrition", "screenfree"];
const since = new Date(); since.setDate(since.getDate() - 30);
const sinceKey = since.toISOString().slice(0, 10);

const counts = Object.fromEntries(HABITS.map((h) => [h, 0]));
for (const page of dv.pages('"10_Journal"')) {
  const name = page.file.name;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(name) || name < sinceKey) continue;
  for (const tag of page.file.etags ?? []) {
    const m = tag.match(/^#habit\/(.+)$/);
    if (m && counts[m[1].toLowerCase()] !== undefined) counts[m[1].toLowerCase()] += 1;
  }
}

const sorted = HABITS.map((h) => [h, counts[h]]).sort((a, b) => b[1] - a[1]);
window.renderChart({
  type: "bar",
  data: {
    labels: sorted.map((r) => r[0]),
    datasets: [{ label: "Days in the last 30", data: sorted.map((r) => r[1]), backgroundColor: "#16a34a" }],
  },
  options: {
    indexAxis: "y",
    plugins: { legend: { display: false } },
    scales: { x: { beginAtZero: true, max: 30, ticks: { stepSize: 5 } } },
  },
}, this.container);
```

## Trend, 7-day rolling window

A raw yes/no series is a picket fence. A rolling count over a window is a line you can
read a direction from. See chapter 18, archetype 7.

```dataviewjs
const HABITS = ["movement", "reading", "focus", "nutrition"];
const COLORS = ["#16a34a", "#8b5cf6", "#f59e0b", "#06b6d4"];
const DAYS = 90;
const WINDOW = 7;

// Load WINDOW extra days: otherwise the first week is computed from a partial
// window and slopes up from zero, which looks exactly like a real improvement.
const since = new Date(); since.setDate(since.getDate() - DAYS - WINDOW);
const sinceKey = since.toISOString().slice(0, 10);

const byDay = {};
for (const page of dv.pages('"10_Journal"')) {
  const name = page.file.name;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(name) || name < sinceKey) continue;
  const set = new Set();
  for (const tag of page.file.etags ?? []) {
    const m = tag.match(/^#habit\/(.+)$/);
    if (m) set.add(m[1].toLowerCase());
  }
  byDay[name] = set;
}

const labels = [];
const series = HABITS.map(() => []);
for (let i = DAYS - 1; i >= 0; i--) {
  const d = new Date(); d.setDate(d.getDate() - i);
  labels.push(d.toISOString().slice(0, 10).slice(5));
  for (let h = 0; h < HABITS.length; h++) {
    let count = 0;
    for (let j = 0; j < WINDOW; j++) {
      const w = new Date(d); w.setDate(w.getDate() - j);
      if (byDay[w.toISOString().slice(0, 10)]?.has(HABITS[h])) count += 1;
    }
    series[h].push(count);
  }
}

window.renderChart({
  type: "line",
  data: {
    labels,
    datasets: HABITS.map((h, i) => ({
      label: h, data: series[i],
      borderColor: COLORS[i], backgroundColor: COLORS[i],
      tension: 0.25, pointRadius: 0, borderWidth: 2,
    })),
  },
  options: {
    scales: { y: { beginAtZero: true, max: WINDOW,
      title: { display: true, text: `Days in a ${WINDOW}-day window` } } },
    plugins: { legend: { position: "bottom" } },
  },
}, this.container);
```

## Year heatmap

```dataviewjs
const HABITS = ["movement", "sleep", "reading", "focus", "nutrition", "screenfree"];
const since = new Date(); since.setDate(since.getDate() - 365);
const sinceKey = since.toISOString().slice(0, 10);

const byDay = new Map();
for (const page of dv.pages('"10_Journal"')) {
  const name = page.file.name;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(name) || name < sinceKey) continue;
  const set = new Set();
  for (const tag of page.file.etags ?? []) {
    const m = tag.match(/^#habit\/(.+)$/);
    if (m) set.add(m[1].toLowerCase());
  }
  byDay.set(name, set);
}

const keys = [...byDay.keys()].sort();
// var(--...) rather than a literal grey, so the grid adapts to light and dark.
const el = dv.el("div", "");
for (const h of HABITS) {
  const row = keys.map((k) => {
    const on = byDay.get(k).has(h);
    const bg = on ? "#16a34a" : "var(--background-modifier-border)";
    return `<span title="${k}" style="display:inline-block;width:6px;height:12px;margin:0 1px;background:${bg}"></span>`;
  }).join("");
  el.innerHTML += `<div style="margin:4px 0"><div style="font-size:.85em;opacity:.7">${h}</div>${row}</div>`;
}
```
