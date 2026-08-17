# 16 — Tags as the Interface

Three independent things write habit tags into your notes: a sync job applying a
threshold to a measurement, an agent recording something you told it in
conversation, and you, typing in an editor. One query reads all of them and
knows no difference.

> A convention that three writers must agree on is not a convention. It is an interface, and it needs a written specification.

---

## The shape of the interface

```
    sync job ───┐
                │
  agent ────────┼───▶  #habit/<name>  in a day's note  ───▶  dashboard query
                │
  you, typing ──┘
```

The tag is the entire contract. Not a frontmatter field, not a table row, not a
database — a string in the body of a dated file. That choice buys three things:

**Any writer can produce one.** A shell script can append a line. An agent can
insert one mid-sentence. You can type one. None of them needs to parse or
rewrite the file's structure.

**Position does not matter.** A tag anywhere in the note counts. This is what
makes concurrent writing safe: two producers adding tags to the same note on the
same day cannot conflict over a location, because there is no location to
contest.

**The query is trivial and total.** One pass over dated files, collect tags,
aggregate. No joins, no schema, no migration when you add a habit.

## The vocabulary is the specification

Write it down in a file the agents read, with one row per tag, and treat
additions as interface changes rather than notes-to-self.

```markdown
| Tag | Meaning | Written by |
|---|---|---|
| `#habit/movement` | Any deliberate physical activity | sync job, you |
| `#habit/sleep` | Slept adequately, by the threshold below | sync job |
| `#habit/reading` | Read something substantial | agent, you |
| `#habit/focus` | A block of undistracted work happened | agent, you |
| `#habit/nutrition` | Ate as intended | you |
| `#habit/screenfree` | No screens in the last hour before bed | you |
```

The "written by" column is the part people skip and then regret. Without it, six
months later nobody can answer whether a missing tag means *the habit did not
happen* or *the producer that writes it stopped running* — and those two need
completely different responses. Chapter 21 turns that column into a health
check: if a tag whose only producer is a script has not appeared in a week, the
script is broken, not your week.

### Naming rules, and why each one is load-bearing

| Rule | Reason |
|---|---|
| Lowercase always | `#habit/Sleep` and `#habit/sleep` are different tags in every query engine. Mixed case silently forks your history in half. |
| Hierarchical prefix (`habit/`) | Lets one query select every habit without enumerating them, and keeps habits from colliding with topical tags. |
| One word, no punctuation beyond the slash | Survives being typed on a phone. A tag you cannot type is a tag you will not use. |
| Never rename, only add and retire | A rename rewrites history, or worse, splits it. Retiring means the old tag stops being written while its past remains valid. |
| No tag for something you would not check | Every tag is a column in a chart you will look at. Tags nobody reads are noise that makes the legend unreadable. |

## Where the threshold belongs

This is the chapter's real content, and it is a decision most people get wrong
the first time.

Some habits are booleans by nature: you read, or you did not. Others are derived
from a measurement — "slept adequately" means some combination of duration and a
quality score. That derivation is a threshold, and the threshold has to live in
exactly one place.

**Put it in the producer.** The sync job evaluates the rule and writes the tag
or does not:

```python
SLEEP_MIN_HOURS = 6.5
SLEEP_MIN_SCORE = 75


def habit_tags(record):
    """Tags implied by one day's measurements. The thresholds live here, once."""
    tags = []

    if (record.get("sleep_score") or 0) >= SLEEP_MIN_SCORE \
       and (record.get("sleep_hours") or 0) >= SLEEP_MIN_HOURS:
        tags.append("#habit/sleep")

    kinds = {a["type"] for a in record.get("activities") or []}
    if kinds - NON_QUALIFYING:          # walking and hiking do not count as training
        tags.append("#habit/movement")

    return tags
```

**Do not put it in the query.** The alternative looks tidier at first — leave
the raw numbers in the log and let the dashboard decide what counts as a good
night — and it fails for four reasons:

| Putting the threshold in the query | Consequence |
|---|---|
| Every consumer re-implements the rule | Two dashboards disagree about the same night, and both are "right" |
| Changing the rule rewrites history | Last year's streak silently changes because you adjusted a number today |
| The human and the script use different rules | You type `#habit/sleep` by feel; the script uses 6.5 hours. The chart mixes two definitions |
| The tag stops being a fact | It becomes an opinion recomputed at read time, and nothing can be audited |

The tag records a **judgement made at a point in time**, with the rule that was
in force then. That is what makes a streak meaningful: it is a log of decisions,
not a re-derivation. When you do change a threshold, write the date and the old
value next to the constant. The chart will show a discontinuity and you will want
to know why.

The general form, worth carrying into every skill in Part 3: **derive once, at
write time, in the producer. Readers read.**

## Tag or frontmatter field?

Both are queryable, so the distinction is not technical. Use this split:

| Use a tag when | Use a frontmatter field when |
|---|---|
| The fact is one of many on the same note | The fact is a property *of* the note |
| Several producers may add to it | One writer owns it |
| It is cross-cutting: many notes, one facet | It is structural: type, status, date |
| Absence is meaningful and normal | Absence is an error |

`#habit/sleep` is a tag: many per note, several writers, absence is just a
normal night. `type: daily` is a field: one value, one owner, and a note without
it is broken.

## Choosing your own set

The vocabulary above is deliberately bland, and yours should not be. The habits
worth tracking are the ones you would not put in a hosted product — and that is
not a side note, it is one of the strongest arguments for this whole
architecture.

A commercial habit tracker requires you to hand a third party a list of the
things you are trying to change about yourself, along with a daily record of how
that is going. Self-hosting means the list can be as specific, as personal, or
as unflattering as it actually needs to be, because it never leaves a machine you
control. Design the vocabulary for the person you are, then keep it private by
construction rather than by policy.

Two practical constraints on the set, whatever it contains:

**Six to twelve tags.** Below six, a dashboard has nothing to say. Above twelve,
you stop tagging reliably and the data becomes a record of your enthusiasm rather
than your behaviour.

**Every tag needs a producer.** A tag that depends entirely on you remembering
to type it will decay within a month. Either automate it, have an agent ask about
it as part of a routine, or drop it. A dashboard column that is empty for six
weeks teaches you to distrust the whole dashboard.

---

**Read next:** [17 — Dataview Mechanics](./17_dataview-mechanics.md), which
covers reading JSONL and tags from a query block, and the handful of techniques
every dashboard in the next chapter depends on.
