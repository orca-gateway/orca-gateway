---
topic: tck-conformance-kit
status: new
first_seen: native-sdk/05 2026-11-05
seen: native-sdk/05
---
# Technology Compatibility Kit (TCK)

**Concept**  Executable fixtures every implementation of a spec must pass; the fixtures, not the
reference code, define what compatible means.

**Why here**  Three SDKs must agree on 9 Value kinds, 31 transforms and 28 actions; render fixtures
exist, action fixtures do not, so the Dart executor is the spec by accident. A TCK fixes that.

**When not**  One implementation; then its unit tests are the same thing, cheaper.

**Tiny example**  {"action":{"kind":"setState","key":"count","value":1},"initialState":{"count":0},
"expected":{"state":{"count":1},"effects":[]}}  run by bun, flutter, swift and gradle alike.

**Go deeper**  https://jakarta.ee/specifications/ · engine/test/conformance.test.ts
