# 04 — An Honest Comparison

Before spending an afternoon building this, it is worth knowing when not to. For
a large number of people the right answer is a hosted product, and a guide that
cannot say so is selling something.

> This system trades polish and convenience for the ability to ask questions that span your whole life. If you do not want those questions, the trade is bad.

---

## The field

| | This system | Hosted note-AI | Assistant memory | Commercial second brain |
|---|---|---|---|---|
| Where data lives | Your disk | Their cloud | Their cloud | Their cloud |
| Format | Markdown you can read | Proprietary, exportable in theory | Not exportable in any useful form | Proprietary |
| Cross-domain queries | Anything sharing a date | Within that product | No | Within that product |
| Runs unattended | Yes, on your schedule | Limited, on theirs | No | Limited |
| Add a capability | An afternoon | File a feature request | No | File a feature request |
| Mobile experience | Adequate | Excellent | Excellent | Excellent |
| Setup time | An afternoon to a weekend | Minutes | None | Minutes |
| Monthly cost | Server plus model usage | Subscription | Included | Subscription |
| Who is on call | You | Them | Them | Them |
| Survives the vendor | Yes | No | No | No |

The two rows that decide it are the third and the last: whether you can join
across domains, and whether the system outlives the company that sold it. Every
other row favours the hosted option.

## Where this system genuinely wins

**Joins across domains.** Sleep against journal, calendar against health,
finances against travel. Chapter 19 makes this the central argument, and it is not
a matter of degree — hosted products structurally cannot do it, because the other
half of the data is at a competitor.

**Additive capability.** A new skill is a directory with a spec and maybe a
script. Not a roadmap request, not a plugin API, not a wait. The gap between
"this would be useful" and "this works" is measured in hours, and that gap being
short changes which ideas you bother to have.

**No deprecation risk.** Products get acquired, pivot, and shut down; features
get removed in redesigns. A folder of Markdown files has no roadmap. Every tool
named in this guide could disappear and the vault would be exactly as valuable as
it is today.

**Privacy by construction.** Chapter 16 made the concrete version of this point:
the habits worth tracking are frequently the ones you would not hand to a company.
Same for a journal, for financial notes, for what you actually think about
colleagues. Self-hosting means the sensitive material can be as specific as it
needs to be, because there is no terms-of-service question to consider.

**Cost at scale.** Around fifteen euros a month for a server and model usage,
roughly flat as the vault grows from hundreds to many thousands of notes. Per-seat
subscriptions do not have that shape, and neither does a stack of four of them.

## Where it plainly loses

**Polish.** Every screen in a hosted product had a design team. Your dashboards
are query blocks in a note-taking app. They are functional and they look it.

**Mobile.** Obsidian on a phone plus a chat interface is workable, not delightful.
Nothing here approaches a native app for capturing something one-handed on a
train.

**Setup.** Minutes versus an afternoon, and the afternoon assumes you are
comfortable with a terminal, SSH, and reading a stack trace. Chapter 05's
thirty-minute path narrows the gap but does not close it.

**Maintenance.** This is the big one and it deserves more than a bullet.

## The real cost: you are now on call

The honest accounting is not the fifteen euros. It is that you have taken
ownership of a small distributed system.

Things that will happen, on a timeframe of months:

| Event | Frequency | What it costs you |
|---|---|---|
| A device vendor's API changes | Once or twice a year | An hour, once you notice |
| An OAuth token expires | Around annually per integration | Fifteen minutes |
| A scheduled job fails silently | Whenever a check is missing | Days of missing data before discovery |
| A model provider changes behaviour | Occasionally | Re-tuning a prompt that used to work |
| A dependency breaks on upgrade | Occasionally | An evening |
| You add a capability and it half-works | Whenever you are enthusiastic | The evening you meant to spend using it |

None of these is hard. All of them are yours. Part 5 exists precisely because
"you will notice when it breaks" is false — the failures that matter here are
quiet, and catching them requires deliberate machinery you also have to build and
maintain.

If reading that list produced mild interest, this guide is for you. If it produced
a sinking feeling, that is a correct and useful signal. Buy the subscription.

## When a hosted product is the better answer

Concretely, and without hedging:

- **You want capture and retrieval, not analysis.** If the value is finding the
  note again, a hosted product does that better with none of the overhead.
- **You do not want to operate anything.** Entirely reasonable, and this
  architecture cannot accommodate it. The operator is not optional.
- **Your data is single-domain.** No second column means no join, and the join was
  the argument.
- **Mobile is where you actually work.** The gap is real and will not close.
- **You need it working today.** A weekend project is a weekend.

## When to build this

- You already keep notes in Markdown, and the friction is organisation rather than
  capture.
- You have two or more domains you would join if you could — health and journal,
  work and calendar, reading and projects.
- You are comfortable operating a small server, or interested in learning.
- The privacy of some of the content is not negotiable.
- You expect to still be doing this in five years, which is when the format
  decision from chapter 01 pays out.

## The hybrid nobody mentions

The choice is not exclusive, and the pragmatic answer is usually both.

Keep the hosted tools where they are better. Use the wearable's app to look at
today's sleep. Use your phone's native notes for one-handed capture on a train.
Then let this system be the place where things **land, join, and persist** — the
layer underneath, not a replacement for every interface above it.

Chapter 05's thirty-minute path is designed with exactly this in mind. It builds
the destination first, with no server and no scheduler, so you can find out
whether the joins are worth anything to you before committing to being on call for
them.

---

**Read next:** Part 2 begins with [05 — Stage 0, Thirty Minutes](../PART_2_BUILD/05_stage-0-thirty-minutes.md),
which produces a working system with no infrastructure at all.
