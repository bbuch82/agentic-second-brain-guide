# Observed failure modes

Raw material for Part 5, chapter 20. Every entry below was observed while
building this repository, not imagined for it. Chapter 20 argues that the
failures worth catching in an agentic system are the ones that exit zero; the
entries here are the evidence, and all ten come from a single tool whose only
job is to block.

Add to this file whenever a real failure is found. Do not invent entries.

---

## The tool

`tools/privacy-check.sh` scans the repository for strings that must never be
published and blocks the commit. It is the smallest possible security gate:
one input file of rules, one output signal, one decision. It shipped with ten
distinct ways to report success while failing.

## 1. Word-boundary syntax that silently matched nothing

**Symptom:** none. The scan reported clean.

**Mechanism:** word boundaries are spelled `\b` in GNU grep and `[[:<:]]` in
BSD grep. The first draft picked one and assumed it. On a machine whose `grep`
was neither — a third implementation accepting `\b` but rejecting `[[:<:]]` —
the pattern matched nothing at all, and "matched nothing" is indistinguishable
from "found nothing".

**Fix:** prove the syntax before using it, with a positive *and* a negative
probe. A grep that treats the boundary token as a literal passes a
positive-only probe while matching nothing. If neither syntax can be proven,
fall back to substring matching: over-matching costs a false positive,
under-matching costs the whole purpose.

**Lesson:** a capability check that only tests for success cannot detect
silent no-ops.

## 2. A single-file invocation that dropped its own output

**Symptom:** none. Every structural rule passed unconditionally.

**Mechanism:** the scanner parsed grep's `path:lineno:content` output by field
position. grep omits the path prefix when given exactly one file, so the field
split returned an empty string, and an empty string matches no rule. The bug
was invisible for multi-file scans and total for single-file scans — which is
exactly what a pre-commit hook does.

**Fix:** force the prefix explicitly, or scan per file so the path is known
without parsing it back out of the output.

**Lesson:** the code path a hook actually exercises is often not the one the
tests exercise.

## 3. A malformed allow rule that disabled every structural rule

**Symptom:** `clean`, exit 0, with the denylisted token sitting in the file.

**Mechanism:** allow rules were applied by piping the candidate line through
`sed` once per rule and re-testing the remainder. An unbalanced bracket in one
allow rule made `sed` fail; the command substitution captured its empty
output; the re-test found nothing in an empty string; every structural hit was
discarded. One typo in a configuration file disabled half the gate.

**Fix:** validate every rule at startup and refuse to run on an invalid one.
Check the exit status of every command whose output you depend on. Both — the
startup probe and the runtime check — because a pattern can be valid for one
tool and fatal for another.

**Lesson:** an unchecked command substitution converts an error into an empty
success.

## 4. An overmatching allow rule that suppressed everything

**Symptom:** identical to the previous entry.

**Mechanism:** an allow rule of `.*` blanked the entire line before the
re-test. Legitimate syntax, catastrophic effect.

**Fix:** reject at startup any allow rule that matches ordinary prose or the
empty string. A canary string of plain text is enough to catch both.

**Lesson:** validating that configuration *parses* is not validating that it
is *sane*.

## 5. Binary files treated as empty

**Symptom:** none. Binary artifacts scanned clean, always.

**Mechanism:** the `-I` flag makes grep report no match in a binary file
rather than searching it. It was in the tool from the first draft, copied in
without examining what it did. The realistic leak this hides is image
metadata: a name or a GPS tag in EXIF.

**Fix:** classify files, search binary ones explicitly, and report a match by
filename without printing bytes.

**Lesson:** a flag inherited from an example is a decision nobody made.

## 6. A malformed deny rule that neutered only itself

**Symptom:** none, and milder than the others — a later valid rule still fired.

**Mechanism:** grep exits 1 for "no match" and 2 for "invalid pattern". The
scanner branched on success versus failure, folding both into "no match".

**Fix:** separate the error status from the negative result. Everywhere.

**Lesson:** two different failure states collapsed into one is how a gate
loses its voice.

## 7. The same root cause, reintroduced by the fix for it

**Symptom:** none.

**Mechanism:** while restructuring the scanner to fix entry 5, a redundant
`--` was left in the new per-file grep calls. The grep implementation read the
second `--` as a filename that did not exist, returned its error status, and
the surrounding `if` folded that back into "no match" — the identical mistake
as entry 6, in the code written to fix that class of mistake.

**Fix:** the same as entry 6, applied at every call site rather than at the
one that prompted it.

**Lesson:** a fix that addresses an instance rather than a class invites the
class back through a different door.

## 8. A test that passed for the wrong reason

**Symptom:** an unexpected green.

**Mechanism:** a test fixture for a word-boundary rule was written with
`printf 'ok:\bno\b\n'`. `printf` interprets `\b` in its format string as a
backspace byte, so the rule that reached the file was corrupted and matched
nothing — and "matched nothing" made the test pass. The expected result and the
observed result agreed for entirely unrelated reasons.

**Fix:** pass data through `%s` rather than embedding it in a format string.

**Lesson:** the green was suspicious before it was understood, and that was the
signal worth acting on. Confirming it meant looking at the bytes rather than the
output. **An unexpected pass is a bug report about the test.** A result that
arrives more easily than it should has usually skipped the thing it claimed to
measure.

**Related technique:** the coverage gap in the entry below was proved the same
way round — by removing the defence and re-running the suite. If nothing goes
red, nothing was testing it. Mutation beats inspection for answering "is this
actually covered", and it takes about a minute.

## 9. One rule file, two regex engines

**Symptom:** an allow rule that did nothing, and a deny rule that let a real
address through. Both silent.

**Mechanism:** deny rules are applied with `grep -E`; allow rules are applied with
`sed -E`, because they have to *remove* their match rather than report it. The two
engines do not accept the same syntax. An allow rule written with `\s` — valid in
the local grep — matched nothing at all under sed, so the rule silently had no
effect and correct content stayed blocked.

The second half was worse. An allow rule intended for reserved documentation
domains was written unanchored:

```
@[a-zA-Z0-9.-]+\.(invalid|test|example|localhost)
```

Against a real address whose host happened to contain `example` as a middle label,
the rule matched that fragment, stripped it, and left a remainder the deny rule no
longer recognised. A real address passed because a documentation exemption matched
the middle of its domain rather than its end.

The gate caught this text, too: the first draft of this entry quoted the offending
address literally, and the email rule blocked the commit. Correct behaviour — an
illustration does not need to be a live example.

**Fix:** POSIX classes (`[[:space:]]`) rather than engine extensions, everywhere a
rule may be handled by more than one tool. And the unanchored rule deleted rather
than patched, keeping only a form where the literal has to sit immediately after
the `@`.

**Lesson:** a configuration file consumed by two different engines has two
dialects, and the narrower one governs. Worth stating in the file itself, because
nothing about a list of regexes reveals which tool will run them.

**Second lesson, and the sharper one:** an allow rule is a hole by construction, so
it needs a test in *both* directions — that the example passes and that the real
thing still fails. Testing only the former is how the second bug shipped. Every
exemption added to a security gate should arrive with the negative case beside it.

## 10. The gate and its manual invocation disagreed

**Symptom:** a whole-tree scan reported clean; the pre-commit hook blocked the same
content moments later.

**Mechanism:** the exemption list — the file naming paths the scan should skip — was
loaded only on the code path that discovers files itself. The hook always passes
explicit paths, which took the other branch, where the list was never read. So the two
invocations were answering the same question with two different rule sets.

**Fix:** load and apply the exemption list in both modes, and normalise the path form
so a prefix compares against the same repository-relative string either way.

**Lesson:** the defect is not that one answer was wrong. It is that a gate and its
manual invocation could disagree at all. Where a check has two entry points, the
configuration has to be resolved before the branch, not inside it — and the version
that matters is the automated one, which is also the one nobody runs by hand while
developing.

---

## The unreadable file

Not a defect in the end, but the scenario that proves the fix for entries 6
and 7 is real rather than decorative. Once startup validation rejects
malformed patterns, the only remaining way to reach the scan-time error path
is a file the scanner cannot read — wrong permissions, a broken symlink, an
unmounted path. Verified behaviour: the scan stops with a message naming the
rule and the file, rather than counting the file as clean.

**A file the scanner cannot read must never be counted as clean.** This is the
general form of every entry above.

---

## What this collection is for

Ten fail-open paths in roughly two hundred lines of shell whose single
purpose is to say no. Not written carelessly — written with tests from the
first commit, reviewed by a second party, and hardened twice. The tests passed
at every stage. Every one of these was found by asking a different question:
not "do the tests pass" but "what would this do if the thing it depends on
failed".

That question is chapter 21's design brief, and this list is chapter 20's
argument for why it needs one.
