---
topic: capability-probing
status: new
first_seen: native-sdk-s17/08 2026-11-13
seen: native-sdk-s17/08
---
# Capability probing

**Concept**  Instead of guessing what a platform can do from its version, ask it once at run time
and remember the answer: try the thing on a known input and see what comes back.

**Why here**  JDK 17/21, Linux's ICU and every Android API level fold a different set of letters; one
probe per process finds the classes this engine misses, with no version table to keep up to date.

**When not**  When the probe is slow or has side effects, or the answer must be known before run time.

**Tiny example**  For each Dart fold class: does `(?i)` + letter A match letter B on this engine?
If not, the SDK writes that class exactly instead of trusting the engine's `i`.

**Go deeper**  S17's design, `.pipeline/native-sdk-s17/08-tasks.md` ("Design", point 0).
