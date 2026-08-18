# 18 — Dashboard Archetypes

Six dashboards, each a different shape of question, each complete and runnable
against the log format from chapter 15. Copy them, change the field names, delete
the ones that do not apply to you.

> A dashboard that answers a question you never ask is a maintenance cost pretending to be insight.

Every block below assumes the loader and helpers from chapter 17. They are
repeated in the first block so it stands alone; later blocks assume you have
factored them into a snippet.

---

## 1. KPI table — the last seven days at a glance

The question: *is anything obviously off this week?* One glance, no
interpretation, no chart.

````markdown
```dataviewjs
const raw = await dv.io.load("memory/measurements.jsonl");
if (!raw) { dv.paragraph("No measurements yet."); return; }

const byDate = new Map();
for (const line of raw.trim().split("\n")) {
  if (line.trim()) { const r = JSON.parse(line); byDate.set(r.date, r); }
}
const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 7);
const week = [...byDate.values()].filter((d) => d.date >= cutoff.toISOString().slice(0, 10));

const avg = (vs) => { const n = vs.filter((v) => v != null); return n.length ? n.reduce((s, v) => s + v, 0) / n.length : null; };
const fmt = (v, dp = 0) => v == null ? "–" : v.toLocaleString(undefined, { minimumFractionDigits: dp, maximumFractionDigits: dp });

const RUN = new Set(["running", "treadmill_running", "trail_running"]);
const acts = week.flatMap((d) => d.activities || []);

dv.table(["", ""], [
  ["Sessions",      `${acts.length} (${acts.reduce((s, a) => s + (a.duration_min || 0), 0)} min)`],
  ["Running",       `${fmt(acts.filter((a) => RUN.has(a.type)).reduce((s, a) => s + (a.distance_km || 0), 0), 1)} km`],
  ["Avg sleep",     week.length ? `${fmt(avg(week.map((d) => d.sleep_hours)), 1)} h` : "–"],
  ["Avg resting HR", `${fmt(avg(week.map((d) => d.resting_hr)))} bpm`],
  ["Avg HRV",       `${fmt(avg(week.map((d) => d.hrv_ms)))} ms`],
  ["Avg steps",     fmt(avg(week.map((d) => d.steps)))],
  ["Days recorded", `${week.length} of 7`],
]);
```
````

The last row is the one that saves you. Without it, a week where the device was
worn twice looks like a week of excellent rest, because every average is computed
over the two days that exist. Any aggregate over a sensor dataset should state
its own sample size.

## 2. Stacked weekly bars — volume by category

The question: *where is the time going, and is the mix changing?*

````markdown
```dataviewjs
const days = await loadMeasurements();     // loader from chapter 17

const RUN = new Set(["running", "treadmill_running", "trail_running"]);
const category = (type) =>
  RUN.has(type)               ? "Running"
  : type.includes("cycling")  ? "Cycling"
  : type.includes("strength") || type === "hiit" ? "Strength"
  : "Other";

const monday = (iso) => {
  const d = new Date(iso + "T12:00:00");
  d.setDate(d.getDate() - (d.getDay() + 6) % 7);
  return d.toISOString().slice(0, 10);
};

const CATS = ["Running", "Cycling", "Strength", "Other"];
const weeks = new Map();
for (const day of days) {
  for (const a of day.activities || []) {
    const key = monday(day.date);
    if (!weeks.has(key)) weeks.set(key, Object.fromEntries(CATS.map((c) => [c, 0])));
    weeks.get(key)[category(a.type)] += a.duration_min || 0;
  }
}

const keys = [...weeks.keys()].sort().slice(-12);
const COLORS = ["#16a34a", "#06b6d4", "#ef4444", "#9ca3af"];

window.renderChart({
  type: "bar",
  data: {
    labels: keys.map((k) => k.slice(5)),
    datasets: CATS.map((c, i) => ({
      label: c,
      data: keys.map((k) => weeks.get(k)[c]),
      backgroundColor: COLORS[i],
      stack: "total",
    })),
  },
  options: {
    scales: { x: { stacked: true }, y: { stacked: true, title: { display: true, text: "Minutes" } } },
    plugins: { legend: { position: "bottom" } },
  },
}, this.container);
```
````

Stacked rather than grouped, because the question is about total load first and
composition second. Twelve weeks rather than all history, because a trend you can
act on is a quarter, and anything longer compresses the recent weeks into
invisibility.

Note that weeks with no activity at all are simply absent from the map, so they
do not appear on the axis. If seeing the empty weeks matters — and for training
load it usually does — seed the map with every Monday in the range before
aggregating.

## 3. Dual-axis load versus recovery — the rest-day chart

The question: *should today be a rest day?* This is the only dashboard here that
is genuinely decision-support rather than review, and it is the one worth
building first.

````markdown
```dataviewjs
const days = (await loadMeasurements()).filter((d) => {
  const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 60);
  return d.date >= cutoff.toISOString().slice(0, 10);
});

window.renderChart({
  type: "bar",
  data: {
    labels: days.map((d) => d.date.slice(5)),
    datasets: [
      {
        type: "bar",
        label: "Training (min)",
        data: days.map((d) => (d.activities || []).reduce((s, a) => s + (a.duration_min || 0), 0)),
        backgroundColor: "#ef4444",
        yAxisID: "y",
      },
      {
        type: "line",
        label: "Recovery indicator",
        data: days.map((d) => d.body_battery_max),
        borderColor: "#16a34a",
        backgroundColor: "#16a34a",
        yAxisID: "y2",
        tension: 0.3,
        pointRadius: 0,
        borderWidth: 2,
        spanGaps: true,
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
````

Read it as a pattern, not as values: full bars with a line that fails to recover
between them, across several days, is the signal. A single hard day followed by a
rebound is fine.

Two deliberate choices. `grid: { drawOnChartArea: false }` on the right axis, so
two gridlines do not fight for the same space. `spanGaps: true` on the recovery
line but not the bars — recovery is a continuous physiological quantity that
existed while unmeasured, whereas training minutes on an unrecorded day must not
be drawn as anything at all.

## 4. Efficiency chart — same output, less cost

The question: *is fitness actually improving, or just effort?* The answer is a
ratio, and it is the metric no vendor app puts on its front page.

````markdown
```dataviewjs
const days = await loadMeasurements();
const RUN = new Set(["running", "treadmill_running", "trail_running"]);

const runs = [];
for (const day of days) {
  for (const a of day.activities || []) {
    if (RUN.has(a.type) && a.distance_km >= 3 && a.avg_hr) {
      runs.push({ date: day.date, ...a });
    }
  }
}
runs.sort((a, b) => a.date < b.date ? -1 : 1);

const paceLabel = (p) => `${Math.floor(p)}:${String(Math.round((p % 1) * 60)).padStart(2, "0")}`;

window.renderChart({
  type: "line",
  data: {
    labels: runs.map((r) => `${r.date.slice(5)} (${r.distance_km} km)`),
    datasets: [
      { label: "Pace (min/km)", data: runs.map((r) => r.duration_min / r.distance_km),
        borderColor: "#16a34a", backgroundColor: "#16a34a", yAxisID: "y", tension: 0.3, borderWidth: 2 },
      { label: "Avg HR (bpm)", data: runs.map((r) => r.avg_hr),
        borderColor: "#ef4444", backgroundColor: "#ef4444", yAxisID: "y2", tension: 0.3, borderWidth: 2 },
    ],
  },
  options: {
    scales: {
      y:  { reverse: true, title: { display: true, text: "Pace (lower is faster)" },
            ticks: { callback: (v) => paceLabel(v) } },
      y2: { position: "right", grid: { drawOnChartArea: false },
            title: { display: true, text: "Avg HR" } },
    },
    plugins: { legend: { position: "bottom" } },
  },
}, this.container);
```
````

Three things make this chart work:

**The inverted pace axis.** `reverse: true` puts faster at the top, so "up is
better" holds for both series and the chart reads without a legend lookup.

**The `>= 3 km` filter.** Short runs have wildly variable pace for reasons that
have nothing to do with fitness — a warm-up, a traffic light, an interval
session. Including them turns the signal into noise.

**Distance in the axis label.** Pace is only comparable across similar distances,
so the label carries the context that makes each point interpretable rather than
pretending all runs are equivalent.

The pattern generalises well beyond running: any *output per unit of cost* over
time. Words written per hour of focus, revenue per hour of meetings, whatever you
have both halves of.

## 5. Streaks and a year heatmap — consistency over months

The question: *is the habit actually happening?* This one reads tags rather than
measurements, so it works for habits with no sensor behind them.

````markdown
```dataviewjs
const HABITS = ["movement", "sleep", "reading", "focus", "nutrition", "screenfree"];
const DAYS = 365;

const since = new Date(); since.setDate(since.getDate() - DAYS);
const sinceKey = since.toISOString().slice(0, 10);

const byDay = new Map();                         // date -> Set of habit names
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

// Current streak: walk backwards from yesterday. Today is excluded because an
// unfinished day would reset every streak to zero each morning.
const streak = (habit) => {
  let n = 0;
  const d = new Date(); d.setDate(d.getDate() - 1);
  for (;;) {
    const key = d.toISOString().slice(0, 10);
    if (key < sinceKey) break;
    if (!(byDay.get(key)?.has(habit))) break;
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
    `${Math.round(total(h) / Math.max(byDay.size, 1) * 100)} %`,
  ]),
);
```
````

The comment about excluding today is not a detail. A streak that counts the
current day resets to zero every morning until you log something, which makes the
number useless and mildly demoralising before breakfast.

The rate column divides by *days with a note*, not by `DAYS`. Dividing by the
calendar punishes you for the week you were on holiday and did not journal; the
honest denominator is the days you actually recorded.

For the heatmap, one row per habit, one cell per day, colour by presence:

````markdown
```dataviewjs
const cell = (on) => on ? "#16a34a" : "var(--background-modifier-border)";
const el = dv.el("div", "");
for (const h of HABITS) {
  const row = [...byDay.keys()].sort()
    .map((k) => `<span style="display:inline-block;width:6px;height:12px;margin:0 1px;background:${cell(byDay.get(k).has(h))}"></span>`)
    .join("");
  el.innerHTML += `<div style="margin:4px 0"><div style="font-size:.85em;opacity:.7">${h}</div>${row}</div>`;
}
```
````

Inline markup rather than a charting library, because a heatmap is a grid of
coloured rectangles and Chart.js has no good primitive for it. Using
`var(--background-modifier-border)` for the off state means the grid adapts to
light and dark themes instead of hardcoding a grey that looks wrong in one of
them.

## 6. Goal progress — distance to a target

The question: *how far along is this, measured from where it started?* Percentage complete is
meaningless without a baseline, and this is the archetype people most often get
wrong by measuring from zero.

````markdown
```dataviewjs
const derived = await loadDerived();      // memory/derived.jsonl
const latest = (field) => [...derived].reverse().find((d) => d[field] != null);

const GOALS = [
  { label: "Weight",  field: "weight_kg", baseline: <baseline>, target: <target>, unit: " kg", lowerIsBetter: true },
  { label: "Fitness", field: "vo2max",    baseline: <baseline>, target: <target>, unit: "",    lowerIsBetter: false },
];

const el = dv.el("div", "");
for (const g of GOALS) {
  const row = latest(g.field);
  if (!row) continue;
  const current = row[g.field];

  const span    = Math.abs(g.target - g.baseline);
  const covered = g.lowerIsBetter ? g.baseline - current : current - g.baseline;
  const pct     = Math.max(0, Math.min(100, covered / span * 100));
  const left    = Math.abs(g.target - current);

  el.innerHTML += `
    <div style="margin:10px 0">
      <b>${g.label}</b>: ${current}${g.unit} → target ${g.target}${g.unit}
      <span style="opacity:.7">(${left.toFixed(1)}${g.unit} to go, as of ${row.date})</span>
      <div style="background:var(--background-modifier-border);border-radius:6px;height:14px;margin-top:4px">
        <div style="background:#16a34a;width:${pct.toFixed(0)}%;height:14px;border-radius:6px"></div>
      </div>
      <span style="font-size:.85em;opacity:.7">${pct.toFixed(0)} % of the way from ${g.baseline}${g.unit}</span>
    </div>`;
}
```
````

Replace `<baseline>` and `<target>` with your own numbers. Four things this
archetype gets right that a naive progress bar does not:

| Choice | Why |
|---|---|
| Progress measured from a baseline, not from zero | Going from 42 to 48 on a 42-to-60 goal is a third of the way, not 80 % |
| `lowerIsBetter` flag | The same code handles "reduce this" and "increase this" without a second implementation |
| Clamped to 0–100 | Overshooting a target must not render a bar wider than its container |
| The measurement's own date shown | A stale value looks identical to a fresh one otherwise, and vendor-derived fields go stale silently |

The baseline is the honest part and the part people fudge. Record where you
actually started, in the file, and leave it there when the number is
unflattering. A progress bar measured from a baseline you keep adjusting is a
mood ring.

---

## Choosing which to build

Do not build all six. Build in this order and stop when the next one has no
question attached to it:

| Order | Archetype | Build it when |
|---|---|---|
| 1 | Dual-axis load vs recovery | You want to make a decision today |
| 2 | KPI table | You want a weekly glance |
| 3 | Streaks | You have habits with no sensor |
| 4 | Efficiency | You have at least three months of comparable data |
| 5 | Stacked weekly bars | The mix matters, not just the total |
| 6 | Goal progress | You have a goal with a real baseline |

The efficiency chart in particular needs history to say anything. Building it in
week two produces a jagged line across four points, and a chart that says nothing
for three months teaches you to stop opening the page.

---

**Read next:** [19 — Why Not the Vendor App](./19_why-not-the-vendor-app.md),
which is the argument this whole part has been building toward.
