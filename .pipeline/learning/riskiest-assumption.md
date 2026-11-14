---
topic: riskiest-assumption
status: new
first_seen: launch-builds/01 2026-11-14
seen: launch-builds/01
---
# Riskiest assumption

**Concept**  Of all the things an idea takes for granted, the one that sinks it if it is false.
Check it first, the cheapest way you can, before you build anything on top of it.

**Why here**  An engine image only pays off if someone runs it. A library has no pages to serve,
so the assumption to check is that people would run a ready-made demo server at all.

**When not**  A small fix or a chore whose value nobody doubts. Just do it.

**Tiny example**  Assumption: newcomers would try Orca from a demo image. Check: count image pulls
and binary downloads two weeks after the first release, before building anything more on them.

**Go deeper**  Savoia, "The Right It" (2019), pretotyping · Ries, "The Lean Startup", leap of faith
