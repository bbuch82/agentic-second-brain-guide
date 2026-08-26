# 18 — Dashboard Archetypes

Ten dashboards, each a different shape of question, each complete and runnable
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

## 7. Rolling window — making a boolean readable

The question: *is this habit trending up or down?* Plotted raw, a yes/no series is a
picket fence that shows nothing. A rolling count over a window turns it into a line.

````markdown
```dataviewjs
const HABITS = ["movement", "reading", "focus", "nutrition"];
const COLORS = ["#16a34a", "#8b5cf6", "#f59e0b", "#06b6d4"];
const DAYS = 90;
const WINDOW = 7;

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
````

Three details carry it:

**The axis is capped at the window size and says so.** "Days in a 7-day window" is
immediately readable; an uncapped axis labelled "count" is not.

**Load `WINDOW` extra days of history.** Without it the first week of the chart is
computed from a partial window and slopes up from zero — an artefact that looks exactly
like a real improvement.

**Four series, not fifteen.** Past four or five lines the legend becomes the chart. Pick
the ones you are actually trying to move.

The technique generalises to anything binary and daily: did you ship, did you practise,
did you go outside.

## 8. The matrix — one row per day, navigable

The question: *what actually happened, day by day?* The heatmap in archetype 5 answers a
year at a glance; this answers a month in detail, and every row is a link.

````markdown
```dataviewjs
const HABITS = [
  ["movement", "🏃"], ["sleep", "😴"], ["reading", "📚"],
  ["focus", "💼"], ["nutrition", "🥗"], ["screenfree", "📱"],
];
const MONTHS = 3;

const byDate = new Map();
for (const page of dv.pages('"10_Journal"')) {
  const name = page.file.name;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(name)) continue;
  const set = new Set();
  for (const tag of page.file.etags ?? []) {
    const m = tag.match(/^#habit\/(.+)$/);
    if (m) set.add(m[1].toLowerCase());
  }
  byDate.set(name, set);
}

const months = [...new Set([...byDate.keys()].map((d) => d.slice(0, 7)))]
  .sort().reverse().slice(0, MONTHS);

for (const ym of months) {
  const [year, month] = ym.split("-");
  dv.header(3, new Date(+year, +month - 1)
    .toLocaleDateString(undefined, { month: "long", year: "numeric" }));

  const lastDay = new Date(+year, +month, 0).getDate();
  const rows = [];
  for (let d = 1; d <= lastDay; d++) {
    const key = `${ym}-${String(d).padStart(2, "0")}`;
    const habits = byDate.get(key) || new Set();
    // The day cell links to the journal entry, with a short display label.
    rows.push([
      dv.fileLink(key, false, String(d).padStart(2, "0")),
      ...HABITS.map(([k]) => habits.has(k) ? "✅" : "·"),
    ]);
  }
  dv.table(["Day", ...HABITS.map(([, icon]) => icon)], rows);
}
```
````

**The linked day cell is the point.** A grid that shows a gap is mildly interesting; a
grid where you click the gap and land in that day's note is how you find out *why*. This
is the only archetype here that is a navigation surface rather than a readout.

**Iterate the calendar, not the data.** Looping days 1 to `lastDay` means days with no
note appear as empty rows rather than vanishing. A matrix built from the records you have
silently hides the days you skipped, which are the ones worth seeing.

**Emoji as column headers**, because fifteen text labels do not fit and a legend above the
table does the explaining. This is the one place emoji are data rather than decoration.

## 9. State-coloured bars — colour as a category

The question: *what did the system think on each of those days?* When a vendor supplies
both a score and its own classification of that score, encode the classification in the
bar colour rather than adding a second series.

````markdown
```dataviewjs
const days = (await loadDerived()).filter((d) => {
  const cutoff = new Date(); cutoff.setDate(cutoff.getDate() - 60);
  return d.date >= cutoff.toISOString().slice(0, 10);
});

const colour = (level) =>
  level === "HIGH" || level === "PRIME" ? "#16a34a"
  : level === "MODERATE"                ? "#f59e0b"
  : "#ef4444";

window.renderChart({
  type: "bar",
  data: {
    labels: days.map((d) => d.date.slice(5)),
    datasets: [{
      label: "Readiness",
      data: days.map((d) => d.readiness_score ?? null),
      backgroundColor: days.map((d) => colour(d.readiness_level)),
    }],
  },
  options: {
    plugins: {
      legend: { display: false },
      title: { display: true,
        text: "Readiness — green: ready · amber: moderate · red: recover" },
    },
    scales: { y: { min: 0, max: 100 } },
  },
}, this.container);
```
````

**One dataset, per-bar colours.** `backgroundColor` accepts an array, one entry per point.
Splitting into three datasets by level would work and would produce gaps in each series.

**Legend off, meaning in the title.** A legend for a single dataset says "Readiness",
which you already knew. The colour key is what needs explaining, and the title is where it
fits.

**A fixed `0–100` scale.** Letting a bounded score auto-scale makes a quiet fortnight look
dramatic, which is the most common way a chart misleads its own author.

## 10. Latest-value card — a summary over a sparse log

The question: *what is the current standing?* Harder than it sounds when the log is sparse:
different fields were last written on different days, because the vendor computes them on
different schedules.

````markdown
```dataviewjs
const days = await loadDerived();

// Each field independently: the newest record where it is present. A single
// "latest record" would show blanks for everything not computed that day.
const latest = (field) => [...days].reverse().find((d) => d[field] != null);

const fmtTime = (s) => {
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
  return (h ? `${h}:${String(m).padStart(2, "0")}` : m)
    + ":" + String(Math.round(s % 60)).padStart(2, "0");
};

const rows = [];
const add = (label, field, render) => {
  const row = latest(field);
  if (row) rows.push([label, `${render(row)} — as of ${row.date}`]);
};

add("Fitness estimate", "vo2max", (r) => r.vo2max);
add("Fitness age",      "fitness_age", (r) => `${r.fitness_age} years`);
add("Weight",           "weight_kg", (r) => `${r.weight_kg} kg`);
add("Endurance",        "endurance_score", (r) => r.endurance_score);
add("Race predictions", "race", (r) =>
  `5K ${fmtTime(r.race.time5K)} · 10K ${fmtTime(r.race.time10K)} · HM ${fmtTime(r.race.timeHalfMarathon)}`);

dv.table(["", ""], rows);
```
````

Three properties worth stealing:

**Per-field recency, not per-record.** `latest(field)` scans backwards for the newest
record where *that* field exists. Reading the last line of the log instead would blank out
every field the vendor did not compute today.

**Every value carries its own date.** A stale figure and a fresh one look identical
otherwise, and vendor-derived fields go stale silently — the exact failure chapter 20
catalogues, surfaced in the one place you would notice.

**Rows appear only when they have data.** A card with five empty rows reads as broken; a
card with two rows reads as early days.

---

## Choosing which to build

Do not build all ten. Build in this order and stop when the next one has no question
attached to it:

| Order | Archetype | Build it when |
|---|---|---|
| 1 | Dual-axis load vs recovery | You want to make a decision today |
| 2 | KPI table | You want a weekly glance |
| 3 | Streaks | You have habits with no sensor |
| 4 | Matrix | You want to click a bad day and find out why |
| 5 | Latest-value card | Your log is sparse and you want a standing |
| 6 | Rolling window | A habit has enough history to have a direction |
| 7 | Efficiency | You have at least three months of comparable data |
| 8 | Stacked weekly bars | The mix matters, not just the total |
| 9 | State-coloured bars | A vendor supplies both a score and a verdict |
| 10 | Goal progress | You have a goal with a real baseline |

The efficiency chart in particular needs history to say anything. Building it in week two
produces a jagged line across four points, and a chart that says nothing for three months
teaches you to stop opening the page.

Two of these are worth more than their position suggests. The **matrix** is the only one
that leads somewhere — every other archetype ends the enquiry, and that one starts it. And
the **rolling window** is the only honest way to look at a habit, because a raw yes/no
series cannot show a trend and a streak counter only shows the present.

---

**Read next:** [19 — Why Not the Vendor App](./19_why-not-the-vendor-app.md),
which is the argument this whole part has been building toward.
