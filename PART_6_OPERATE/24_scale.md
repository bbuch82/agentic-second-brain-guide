# 24 — Scale

Around eight thousand notes, nothing about the file tree is slow. What becomes
expensive is the thing you never measure: the number of bytes an agent reads before
it starts working, on every single run.

> The constraint is not disk, and it is not search. It is that every file the agent reads on every run is a recurring cost.

---

## What actually degrades

| Operation | At ~8,000 notes | Scaling |
|---|---|---|
| Full-text search across the vault | Well under a second | Linear, and the constant is tiny |
| Listing a directory | Instant | Flat |
| Parsing every frontmatter block | A few seconds | Linear; fine for a scheduled check, too slow for a query block |
| A dashboard query over one folder | Instant | Linear in that folder only |
| An agent reading its context files | Every run, always | Flat, but paid on every operation |
| An agent searching for the right note | Varies enormously | Depends entirely on how well the tree is named |

Only the last two matter, and neither is about the size of the vault.

## Full-text search beats an embedding index here

The instinct at a few thousand notes is to build a vector index. It is usually the
wrong move, for reasons that are specific to this shape of data.

**Your own vocabulary is stable.** You call things what you call them. The
paraphrase problem embeddings solve — the query and the document using different
words for the same thing — barely exists in a corpus you wrote yourself.

**Exact match is what you actually want.** Searching for a person's name, a project
name, or a distinctive phrase should return exactly the notes containing it, not the
notes that feel similar.

**Grep composes with everything.** Scoped to a folder, combined with a date filter,
piped into another command. An index is a separate system with its own freshness
problem — and a stale index is chapter 20's whole subject.

**Naming does the work an index would.** `40_Network/People/Doe_Jane.md` is found by
knowing the convention. That is the payoff for chapter 01's insistence that
conventions exist because programs depend on them.

Where embeddings genuinely help: finding everything across thousands of concept
notes that relates to an idea you cannot name a keyword for. That is a real use
case and it arrives later than people think. Build it when a specific question
has repeatedly failed, not in advance.

## The context budget is the real constraint

An agent reads its governance files on every run. Nine files at a few hundred lines
each is a fixed cost on every operation, however trivial.

The arithmetic is unforgiving in one direction: a capability file that grows from
100 to 1,000 lines makes *every* run more expensive, including the ones that never
touch that capability. And the cost is paid in the currency that matters most —
attention. A model with 900 lines of instructions it does not need for the current
task is measurably worse at the task.

Four techniques, in order of how much they buy:

**An index, not a store.** The memory file lists what is remembered and where, one
line each. The content lives in files that are read only when relevant. A memory
file that contains the memories is the single most common way this budget is blown.

**Per-area context files.** Rather than one file describing every work area, one per
area, read only when that area is the subject. Ten areas at 50 lines each cost 50
lines, not 500.

**Rules, not documentation.** Governance files state what to do. Explanations belong
in the guide, the design documents, and comments — read by humans and by agents that
are specifically working on that component.

**Pre-computed dashboards.** A generated summary file is one read. Re-deriving it in
context is thousands.

## Techniques that scale the tree

| Technique | What it fixes |
|---|---|
| An index file per large folder | An agent listing 2,000 files to find one |
| Dated filenames | Sorting and recency without opening anything |
| A closed `type` vocabulary | Selecting a category without heuristics on the path |
| Archiving completed work | Keeping the live tree the size of what is live |
| Scoped search by default | A query touching one folder instead of all of them |

Archiving is the one that gets skipped. Moving finished projects to an archive
directory that queries exclude keeps the working set proportional to your current
life rather than your whole history — and it costs nothing, because chapter 03's
rule already says archive rather than delete.

## What breaks first, in practice

Not performance. Three other things, in this order:

**Naming drift.** Two conventions for the same kind of note, because one predates a
decision. Queries silently return partial results. The fix is a one-off normalisation
pass and a written convention — and the integrity check from chapter 21 is what stops
it recurring.

**Dangling links.** Chapter 01 warned that nothing enforces referential integrity.
At scale you accumulate links to notes that were renamed or never created. Add a
check that reports them; expect the first run to find dozens.

**Dashboard sprawl.** A page that grew to twenty query blocks, each loading the same
log. It becomes slow to render and nobody opens it. Split by theme before optimising
the queries; two focused dashboards are better reading anyway.

## When it would genuinely stop working

For honesty, the actual limits:

| At roughly | What breaks | Response |
|---|---|---|
| 50,000 notes | Whole-tree frontmatter parsing gets slow for scheduled checks | Check incrementally, by modification time |
| 100,000 notes | Obsidian's own indexing becomes noticeable | Split into multiple vaults by domain |
| 100,000 measurement lines | A query block parsing the whole log per render | Roll old data into monthly files |

None of these is near. A daily journal, a few notes a day and a daily sensor record
puts you at a few thousand notes and a few thousand log lines per year. The format
outlasts the decade before any of the above matters — which was chapter 01's argument
for choosing it.

---

**Read next:** [25 — Cost and Model Routing](./25_cost-and-model-routing.md), where
the money actually goes.
