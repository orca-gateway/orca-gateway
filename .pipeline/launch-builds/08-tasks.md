# 08 · Tasks · launch-builds

## Front page

### In one breath
tasks: 5 in 2 groups · widest group: 4 · cases: 19 of 23 placed
Group 1 runs T1-T4 side by side: the Todo app and tile, the READMEs, the notes check and changelogs,
and the release workflow with the Dockerfile and CI paths. Group 2 (T5: index.ts registers the Todo,
prints the startup line, stops on signals) waits for T1's todo.ts. E1-E4 are stage 10 hand checks.

### New for you
nothing new

### Trade-offs
1 auto-decided: T5 after T1 in its own group, as index.ts imports T1's todo.ts

### Questions for you
1. Commands: test `cd engine && bun test` · lint `shellcheck scripts/release.sh` and
   `flutter analyze` in examples/app · typecheck none (tsc 5.9 refuses the engine's tsconfig).
   (default: as found)
2. Commits by the plugin? (default: none; you commit)
3. One gate per group? (default: yes; `all` runs every group in one turn)
4. T3 writes engine/CHANGELOG.md's "## 0.3.5" section in this PR, as 06 says? (default: yes, dated
   the day it is written; stage 10 can move the date before release.sh runs)

## Appendix

Planned by pipeline:build-task-planner (2026-11-14); the three checks held: every 07 case in one task or Not planned,
no file in two tasks of a group, no task over five files or beyond M, Depends on names an earlier group.

### Groups
| Group | Task | Title | Files | Cases | Size | Depends on |
|---|---|---|---|---|---|---|
| 1 | T1 | Todo app page and Flutter tile | examples/server/todo.ts (new) · engine/test/todo-example.test.ts (new) · examples/app/lib/main.dart | U1, U2, U3, U4, U5, U6, U7, U8, U9, U10 | M | — |
| 1 | T2 | README step 1 and Todo rows | examples/server/README.md · examples/app/README.md · examples/app-ios/README.md · examples/app-android/README.md · engine/test/launch-readmes.test.ts (new) | U11 | M | — |
| 1 | T3 | Notes check and changelog links | scripts/release.sh · CHANGELOG.md · engine/CHANGELOG.md · engine/test/launch-release.test.ts (new) | U12, U13, U14 | M | — |
| 1 | T4 | Release workflow, image recipe, CI paths | .github/workflows/engine-release.yml (new) · Dockerfile · .github/workflows/engine.yml · engine/test/engine-release-notes.test.ts (new) | U15 | M | — |
| 2 | T5 | Demo server registers Todo, stops cleanly | examples/server/index.ts · engine/test/demo-server.test.ts (new) | I1, I2, I3, I4 | S | T1 |

### Order, and why each boundary
- Kind: feature. There is no regression-first task and no scaffold task. The four group-1 tasks share no file, and
  none imports from another.
- 1 → 2: T5's index.ts imports todoApp from T1's examples/server/todo.ts. I1, I3 and I4 GET todo/page/home, so T1
  must exist first.
- T4 stays in group 1. U15 reads only the notes step's `run:` script, which must stay one script. The publish job
  compiles index.ts, which already exists. The verify job needs T1 and T5 only on a real tag (E1).
- T2 quotes T5's startup line "Orca demo server <version> on http://localhost:<port>". It copies the text from 06 and
  imports nothing, so T5 must print exactly that line.
- T3 also writes the "## 0.3.5 - <date>" section in engine/CHANGELOG.md. 06 says this section is written "in the PR
  before release.sh", and E1 needs it merged. T3 may change engine/CHANGELOG.md only for this (question 4).
- T4 owns the gate 07 q1 edit. It adds to engine.yml's push and pull_request paths: examples/server/** (covers its
  README), scripts/release.sh, Dockerfile, examples/app/README.md, examples/app-ios/README.md,
  examples/app-android/README.md and .github/workflows/engine-release.yml.
  - The Dockerfile rewrite, the re-run path (workflow_dispatch tag input) and the verify job have no automated case.
    They go in T4 because the workflow is what uses them.
  - .dockerignore stays as is: the image is built from a folder holding only the Linux binary.
- T1 also carries the Flutter tile because the tile opens T1's app. It has no automated case (E2 checks it by hand),
  and `cd examples/app && flutter analyze` must stay at "No issues found".
- T3 must keep `shellcheck scripts/release.sh` at its baseline: the 3 SC2005 style notes on lines 494-500.
- T1 and T5 must keep `cd engine && bun test` at its baseline: the one existing failure (a test binds 8080) and no new
  ones. Engines in tests listen on port 0 or PORT, never 8080.

### Seams
none: no file is shared, so no seam task is needed.
- examples/server/index.ts belongs only to T5 (Todo registration, startup line, signals).
- engine-release.yml (publish, verify, notes, re-run) and engine.yml belong only to T4.
- 07's engine/test/launch-release.test.ts is split three ways: U11 moves to T2's launch-readmes.test.ts, U12-U14 stay
  in launch-release.test.ts under T3, and U15 moves to T4's engine-release-notes.test.ts.

### Done when
test: `cd engine && bun test` · lint: `shellcheck scripts/release.sh` and `cd examples/app && flutter analyze` ·
typecheck: none (engine tsc 5.9.3 refuses tsconfig's "ignoreDeprecations": "6.0"; not this idea's to fix)
baseline: 706 pass, 1 fail, 707 tests across 29 files (the fail: a test binds 8080, EADDRINUSE); shellcheck: 3 SC2005
style notes (release.sh 494-500); flutter analyze: No issues found. 2026-11-14
commits: none
gate: per group (answered at gate 08, 2026-11-14)

### Not planned
- E1: a hand check at stage 10, in .pipeline/launch-builds/10-uat.md (gate 07). It needs a real engine-v0.3.5 tag and
  runs first.
- E2: a hand check at stage 10, in the same file. It needs E1's release and the GHCR package made public. It also
  checks T1's Flutter tile.
- E3: a hand check at stage 10, in the same file. It needs E1's macOS download and a Mac with Xcode.
- E4: a hand check at stage 10, in the same file. It needs E2's Docker server and an Android emulator.
- The docs/User_Actions.md entry (make the GHCR package public): outside this repo; the main session writes it.
- 07's "Uncovered, on purpose" stays untested: the re-run path (built in T4), the Windows first start, and the day-14
  counts (stage 12).
