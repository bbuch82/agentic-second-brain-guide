# Conventions

The contract every program in this vault relies on. Chapter 01 gives the reason for
each line.

## Filenames

| Kind | Pattern |
|---|---|
| Daily note | `YYYY-MM-DD.md`, under `10_Journal/YYYY/MM/` |
| Person | `Lastname_Firstname.md` |
| Reading | `YYYY-MM-DD-kebab-title.md` |
| Concept note | `kebab-title.md`, no date |
| Meeting | `YYYY-MM-DD Short Title.md` |

## Frontmatter

Every note has all five fields.

```yaml
---
title: ""
date: 2026-01-01
tags: []
type: note
status: active
---
```

`type` is one of: `note`, `daily`, `weekly`, `reading`, `person`, `meeting`,
`concept`, `project`, `reference`.

`status` is one of: `active`, `completed`, `archived`.

## Links

`[[Exact_Filename]]`, no extension. Always link a person by their note name, and
create the note if it does not exist.

## Tags

Lowercase, hyphenated. Hierarchical where a group needs selecting as a whole:
`#habit/sleep`, `#habit/movement`. At least two per note.

## Generated files

Dashboards and indexes are queries. Never hand-edit one; change the query or the
source.
