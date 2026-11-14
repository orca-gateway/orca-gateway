# 03 · Product review · launch-builds

## Front page

### In one breath
Ready with changes. iOS and Android cannot tick a Todo (neither SDK draws a check box), the verify
job never asks for the Todo, and two risks are missing: unsigned downloads and empty notes.

### New for you
nothing new

### Trade-offs
1 needs you: 02 has iOS and Android open the Todo, but neither SDK draws a check box (question 1)

### Questions for you
1. Tick on iOS and Android? (default: the Todo uses only what all three apps can draw, so it works
   fully everywhere; otherwise their READMEs would say "no tick")
2. A tag with no notes section? (default: the engine release stops before any change, as its other
   checks do; engine/CHANGELOG.md has no section for 0.3.0, 0.3.1 or 0.3.4 today)
3. Unsigned downloads? (default: macOS blocks and Windows warns on first start; the notes and
   READMEs give the one-time "Open Anyway" step; signing waits for the count)
4. No design source is set, so stage 04 draws the screens. Fine? (default: yes)

## Appendix

### Review table
| Claim | Holds | Evidence |
|---|---|---|
| Trying developers start it with one command and no server setup | partly | trying-developer; true for `docker run` once the package is public, but macOS blocks and Windows warns on unsigned downloads (q3) |
| One engine tag gives the maintainer a complete release with notes | partly | maintainer; the notes are still written by hand first, and 3 of the last 5 engine versions have no changelog section (q2) |
| The first release serves the Todo unaided; release on the tag, check after | partly | answer 01 q3; memory central-release-mode is real (your call, native-sdk-s10 gate 08, 2026-11-07); but the check job only pulls and runs, it never asks for the Todo |
| Keep them at 25+ pulls and downloads in 2 weeks | partly | answer 02 q1, "a guess", no baseline; a download that never starts still counts |
| Todo: add, list, tick, delete, in memory, a Flutter tile; iOS and Android open it | partly | plan 23.3; answer 02 q2; neither sdk-swift nor sdk-kotlin draws a Checkbox (examples/server/index.ts: "a Checkbox iOS lacks"); both apps also take ORCA_PATH |
| Image name, 3 binaries, notes source; run line "in the examples README" | partly | answers 02 q3-q5; there is no examples/README.md; server, app, app-ios and app-android each have their own |
| Before: Bun to start the server, no Todo, root changelog stale, engine tags go to npm only | yes | each app README's step 1 is `task example:dev:server`; no todo in examples/; CHANGELOG.md says "[0.1.0] - Unreleased"; only devtools-v, sdk-swift-v and sdk-kotlin-v tags start workflows |
| Docker or a download is easier for them than Bun (Comfort) | not yet | none: 01's riskiest assumption; the 2-week count tests it |
| Out of scope; risks (Apple-silicon image, misleading counts, GHCR private until made public) | partly | 01's smallest version; CLAUDE.md user-actions rule; missing: unsigned downloads, empty notes, and 01's "the stub engine Dockerfile goes" |
Checked (strategist): examples/server/index.ts, examples/app-ios/README.md, examples/app-android/README.md,
sdk-swift/Sources/OrcaGateway/NodeView.swift, sdk-kotlin/sdk/src/main/kotlin/com/orcagateway/sdk/WidgetBuilders.kt,
engine/CHANGELOG.md, CHANGELOG.md, .github/workflows/, .pipeline/tradeoffs.jsonl.

### Design conflicts
none: no design source is set. The only UI precedent, the tile list in examples/app/lib/main.dart (title, subtitle,
icon, appId), fits a Todo tile.

### Suggested edits to 02
- Trade-offs, front line: "then a job pulls and runs it (memory, by analogy)" → "then a job asks the image and a
  binary for the Todo page (your call, 2026-11-07, by analogy)".
- Trade-offs in full, bullet 1: add "and asks each for the Todo page".
- Question 2 default: "iOS and Android open it with ORCA_APP_ID=todo" → "iOS and Android open it with
  ORCA_APP_ID=todo and its ORCA_PATH; the tick as 03 question 1 decides".
- Question 3 default: "the examples README" → "examples/server/README.md and step 1 of the app, app-ios and
  app-android READMEs".
- Before/after, maintainer After: add "; the stub engine Dockerfile is gone (01's answer)".
- Risks: add "Unsigned downloads: macOS blocks and Windows warns on first start; the notes give the step (03 q3)."
- Risks: add "A tag with no engine/CHANGELOG.md section would ship empty notes (03 q2)."
