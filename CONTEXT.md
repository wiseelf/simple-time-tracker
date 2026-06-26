---
context: SimpleTimeTracker
---

## Glossary

**On-call rotation block**
A user-defined date range (e.g., June 1–7) with a daily time window (e.g., 8am–4pm) during which the user is on duty. Entered manually per rotation; does not recur automatically.

**Non-billable window**
A globally configured day-of-week + time range (e.g., Mon–Fri 8am–6pm) where on-call time produces no billing. Optional app-level setting.

**Billable on-call time**
The portion of an on-call rotation block that falls *outside* the non-billable window. Billed at the passive rate by default.

**Passive on-call**
Billable on-call time during which no on-call active session is logged. Billed at the passive rate (configurable; default 40% of base rate). Derived: (billable on-call window) minus (active on-call sessions within that window).

**Active on-call**
A session explicitly tagged as on-call incident work. Created by clicking the on-call button while the timer is running: saves elapsed time as a regular session, starts a new timer tagged as active on-call. Billed at the active rate (configurable; default 100% of base rate).

**Base rate**
A monetary amount per hour, configured globally. Used to compute income from time. Part of the optional income tracking feature.

**Income tracking**
An optional feature (off by default) that computes monetary amounts from tracked time using the base rate and on-call multipliers. When off, the On-call tab shows hours only.

**Passive rate**
Configurable multiplier applied to passive on-call hours (default: 40% of base rate).

**Active rate**
Configurable multiplier applied to active on-call hours (default: 100% of base rate).
