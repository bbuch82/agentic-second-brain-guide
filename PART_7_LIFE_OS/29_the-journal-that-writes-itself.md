# 29 — The Journal That Writes Itself

Journalling fails for almost everyone for the same reason: it asks for effort at the end
of the day, which is when there is least of it. The fix is not more discipline. It is
noticing that the day already left a trail, and that assembling a trail is machine work.

> Do not ask a person at 22:00 what happened. Ask the files.

---

## The inversion

A blank page at the end of the day is a demand. A page that already contains what
happened is an invitation — and the difference in how often you actually write is not
small.

So the evening job does not prompt. It reads every source the day produced, writes what
it can support, and leaves the parts only you can supply empty and clearly marked.

```
  ┌──────────────┐
  │   calendar   │  what you were in
  ├──────────────┤
  │   meetings   │  what was said, and by whom
  ├──────────────┤
  │  transcripts │  voice recordings, transcribed
  ├──────────────┤
  │ measurements │  how the body was
  ├──────────────┤
  │  tasks done  │  what closed
  ├──────────────┤
  │   captures   │  what you sent it during the day
  └──────┬───────┘
         │  21:00, one job
         ▼
  ┌──────────────────────────────────┐
  │  today's note                    │
  │   generated sections + a marker  │
  │   your own prose, untouched      │
  └──────────────────────────────────┘
```

## The sources, and what each may claim

Each source licenses a different kind of statement. Getting this wrong is how an
auto-journal becomes fiction, so the contract is explicit about it.

| Source | May state | Must never state |
|---|---|---|
| Calendar | That an event was scheduled, with whom | That you attended, or that it went well |
| Meeting notes | What was decided and who owns it | Your opinion of it |
| Voice transcripts | What was said, attributed to a speaker | What you meant |
| Measurements | The numbers, and a threshold crossing | A cause |
| Completed tasks | That they closed | That they mattered |
| Captures | Verbatim, as you sent them | A paraphrase that smooths them |

The whole table reduces to one rule: **the job records evidence, not interpretation.**
Interpretation is the part you write, and leaving room for it is the point.

## Voice recordings are the highest-value source

Speaking is four times faster than typing and, more importantly, produces different
content. People dictate what they actually think and type what they think they should
write.

The pipeline, whether the audio comes from a dedicated recorder or a phone:

```
  audio file ──▶ inbox ──▶ transcription ──▶ classification ──▶ destination
                                                                    │
                                            ┌───────────────────────┴──┐
                                            ▼                          ▼
                                   work meeting                 private conversation
                            <Area>/Meetings/                30_Life/Transcripts/
                                            │                          │
                                            └───────────┬──────────────┘
                                                        ▼
                                            today's note links to it
```

Transcription is slow enough that it must be asynchronous. A queue directory, a worker,
a result — the classic shape, and the reason is that a chat interface waiting three
minutes for a transcript is a chat interface that has timed out.

```python
QUEUE = VAULT / "99_Assets/tmp/transcribe-queue"
RESULTS = VAULT / "99_Assets/tmp/transcribe-results"


def enqueue(audio_path: Path) -> str:
    """Accept the file, return immediately. The worker does the slow part."""
    job = hashlib.sha256(audio_path.read_bytes()).hexdigest()[:12]
    QUEUE.mkdir(parents=True, exist_ok=True)
    shutil.move(str(audio_path), QUEUE / f"{job}{audio_path.suffix}")
    return job
```

The agent tells you the recording is queued and stops waiting. The worker transcribes,
writes a result file, and the next inbox run files it like any other document — chapter
11's classification pattern, with audio as one more input type.

Two details that matter more than the transcription quality:

**Hash the audio for the job identifier.** The same recording submitted twice produces
the same job, so a double upload is a no-op rather than two transcripts. Idempotency,
per chapter 22, applied at the front door.

**Keep the audio until the transcript is filed, then archive it, and never delete it
automatically.** Transcription gets things wrong — names especially — and the recording
is the only way to check.

### Speaker attribution is the sharp edge

A transcript with two speakers and no labels is a document that will eventually put
someone else's words in your mouth. If the recorder produces diarisation, keep it. If it
does not, the contract must say so:

```markdown
## Transcripts without speaker labels
Do not attribute statements to a named person. Write "one participant said" or
summarise without attribution. Never present an unlabelled line as the user's own
words or opinion.
```

This is the same failure class as chapter 20's shared-calendar misattribution, in a
setting where it is more embarrassing.

## The weave

One job, one contract, running after the day is effectively over. It writes into today's
note, in fixed sections, guarded so your own writing survives.

```markdown
# Skill: evening-weave

## Trigger
21:00 daily. Also runnable by hand for a past date.

## Reads
- `00_Start/Calendar.md` — today's entries, plus its `updated` field
- `<Area>/Meetings/` and `30_Life/Transcripts/` — files dated today
- `memory/measurements.jsonl` — yesterday's and today's record
- Completed tasks whose file was modified today
- `00_Start/Inbox/` — captures from today not yet filed

## Writes
Into `10_Journal/YYYY/MM/YYYY-MM-DD.md`, between markers:

<!-- begin:weave -->
## Day
## Conversations
## Body
## Open
<!-- end:weave -->

Then the completion marker: <!-- generated: YYYY-MM-DD -->

## Invariants
1. Only the region between the weave markers is rewritten. Prose outside it is never
   touched, moved, or reformatted.
2. Do not invent a feeling, an opinion, or a decision. If the sources do not support a
   sentence, the sentence does not appear.
3. Every referenced document gets a wikilink. Never summarise without linking.
4. Events from shared calendars are attributed by name, or left neutral.
5. If a source is stale — `Calendar.md` older than its interval — say so in the section
   rather than proceeding as if it were current.

## Failure behaviour
A source unavailable: write the sections that are supported, and name the missing one
explicitly. Never silently produce a shorter entry.
```

Invariant 1 is what makes the whole thing tolerable. The generated region is rewritten
every run, so a late meeting appearing at 21:30 is picked up by a re-run — and the
paragraph you wrote at 22:00 about how the day actually felt is untouched, because it
lives outside the markers. Chapter 22 has the mechanism.

Invariant 5 is the one that gets skipped and then produces the most confusing output: a
journal entry describing an empty day because the calendar sync broke on Tuesday.
Nothing errored. The file existed. It was simply old.

### What a woven entry looks like

```markdown
---
title: "2026-08-26"
date: 2026-08-26
tags: [journal, daily]
type: daily
status: active
---

# 2026-08-26

<!-- begin:weave -->
## Day

Four scheduled entries. Platform review with [[Jane Doe]] and [[Richard Roe]] at 09:00;
two blocks marked as focus time in the afternoon. One entry from the shared household
calendar at 17:00, not attributed.

## Conversations

- [[2026-08-26 Platform Review]] — decision: ship the migration behind a flag first.
  Owner [[Jane Doe]]. Two open items assigned here.
- [[2026-08-26 Walk Transcript]] — private, 14 minutes. Recurring theme: the second
  half of the year has no slack in it.

## Body

Sleep 6.1 h, score 64 — third consecutive night under seven hours. Resting heart rate
54 bpm, in range. No activity recorded.

## Open

- [ ] Confirm the rollback window with Ops #todo
- Calendar last synced 13:57, which is current.
<!-- end:weave -->

## Recap

Actually the flag decision was the easy part — the argument was about who owns the
rollback, and nobody said it out loud.

<!-- generated: 2026-08-26 -->
```

Everything above `## Recap` was assembled. The paragraph under it is the only thing that
required a person, and it took twenty seconds because the page was not blank.

That ratio is the entire argument of this chapter.

## The morning half

The same sources, read forward instead of back, delivered to a channel rather than a
file:

| Section | Rule |
|---|---|
| Today's schedule | Verbatim from the calendar, with a staleness note if it is old |
| Birthdays | Chapter 28's rules, drafts included |
| Carried over | Open items from yesterday's woven entry |
| One health line | Only if a threshold was crossed |

Deliberately short. A morning briefing competes with the rest of your phone, and the
version that gets read is the one that fits on a screen.

## Privacy, specifically

Voice transcripts are the most sensitive content in the vault by a wide margin. A
recording of a difficult conversation is not comparable to a meeting note, and the
system should treat it differently:

**Private transcripts go to their own directory**, and no routine reads that directory
as incidental context. The evening weave may link to a transcript and name its theme in
one line; it does not quote it.

**Nothing about a transcript leaves the machine beyond what the model already sees to
transcribe it.** If the content of a class of recording must never reach a third party,
the answer is not to find a clever configuration — it is that this system does not
transcribe those. Chapter 26 makes the general version of that argument.

**Record the fact, not the content, when the content is other people's.** A conversation
with a family member is theirs as much as yours, and a searchable verbatim archive of it
is a decision they did not make.

## Where it disappoints

**It is a record, not reflection.** The generated sections tell you what happened. They
do not tell you what it meant, and reading them back does not produce insight on its own.
What they do is remove the excuse, which turns out to be most of the barrier.

**Transcription errors compound quietly.** A name misheard once becomes a wikilink to a
person who does not exist, and then a second note referencing that link. The people index
regenerating is where you notice.

**The good days get thin entries.** Deep work leaves almost no trace: no meetings, no
messages, an empty calendar. So the days that mattered most produce the shortest woven
sections, and only your own paragraph carries them. Worth knowing, because the pattern
looks like the system failing when it is the opposite.

---

**Read next:** the [contents](../README.md), or [chapter 20](../PART_5_TRUST/20_failure-modes.md)
for what happens when a job like this one exits zero and writes nothing.
