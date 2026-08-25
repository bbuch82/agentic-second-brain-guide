# Heartbeat

Every routine runs on exactly one host. Adding a routine means adding a row.

| Routine | When | Host | Writes | Marker |
|---|---|---|---|---|
| {{ROUTINE}} | {{TIME}} | {{HOST}} | {{WHAT}} | {{MARKER}} |

This table is what the completeness checks assert against. A routine that is not
listed is a capability nothing knows should be running.
