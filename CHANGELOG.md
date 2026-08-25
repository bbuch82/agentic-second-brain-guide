# Changelog

## v2 — 2026

A rewrite rather than a revision. v1 was an eleven-chapter installation manual; v2 is
six parts organised around one thesis, plus the operational material that a year of
running the thing produced.

**Reorganised from eleven install chapters into six parts.** Principles before
procedure, because the mental model is the part that transfers to a different stack and
the part people share.

**The vault is stated as the contract.** v1 described one installation. v2 treats the
Markdown format as the interface between several runtimes, which is what makes any one
of them replaceable.

**Skills replace prose agent profiles.** v1 had six specialists described in prose. v2
has capabilities as artifacts: a contract with six fixed sections, sometimes an
implementation, sometimes tests, and a dated design document recording what was
rejected and why.

**A new part on sensors and dashboards.** The complete loop from a device API through
append-only logs and habit tags to six runnable query blocks. Documented nowhere else in
one piece, and the reason the whole system beats a vendor app: the join.

**A new part on trust.** Nine real failure modes with symptom, cause and fix; the
watchdog that asserts on the vault rather than on the jobs; the five mechanisms that make
a repeated write safe; and runbooks written for someone in a hurry. This is the material
that did not exist in v1 because it had not been learned yet.

**An honest comparison, and a chapter naming what is still broken.** v1 sold the system.
v2 states where a hosted product wins, puts numbers on the maintenance burden, and ends
by naming the unresolved problem: the vault outlives its owner's attention, the
automation does not.

**Publication tooling.** A privacy checker with an out-of-repository denylist, and a
prose checker for the guide's own voice rules. Both are pre-commit gates. The checker's
own nine fail-open paths became the opening example of chapter 20.

**Voice changed.** v1 followed a fictional persona. v2 has none: the form is real, the
example content is synthetic, and the author is not in the document.

## v1 — 2026

The first edition: eleven chapters covering a Hetzner VPS, OpenClaw in Docker, a
Telegram interface, an Obsidian vault, six agent profiles and a set of automation
scripts. Archived unedited under [`v1/`](./v1/README_ARCHIVE.md) and tagged `v1.0`. Its
original filenames still resolve through redirect stubs at the repository root.
