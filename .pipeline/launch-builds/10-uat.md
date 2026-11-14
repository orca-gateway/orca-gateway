# 10 · UAT · launch-builds

## Front page

### In one breath
PR #27 was merged before the review fixes landed, so they are in PR #28: 3 commits, each
reviewed twice. x64 builds need no AVX2; a macOS job starts the download; pre-releases leave
:latest alone; the re-run wording is true; Todo text shows as typed; no busy-port list in tests.
bun test: 735 pass, 1 fail (8080, as before). #28's checks read once: 2 passing, 2 pending.

### New for you
nothing new

### Trade-offs
3 auto-decided: baseline x64 builds, a macOS check job (free: public repo), Todo text static

### Questions for you
1. Merge PR #28 once its checks are green: yours, so this card waits for you. (default: ok)
2. Right after it, User_Actions "Epic 23: Launch builds": release.sh for engine 0.3.5, make
   demo-server public. Until then the READMEs' Docker and download options lead nowhere.
   (default: as written there)
3. Hand checks E1-E4 after the release: I read the run and the release page (E1); E2-E4 need
   your Mac, a docker pull and the simulators. (default: you run E2-E4, or tell me to)
4. After A: 11 skipped by default; 12 reads the release run and the day-14 counts. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #27 and PR #28
https://github.com/orca-gateway/orca-gateway/pull/27 was opened at this stage after gate 09 and merged by you at
2026-11-14 09:50 UTC (merge 74778c4), before the review's fixes were pushed. Its description is as opened (a fixes
note added to it by mistake was taken back out). Over main it carried the S18 close note, the launch-builds pipeline notes and one commit per task: T1
0a34099, T5 eb9c9ed, T2 d63af92, T3 f111a6e, T4 6afcb96. No engine-v0.3.5 tag and no release exist yet.

https://github.com/orca-gateway/orca-gateway/pull/28 "fix: review fixes for the demo server release (Epic 23)",
from the same branch, holds only the three fix commits below. Bound to this session, Auto-fix off, auto-merge off.
Read once at this card (`get_status`): open, mergeable; 2 passing, 2 pending, 0 failing. The body is in the session
scratchpad (`lb/pr-launch-builds-fixes.md`).

### Review fixes (round 2, your "Yes, fix them")
A code review of PR #27 (xhigh) found 7 issues. Three rework tasks, each a fresh implementer, then fit and quality
reviews (all six passed first time):
| Finding | Fix | Task, commit |
|---|---|---|
| 1 x64 builds need AVX2 (emulated Docker on Apple silicon) | `bun-linux-x64-baseline`, `bun-windows-x64-baseline`; names unchanged | R1 d3e44bc |
| 2 the macOS download is never started | job verify-macos on macos-latest: download, codesign --verify, start, Todo GET | R1 d3e44bc |
| 3 READMEs point at an image and release that do not exist yet | User_Actions: release right after the merge; #28's body says so | docs |
| 4 the re-run overpromises | header, dispatch input, missing-section error; User_Actions Step 3 split by where the fix is | R1 d3e44bc, docs |
| 5 Todo text template-expanded on page GET | `V.static(todo.text)`; U20 | R2 1bbadbc |
| 6 pre-release tags move :latest, normal release | :latest only without a `-` suffix; `--prerelease` on create and edit | R1 d3e44bc |
| 7 the test lists this machine's busy ports | set removed; one retry on a fresh port after an address-in-use start | R3 8749a7c |
New cases: U16-U19 (engine-release-notes.test.ts: targets, image and publish scripts with stub docker/gh for 0.3.5
and 0.4.0-alpha.1, verify-macos), U20 (todo-example.test.ts). One run, mine: `cd engine && bun test` 735 pass, 1
fail, 736 tests across 34 files (server.test.ts, 8080 EADDRINUSE, the baseline's). Not checked by a test: the new
error text and the header comments (R1's Not done).

### docs/User_Actions.md (workspace, outside the repo)
Section "Epic 23: Launch builds — make the demo server image public (GitHub Container Registry)": do the steps right
after the merge (the READMEs' Docker and download options lead nowhere until then); Step 1 release engine 0.3.5 with
release.sh (watch for "ok notes"; publish, verify and verify-macos turn green); Step 2 make the demo-server package
public once, check with `docker logout ghcr.io` and `docker run`; Step 3 only if the run is red: a fix to the
workflow file is picked up by Run workflow for engine-v0.3.5, any other fix ships as 0.3.6; Step 4 the day-14
counts, minus the verify jobs' own pull and two downloads.

### Hand checks (07's E1-E4), after the release
| Id | Who | What |
|---|---|---|
| E1 | me, read only | the "Engine release" run green (publish, verify, verify-macos); release "Engine 0.3.5" published with the run block, the section and 3 assets; :0.3.5 and :latest one digest |
| E2 | you (a docker pull) | Apple-silicon Mac, `docker logout ghcr.io`, the README's docker run line, the Flutter app: Todo tile second; add, tick, delete; Ctrl+C stops and removes the container |
| E3 | you | the macOS zip from the newest Engine release, Open Anyway once, the iOS app with ORCA_APP_ID=todo ORCA_PATH=home: add, tick, delete |
| E4 | you or me on your word | E2's server, an Android emulator, `task example:android:run APP=todo PAGE=home`, a 3-line todo wraps with the dot and × on its first line |

### What ships, what does not
- Ships with the next engine tag: the image, the 3 downloads, the release page. npm gets 0.3.5 from release.sh as
  before. Nothing in the SDKs changes; no wire-format change (the Todo uses existing widgets and actions).
- Not tried before the first tag: the cross-compile for linux-x64-baseline, windows-x64-baseline and darwin-arm64,
  the docker build, the verify-macos job, actionlint (not installed).
- The image is amd64 only; Docker on Apple silicon runs it under emulation, now without needing AVX2. E2 tells
  whether it is good enough; a native arm64 image would be a later change.
- The Windows download is still never started by CI (no finding asked for it).
