# Skill: quick-capture

## Purpose
Route a prefixed message to the right file without asking a follow-up question.
Capture has to be frictionless or it does not happen.

## Trigger
A message beginning with a known prefix.

## Routing

| Prefix | Meaning | Destination |
|---|---|---|
| `n:` | A note or idea | New file in `00_Start/Inbox/` |
| `t:` | A task | Append `- [ ] <text> #todo` to `00_Start/Tasks.md` |
| `q:` | A quote worth keeping | New file in `05_Wisdom/` |
| `p:` | A person to remember | `40_Network/People/Lastname_Firstname.md` |

## Outputs
The destination file, with full frontmatter per
`99_Assets/Templates/CONVENTIONS.md`. Nothing else.

## Invariants
1. Never ask a clarifying question for a prefixed message. Route it, or flag it.
2. `p:` uses every field of the person template; unknown values stay `""`.
3. Never write to a file other than the destination.
4. Never edit a generated file.

## Failure behaviour
An unrecognised prefix, or text that does not fit the prefix it carries: write it to
`00_Start/Inbox/` tagged `#needs-review`, and say in one line what was unclear.

## History
Initial version. See chapter 12 for why this is the first skill to build.
