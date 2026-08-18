# 19 — Why Not the Vendor App

The device manufacturer's app is better than anything in this guide at showing
you your sleep. It is faster, prettier, works on your phone, and requires no
maintenance. It also cannot answer a single one of the questions worth asking.

> The vendor has your sensor data. The vendor does not have your journal. The value was never in either column — it was in the join.

---

## One column each

Every product holding a piece of your life holds exactly one column of the table
you actually want:

| Product | Its column | What it cannot see |
|---|---|---|
| Wearable app | Sleep, heart rate, activity | What you were doing, deciding, or carrying that week |
| Calendar | Where you were | Whether any of it mattered |
| Task manager | What you finished | What it cost |
| Journalling app | How you felt | Whether your body agreed |
| Reading app | What you read | Whether it changed anything you did |

Each is complete on its own terms and useless for the question that spans two of
them. And the questions worth asking always span two:

- Resting heart rate against the weeks with travel in the calendar.
- Sleep quality against the days a difficult conversation shows up in the journal.
- Training volume against your own recorded assessment of focus.
- A habit streak against the month a project shipped.
- Reading volume against the quarters you later judged as your best.

None of these needs clever analysis. Each is a filter and a comparison — the sort
of thing a spreadsheet did in 1985. They are unavailable not because they are
hard but because **the two columns live in different companies.**

## The structural reason it stays that way

This is not an oversight that a better wearable app will fix. It follows from how
these products are built and sold.

A vendor's dataset is its moat. Exporting your data in a form that joins cleanly
with a competitor's — or with your own notes — reduces the cost of leaving, and
reducing the cost of leaving is not a feature anyone is incentivised to ship.
What you get instead is a CSV export that is technically compliant and
practically inert: one row per day, no stable identifiers, no history for the
derived fields, and a schema that changes without notice.

The consequence is worth stating plainly, because it is the part that decides
architecture: **integration is not something you can buy.** Any product that
offered it would need every other product to cooperate, permanently, against
their own interest. The only place the join can happen is somewhere you control,
in a format nobody owns.

That place is a folder of text files.

## What the join actually requires

Very little, and that is the surprising part. Three properties, all of which
chapter 01 already established:

**One query surface.** Measurements in a log, notes in Markdown, both readable by
the same query block. No API, no ETL, no reconciliation step.

**One time key.** Every record carries an ISO date. That is the entire join
condition for almost every question above — no keys, no foreign relations, no
schema.

**Local storage.** Not for ideology. Because a join needs both sides present at
the same moment, and a hosted product will never let both sides be present
anywhere except inside itself.

A dashboard correlating sleep against journalled conflict is roughly twenty lines
of JavaScript. The reason nobody can sell it to you is not that it is difficult.

## What you give up

A chapter making this argument without the other side is marketing. Four things
the vendor app does better, and they are not small:

**Polish.** Its sleep chart took a design team months. Yours took twenty minutes
and looks like it.

**Real-time.** It updates as the device syncs. Your dashboard shows yesterday,
because the sync runs on a schedule and today is incomplete.

**Phone.** It is a native app built for a small screen. Yours is a query block
rendered in a note-taking app, which works on a phone in roughly the way a
desktop site does.

**Zero maintenance.** Nobody pages you when their API changes. In your version,
you are the on-call engineer for an integration with a vendor who does not know
you exist — the cost chapter 27 names explicitly rather than hiding.

Keep the vendor app installed. It is the better tool for looking at one number
today. The system in this guide is for the question that needs two numbers and
three months.

## The general form

Everything in this part has been a specific instance of one principle, and it is
the principle that decides what to build next in the whole system:

> The value of a second brain scales with the number of life domains that share a single query surface — not with the sophistication of any one of them.

Two practical consequences follow, and they are the most useful things in this
chapter.

**Adding a domain beats improving a domain.** A seventh dashboard over the same
sensor data adds a chart. Connecting a second domain — finances, reading,
calendar, a work tracker — multiplies the questions available, because every new
domain can be joined against every existing one. When the choice is between
polishing an existing pipeline and adding a rough new one, add the rough one.

**A domain that cannot join is barely worth ingesting.** Data with no date, no
stable identifier, or in a format only one tool reads is a silo you have moved
rather than opened. Either give it a time key and the vault's format on the way
in, or leave it where it is.

This is why the vault is the centre of the architecture and the agent is not. The
agent is what makes the tedious parts bearable — the classifying, the filing, the
cross-linking, the drafting. The joins are what make the system worth having, and
they belong to the format.

---

**Read next:** Part 5 opens with [20 — Failure Modes](../PART_5_TRUST/20_failure-modes.md),
because everything in this part runs unattended and the interesting failures are
the ones that report success.
