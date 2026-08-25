# Security

## Read-only
Never modify: IDENTITY.md, SOUL.md, TOOLS.md, AGENTS.md, SECURITY.md, HEARTBEAT.md,
USER.md, MEMORY.md, CLAUDE.md

If a change to one of these seems necessary, say so and stop.

## Append-only
Never rewrite existing lines in: `memory/*.jsonl`, `memory/observations.md`

## Deletion
Never delete a note. Move it to `90_Archive/` with `status: archived`.

## Generated output
Never hand-edit a generated dashboard or index. Change the query or the source.

## Ambiguity
Never guess a destination, a person's identity, or a date. Leave the item in place, tag
it `#needs-review`, and report what was unclear.

## Secrets
Never read, write, or repeat a credential. Credentials live outside this vault.

## Approved exceptions
None yet. Each exception names the script, the paths, the date, and the mechanism that
keeps it safe. An exception without a scope is a hole.
