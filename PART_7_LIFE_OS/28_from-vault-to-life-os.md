# 28 — From Vault to Life OS

Everything so far builds a system that answers questions. This chapter is about the
shift that makes it feel different in kind: a system that raises things you did not ask
about.

> A second brain answers what you ask it. A life OS tells you what you would have wanted to ask.

---

## What actually changes

Nothing architectural. The vault, the two layers, the skills, the checks are all
unchanged. What changes is that three things now exist together:

| Ingredient | Built in |
|---|---|
| A domain with data arriving on its own | Part 4 — sensors, calendar, tasks |
| A written rule about what is worth surfacing | Part 3 — the skill contract |
| A channel that reaches you unprompted | Part 2 — the chat interface and the schedule |

Any one of them alone is a feature. Together they change the system's relationship to
you: it stops being a place you go and becomes something that occasionally speaks.

That is a power worth handling carefully, and most of this chapter is about the
handling.

## The three domains that pay off first

### Health, as context rather than a chart

Part 4 built the loop. What makes it a life-OS ingredient rather than a dashboard is one
line in a skill contract:

```markdown
## Morning briefing — health section
Read yesterday's record from `memory/measurements.jsonl`.
Mention it only when it is actionable: a third consecutive short night, a resting
heart rate several points above the fortnight's average, a recovery indicator that
has not returned after two hard days.
Otherwise say nothing about health.
```

The instruction that carries the weight is the last line. A briefing that recites six
numbers every morning is a report, and you stop reading reports. A briefing that
mentions sleep on the fourth bad night is an observation, and you act on those.

The threshold belongs in the contract, written down, for the reason chapter 16 gave: it
is a judgement, and judgements need a place where they can be reviewed and changed
deliberately.

### Habits, as a streak the system knows about

The tag vocabulary from chapter 16 plus the streak query from chapter 18 already produce
the numbers. The life-OS step is letting the agent read them:

```markdown
## Weekly review — habits section
Read the habit tags from the last four weeks.
Name at most two things: the longest current streak, and one habit that has fallen
off compared with the previous month.
Do not moralise. State the observation and stop.
```

"At most two" and "do not moralise" are not stylistic notes. A system that lists every
lapsed intention every Sunday is a system you learn to skim, and a skimmed review is
worse than none because it costs the same and returns nothing.

### Birthdays, the worked example

This is the smallest complete life-OS feature, and it exercises every part of the
pattern: a data source, a person database, a rule, a draft, and a hard boundary.

**The data.** The calendar sync writes a marker for birthday entries, so they are
recognisable without parsing free text:

```markdown
## 2026-08-26 (Wednesday)
- 🗓 **Jane Doe's birthday** [🎂]
- 09:00–10:00 **Platform review** [Work]
```

**The person database.** A note per person, with a filled template. The birthday field
holds `MM-DD` when the year is unknown and `YYYY-MM-DD` when it is — which is the whole
reason the next rule can exist:

```yaml
---
title: "Jane Doe"
first_name: "Jane"
last_name: "Doe"
type: person
birthday: "1979-08-26"
company: "Acme"
role: "Head of Platform"
relationship: "colleague"
last_contact: "2026-06-14"
---
```

**The rule**, in the briefing contract:

```markdown
## Birthdays
For each [🎂] entry dated today, match the name against `40_Network/People/`.

With a person note:
- State the age ONLY if the birthday field carries a year. Never compute from a
  partial date, and never guess.
- One line of context from the note — role, company, or when you last spoke.
- A copy-paste draft of two to four sentences. Formal or informal register
  according to the relationship field.
- Facts in the draft come ONLY from the person note. Invent nothing.

Without a person note:
- Say "no profile in the network — create one?" and offer no draft.

Never send anything. Drafting is the whole job.

Also list birthdays in the next seven days, without drafts.
```

Six rules, and each one exists because its absence produces a specific embarrassment:

| Rule | Prevents |
|---|---|
| Age only with a year | Congratulating someone on the wrong decade |
| Context from the note only | A warm message containing an invented shared memory |
| Register from the relationship field | Addressing a client the way you address a friend |
| No profile, no draft | A generic message that reads as generic |
| Never send | The category of mistake that cannot be undone |
| Seven-day lookahead | Discovering a gift is needed on the day |

**The last-contact field** is the one people leave out and then miss. "You last spoke in
June" is what turns a birthday message from a ritual into a reason to actually catch up,
and it costs one line in the template.

## People deserve a database, not a folder

Two thousand notes in a directory is a filing cabinet. The same notes with a structured
view are a CRM you happen to own.

Obsidian's Bases feature — or a Dataview table, if you prefer — turns the frontmatter
into a filterable surface:

```yaml
filters:
  and:
    - type == "person"
    - file.inFolder("40_Network/People")
formulas:
  # A sortable MM-DD key, so a birthday list works without a year.
  birthday_sort: if(birthday.length == 10, birthday.slice(5), birthday)
properties:
  file.name:      { displayName: Name }
  formula.birthday_sort: { displayName: "Birthday (MM-DD)" }
  note.company:   { displayName: Company }
  note.role:      { displayName: Role }
  note.relationship: { displayName: Relationship }
  note.last_contact: { displayName: Last contact }
views:
  - type: table
    name: Everyone
    order: [file.name, company, role, last_contact]
    sort:
      - property: last_name
        direction: ASC
  - type: table
    name: Family and friends
    filters:
      or:
        - relationship == "friend"
        - relationship == "family"
    order: [file.name, formula.birthday_sort, last_contact]
  - type: table
    name: Overdue
    filters:
      and:
        - relationship != ""
        - last_contact < "2026-03-01"
    order: [file.name, last_contact]
```

Three things worth copying from that:

**The formula, not a second field.** Deriving a sortable `MM-DD` from whatever the
birthday field holds means one source of truth and no field to keep in step. This is
chapter 17's derive-at-read-time rule applied to a view.

**Named views instead of one giant table.** "Family and friends", "Overdue", "By city" —
each is a question you actually ask. A single table with every column is a table nobody
opens.

**Sorting by a property, not the filename.** Which is why the person template carries
`first_name` and `last_name` as fields even though both are in the title. The filename is for
humans and wikilinks; the fields are for sorting.

### Naming people

Use the natural order, with spaces: `Jane Doe.md`. Wikilinks then read as prose —
`[[Jane Doe]]` — which matters because an agent writes hundreds of them into journal
entries and meeting notes, and `[[Jane Doe]]` in the middle of a sentence reads like a
database dump.

Collisions get a qualifier rather than a reordering: `Jane Doe (Acme).md`.

## Reminders are not tasks

The distinction that keeps this from becoming another nagging inbox:

| | A task | A nudge |
|---|---|---|
| You wrote it | Yes | No — the system noticed |
| Lives in | A task list, until done | A briefing, once |
| Ignoring it | Leaves it outstanding | Is a valid answer |
| Repeats | Until completed | Only if still true tomorrow |

Nudges must not accumulate. A birthday you did not act on is not a backlog item; it is
gone, and the system should not mention it again. The moment nudges start queuing, you
have built a second task list that you did not agree to and will resent.

Concretely: nudges belong in the message, never in a file that persists them. If
something genuinely needs to survive being ignored, it is a task, and it goes through
capture like any other.

## The review cadence

Three loops, three different questions. The value is that they are different — three
variations on "how was it" is one loop run three times.

| Loop | When | Question | Reads |
|---|---|---|---|
| Daily | Evening | What happened, and what is tomorrow | Today's note, calendar, measurements |
| Weekly | Sunday | What moved, what stalled, what got avoided | Seven days of notes, tasks, habits |
| Monthly | Month end | Is the direction still right | Weekly reviews, goals, projects |

The monthly one is the only place the system can say something you could not have said
yourself, because it is the only scope where a trend is visible. It is also the one
people drop first, because its value is invisible for the first three months and obvious
by the sixth.

And a rule for all three: **each writes a note.** A review that exists only as a chat
message cannot be read next month, which defeats the loop above it.

## Where this goes wrong

Four failure modes, all of them about the channel rather than the code.

**It talks too much.** Every additional line in a daily briefing lowers the chance the
whole thing gets read. The correct instinct is to remove sections, not add them. If a
section has not changed a decision in a month, cut it.

**It is confidently wrong about people.** The worst failures in this whole system are
social: an event from a shared calendar attributed to you rather than a family member, a
draft citing a fact about someone that came from nowhere. Chapter 20 catalogued the first
one. The defence is the same in both cases — an explicit ownership rule, facts only from
the note, and neutrality when unsure.

**It sends something.** Never grant an unattended job the ability to send, post, or
reply. Draft freely; send by hand. This is the one rule in the guide with no exception,
and chapter 08's `SOUL.md` is where it is written down.

**It becomes another thing to maintain.** Every nudge is a rule, and every rule is a
thing that can be wrong. Six good nudges beat twenty mediocre ones, and the way to find
the six is to add one at a time and delete what you stop reading.

## The honest limit

This does not manage your life. It surfaces things at moments when you can act on them:
a birthday while there is still time to write, a fourth bad night before you book the
week solid, a person you have not spoken to since June while you are already thinking
about them.

Every decision remains yours, and the system is not smarter than you about any of it. It
is only more reliably *present* — which turns out to be most of what was missing.

That is also its ceiling. It cannot want anything on your behalf, and a system pointed at
goals you do not actually hold will produce a very well-organised year of the wrong
work. Chapter 27's accounting applies here too: the machinery is trustworthy, the
direction is not its department.

---

**Read next:** the [contents](../README.md), or [`starter/`](../starter/) to build it.
