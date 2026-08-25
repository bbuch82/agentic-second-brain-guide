# Part 5 — Trust

The part that does not exist elsewhere. An agentic system rarely fails by crashing; it
fails by finishing, exiting zero, and producing nothing. This part catalogues those
failures from real operation, builds the process that detects them, makes every write
safe to repeat, and gives you something to read at the moment it goes wrong.

| # | Chapter | Delivers |
|---|---|---|
| 20 | [Failure Modes](./20_failure-modes.md) | Nine quiet failures with symptom, cause and fix |
| 21 | [The Watchdog](./21_the-watchdog.md) | Four families of check, alert cadence, and why the set grows from incidents |
| 22 | [Idempotency and State](./22_idempotency-and-state.md) | Five mechanisms for surviving a repeated run |
| 23 | [Recovery Runbooks](./23_recovery-runbooks.md) | Seven entries in a fixed format, written for someone in a hurry |

> Every failure worth catching in this system exits zero. Success is not evidence.

**Read next:** [Part 6 — Operate](../PART_6_OPERATE/README.md)
