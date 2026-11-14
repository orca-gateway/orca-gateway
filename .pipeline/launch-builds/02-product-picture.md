# 02 · Product picture · launch-builds

## Front page

### In one breath
Developers trying Orca start the demo server, Todo included, with one command and no server setup;
you get a complete public release, with notes, from one engine tag. We know it works when the first
tag's release serves the Todo unaided, then by two weeks of image pulls and binary downloads.

### New for you
nothing new

### Trade-offs
1 auto-decided: release on the tag, then a job asks image and binary for the Todo (memory, analogy)

### Questions for you
1. What count keeps the image and binaries? (default: 25 pulls and downloads in the 2 weeks after
   the first release, ours left out; below that they go at the next release. A guess.)
2. Todo scope? (default: add, list, tick, delete, as plan 23.3; kept until the server stops; a tile
   in the Flutter app; iOS, Android open it with ORCA_APP_ID/ORCA_PATH; tick as 03 q1)
3. Image name? (default: ghcr.io/orca-gateway/demo-server, tagged with the engine version and
   latest; its run line in the notes, examples/server/README.md and each app README)
4. Which 3 binaries? (default: Linux and Windows on Intel/AMD, macOS on Apple silicon)
5. Notes from? (default: engine/CHANGELOG.md's section for the tag, written in the PR before
   release.sh; the root CHANGELOG.md, stuck at 0.1.0, links each package's own)

## Appendix

### Personas used
- personas/trying-developer.md (new): a developer evaluating Orca from the example apps.
- personas/maintainer.md (new): you, cutting releases with scripts/release.sh.

### Before and after per persona
| Persona | Before | After |
|---|---|---|
| trying-developer | installs Bun, starts the examples server; no Todo example | one command (`docker run` or a binary) runs it, Todo included |
| maintainer | an engine tag publishes to npm only; the root changelog is stale | the same tag also gives a GitHub release: notes, the image and 3 binaries; the stub engine Dockerfile is gone (01's answer) |

### Trade-offs, in full
- Release on the tag, no draft, then a verify job pulls the image and runs a binary, and asks each for the Todo
  page: memory "central-release-mode"
  (2026-11-07, Maven Central: "automatic release once the upload validates, then a verify job"), applied by
  analogy; logged as an agent decision.
- Not decided by memory (the strategist had cited them as your calls; no such entry exists): where the notes come
  from (question 5), and making the GHCR package public, which is a manual step on GitHub and so goes into
  docs/User_Actions.md by the project's rule (CLAUDE.md), not a choice.

### Out of scope and why
- The full size (a Dockerfile in the `orca` scaffold, multi-arch images, one notes flow for every package): after
  question 1's count says the demo server is used.
- Releases for past tags (0.1.0 to 0.3.4): launch needs the next one; old builds lack the Todo.

### Risks
- Apple-silicon Macs may not start an Intel/AMD-only image (Docker Desktop emulates, slowly); stage 10 tries it; a
  failure adds an arm64 image.
- Counts mislead: our own verify job pulls too and there is no baseline; stage 12 records day one.
- The GHCR package starts private; until you make it public (User_Actions), `docker run` fails for others.
- Unsigned downloads: macOS blocks and Windows warns on first start; the notes give the step (03 q3).
- A tag with no engine/CHANGELOG.md section would ship empty notes (03 q2).

Edited at gate 03 (2026-11-14)
