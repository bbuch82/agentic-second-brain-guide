---
obsidianUIMode: preview
title: "Health"
type: reference
---
# Health

> Source: `memory/measurements.jsonl`, written daily by the sensor sync — see chapter 15.
> Requires the **Dataview** plugin with JavaScript Queries enabled, and **Charts**.
> Field names below match the log format in chapter 15; change them to match yours.

## Last seven days

```dataviewjs
const raw = await dv.io.load("memory/measurements.jsonl");
if (!raw) { dv.paragraph("No measurements yet. Run the sync."); return; }

// Keyed by date so a re-run or a backfill cannot double-count. Last line wins:
// a later append is a correction.
const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 7);
const week = [...byDate.values()].filter((d) => d.date >= cutoff.toISOString().slice(0, 10));

// v != null, not truthiness: zero is a real measurement.
const avg = (vs) => { const n = vs.filter((v) => v != null); return n.length ? n.reduce((s, v) => s + v, 0) / n.length : null; };
const fmt = (v, dp = 0) => v == null ? "–" : v.toLocaleString(undefined, { minimumFractionDigits: dp, maximumFractionDigits: dp });

const acts = week.flatMap((d) => d.activities || []);

dv.table(["", ""], [
  ["Sessions",       `${acts.length} (${acts.reduce((s, a) => s + (a.duration_min || 0), 0)} min)`],
  ["Avg sleep",      week.length ? `${fmt(avg(week.map((d) => d.sleep_hours)), 1)} h` : "–"],
  ["Avg resting HR", `${fmt(avg(week.map((d) => d.resting_hr)))} bpm`],
  ["Avg HRV",        `${fmt(avg(week.map((d) => d.hrv_ms)))} ms`],
  ["Avg steps",      fmt(avg(week.map((d) => d.steps)))],
  // Without this row, a week the device was worn twice reads as excellent rest.
  ["Days recorded",  `${week.length} of 7`],
]);
```

## Load versus recovery, sixty days

Full bars with a line that fails to recover between them, over several days, is the
signal. One hard day followed by a rebound is not.

```dataviewjs
const raw = await dv.io.load("memory/measurements.jsonl");
if (!raw) { dv.paragraph("No measurements yet."); return; }

const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 60);
const days = [...byDate.values()]
  .filter((d) => d.date >= cutoff.toISOString().slice(0, 10))
  .sort((a, b) => a.date < b.date ? -1 : 1);

window.renderChart({
  type: "bar",
  data: {
    labels: days.map((d) => d.date.slice(5)),
    datasets: [
      {
        type: "bar", label: "Training (min)", yAxisID: "y", backgroundColor: "#ef4444",
        data: days.map((d) => (d.activities || []).reduce((s, a) => s + (a.duration_min || 0), 0)),
      },
      {
        // spanGaps on a continuous physiological measure only. Never on counts:
        // bridging a gap in step data draws activity that did not happen.
        type: "line", label: "Recovery", yAxisID: "y2", borderColor: "#16a34a",
        backgroundColor: "#16a34a", tension: 0.3, pointRadius: 0, borderWidth: 2,
        spanGaps: true, data: days.map((d) => d.recovery ?? null),
      },
    ],
  },
  options: {
    scales: {
      y:  { position: "left",  title: { display: true, text: "Minutes" } },
      y2: { position: "right", min: 0, max: 100, grid: { drawOnChartArea: false },
            title: { display: true, text: "Recovery" } },
    },
    plugins: { legend: { position: "bottom" } },
  },
}, this.container);
```

## Sleep and resting heart rate, ninety days

```dataviewjs
const raw = await dv.io.load("memory/measurements.jsonl");
if (!raw) { dv.paragraph("No measurements yet."); return; }

const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 90);
const days = [...byDate.values()]
  .filter((d) => d.date >= cutoff.toISOString().slice(0, 10))
  .sort((a, b) => a.date < b.date ? -1 : 1);

window.renderChart({
  type: "bar",
  data: {
    labels: days.map((d) => d.date.slice(5)),
    datasets: [
      { type: "bar", label: "Sleep (h)", yAxisID: "y", backgroundColor: "#06b6d4",
        data: days.map((d) => d.sleep_hours ?? null) },
      { type: "line", label: "Resting HR (bpm)", yAxisID: "y2", borderColor: "#ef4444",
        backgroundColor: "#ef4444", tension: 0.3, pointRadius: 0, borderWidth: 2,
        spanGaps: true, data: days.map((d) => d.resting_hr ?? null) },
    ],
  },
  options: {
    scales: {
      y:  { position: "left", max: 12, title: { display: true, text: "Hours" } },
      y2: { position: "right", grid: { drawOnChartArea: false },
            title: { display: true, text: "bpm" } },
    },
    plugins: { legend: { position: "bottom" } },
  },
}, this.container);
```

## Notes

- Days the device was not worn appear as gaps. That is correct: a gap and a day of
  genuine inactivity are different facts and must not look the same.
- Goal-progress and efficiency archetypes are in chapter 18. They need a recorded
  baseline and about three months of comparable data respectively, so they are not
  shipped here.
