# 27 — What Is Still Wrong

Everything up to here described a system that works. This chapter describes the parts
that do not, the decisions that would be made differently, and the problem nobody in
this category has solved.

> A guide that only documents what works is a sales brochure with code samples.

---

## Still fragile

**Every external integration.** Each one is a schema you do not own, a token that
expires, and a rate limit that can change. The first symptom is always a gap in a
chart rather than an error. Chapter 21's freshness checks are a detection mechanism,
not a fix — and there is no fix, only the choice of how many of these to run. Every
integration added is a permanent maintenance subscription.

**Prompt-contract correctness.** The wrong-attribution failure in chapter 20 was not a
bug in any code. It was a missing rule, and no test would have found it. This whole
class — output that is technically correct and semantically wrong — is caught by
reading the output, by a human, occasionally. That is not a strategy, and no better one
is on offer here.

**Model behaviour drift.** A routine tuned against one model version behaves slightly
differently against the next. The output stays plausible, so nothing alerts. The only
detection is noticing that a briefing reads differently than it used to.

**The vendor-derived fields.** Values that only exist for the current day, described in
chapter 15, remain the most awkward data in the system. The two-log split prevents the
worst corruption, but the underlying problem — a history you cannot reconstruct if you
miss a day — is unsolved and unsolvable from outside the vendor.

## Would be done differently

**The watchdog would come first.** It arrived after several silent failures had already
cost weeks of data. Everything before it was built without knowing whether it was
working. Chapter 12's build order puts it at position five for exactly this reason, and
that ordering is hindsight rather than foresight.

**Fewer integrations, better observed.** The instinct was to connect everything
connectable. A smaller set with freshness checks from day one would have been worth more
than a larger set discovered to be broken weeks later.

**Thresholds would be dated from the start.** Chapter 16 argues that a threshold encodes
a judgement made at a moment. Several thresholds in this system were changed without
recording when or why, so a discontinuity in an old chart is now unexplainable.

**Governance files would have stayed smaller.** They accumulated explanation that
belonged in design documents. Chapter 24 quantifies what that costs: every line is read
on every run, forever.

## Not worth their maintenance cost

Named plainly, because "which integrations to skip" is more useful than another list of
what to add:

| Integration | Why it disappoints |
|---|---|
| Bidirectional task sync | Two systems both believing they own task state. Conflicts are frequent and resolution is manual. One-directional is worth far more than half the trouble |
| Anything with a scraped rather than documented API | Breaks on a UI change, silently, and cannot be tested against |
| A second calendar source | The marginal information is small and the freshness surface doubles |
| Long-form generation from concept notes | Produces competent, unpublishable drafts. The drafting was never the hard part |

The last row generalises. Skills that automate *judgement* consistently underdeliver;
skills that automate *filing, linking and checking* consistently overdeliver. The
tedium was always the bottleneck, not the thinking, and it is worth checking a new idea
against that before building it.

## What the system does not deliver

**It does not make you think better.** It removes friction from capture and retrieval.
The synthesis that changes a decision still happens in a session with a human present —
chapter 13 said composition ends where cross-stage judgement begins, and that boundary
has not moved.

**It does not reduce total time spent.** It reallocates it. Less time filing, more time
maintaining. Whether that trade is good depends entirely on whether you enjoy the second
kind of work.

**It does not remove the operator.** Nothing here is autonomous in the sense people mean
when they say it. It is unattended, which is different: it runs without you until it
does not, and then it needs you specifically.

**Retrieval is still the weak point.** Finding the note you half-remember remains
harder than it should be, and naming conventions plus grep are a floor rather than a
solution. Chapter 24 argues against an embedding index at this scale, and that argument
is about cost and staleness rather than a claim that search is solved.

## The unresolved problem

What happens to a system like this when its owner stops maintaining it?

The vault survives — that was chapter 01's whole argument, and it holds. A folder of
Markdown files with a decade of history is readable by anything, forever, with no
migration.

The *system* does not. Tokens expire, APIs change, containers stop, and within a year
the automation is inert. Not corrupted, just still. And the person who might want it —
a partner, a child, a colleague inheriting a body of work — would need to be the kind
of person who reads this guide.

There is no answer here. It is worth naming because every guide in this category
implicitly promises permanence, and what is actually permanent is the file tree, not the
machinery around it. Two consequences follow, and they are the closest thing to advice:

**Prefer the file tree over the automation** whenever the two compete. A convention that
works without a script beats a script that maintains a convention.

**Write the notes so they read without the system.** A concept note that only makes
sense inside a dashboard is a note that will not survive. One that reads as prose will.

---

That is the honest end of it. The architecture is sound, the failure modes are
documented, the maintenance is real, and the part that will outlast all of it is the
plainest thing in the whole design.

**Read next:** the [contents](../README.md), or [`starter/`](../starter/) to build it.
