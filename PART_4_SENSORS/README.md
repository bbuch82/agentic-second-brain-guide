# Part 4 — Sensors and Dashboards

The complete loop from a wearable's API to a query block, documented nowhere else in
one piece. Six chapters: the architecture, the sync implementation, the tag vocabulary
three writers share, the query techniques, ten runnable dashboards, and the argument for
owning both ends of the data.

| # | Chapter | Delivers |
|---|---|---|
| 14 | [The Sensor Loop](./14_the-sensor-loop.md) | Seven hops from device to dashboard, with the contract at each seam |
| 15 | [Building the Sync](./15_building-the-sync.md) | Token reuse, catch-up from the log itself, idempotency, the vendor seam |
| 16 | [Tags as the Interface](./16_tags-as-the-interface.md) | Three producers, one consumer, and where the threshold belongs |
| 17 | [Dataview Mechanics](./17_dataview-mechanics.md) | The six techniques every dashboard depends on |
| 18 | [Dashboard Archetypes](./18_dashboard-archetypes.md) | Ten complete query blocks, and the order to build them |
| 19 | [Why Not the Vendor App](./19_why-not-the-vendor-app.md) | The join argument, generalised |

> The vendor has your sensor data. The vendor does not have your journal.

**Read next:** [Part 5 — Trust](../PART_5_TRUST/README.md)
