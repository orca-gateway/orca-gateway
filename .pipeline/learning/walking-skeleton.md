---
topic: walking-skeleton
status: new
first_seen: native-sdk/06 2026-11-06
seen: native-sdk/06
---
# Walking skeleton

**Concept**  The thinnest end-to-end slice that touches every layer and really runs, built first;
then each step grows one layer while the whole keeps working.

**Why here**  S1 and S2: models, resolver, store, client and renderer, just enough for the counter
page on a phone with fixtures green, before any of the 21 widgets or 12 actions are filled in.

**When not**  A single-layer library; or when the risk sits in one layer only, so spike that layer.

**Tiny example**  S1: XCTest loads schema/fixtures/render/01_text_static.json and passes.
S2: OrcaApp(baseUrl:appId:) shows "Counter Example" with a working plus button.

**Go deeper**  Cockburn, Crystal Clear (2004), walking skeleton · examples/server/counter.ts
