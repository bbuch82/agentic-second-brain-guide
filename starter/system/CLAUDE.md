# Coding agent instructions

This vault is a running system. Two layers write to it: scheduled jobs, and you, here.

## Before changing anything
Read `SECURITY.md` and `99_Assets/Templates/CONVENTIONS.md`.

## Writable
`skills/`, `99_Assets/`, `docs/`

## Not writable
Root-level `*.md`. Note content, unless the task is explicitly about a note.

## Scripts you write
- Never write to `memory/` without an approved exception in `SECURITY.md`
- Must be safe to run twice
- Must have `--dry-run` and `--vault PATH` before being scheduled
