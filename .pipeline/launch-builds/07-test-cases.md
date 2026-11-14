# 07 · Test cases · launch-builds

## Front page

### In one breath
cases: 15 unit · 4 integration · 4 e2e. They cover the Todo page and its 3 actions on every SDK's
widget set, the server's start, stop and compiled binary, the READMEs, the notes check and the notes
step, and each persona flow. Uncovered: the 2-week counts (stage 12), the re-run path and
the Windows start.

### New for you
nothing new

### Trade-offs
1 auto-decided: E1-E4 stay hand checks at stage 10, none in CI (memory "e2e-hand-checks", your call,
2026-11-07, another project; here a real tag and real devices)

### Questions for you
1. Run the new tests on PRs touching only examples/server, scripts/release.sh, the Dockerfile, the
   READMEs or engine-release.yml? (default: yes, those paths join engine.yml's triggers)
2. The re-run path and the Windows download's first start stay untested? (default: yes; the re-run
   runs only if the first tag goes red, and there is no Windows machine; the same compile builds it)

## Appendix

Written by pipeline:design-test-designer (2026-11-14) from 02, 04's flows and 06; checked here: every 02 claim, 06
component and 04 flow has a row; every id exists; every case sits in one file.

### Cases
| Id | Level | Given | When | Then | Source | Priority |
|---|---|---|---|---|---|---|
| U1 | unit | a fresh import of todoApp, registered alone on an Engine (port 0), nothing added yet | GET /api/v1/app/todo/page/home | 200; the tree has a TextField, an "Add" ElevatedButton, a node keyed "todo-list" holding "Nothing to do yet. Add one above.", and the footer "Kept on the server until it stops." | 06 component todo app | must |
| U2 | unit | the page tree from U1 | inspect the TextField and the Add button | the TextField's onChange is SetState page "draft"; Add's action is ServerAction addTodo with text bound to page state "draft" | 06 data "draft" | must |
| U3 | unit | the list holds "Call Sam" | POST action addTodo {text: "  Buy milk  "} | the reply is [replaceComponent targetId "todo-list", setState page "draft" ""]; the new list ends with "Buy milk" (trimmed); its tree equals the "todo-list" of a fresh GET | 06 sequence I add, tick and delete a todo | must |
| U4 | unit | any list | addTodo {text: "   "} | the reply has no actions; the next GET shows the same list | 06 sequence I add, tick and delete a todo | should |
| U5 | unit | two items both named "Call Sam" | toggleTodo {id of the first}, then toggleTodo again | the ids are distinct strings; only the first shows check_circle green with grey lineThrough text, the second keeps the grey circle; order unchanged; the second toggle restores it | 06 data todos | must |
| U6 | unit | three items | deleteTodo {one id}, deleteTodo {"no-such-id"}, then delete the rest | only that row goes; the unknown id leaves the list as it was; after the last delete "todo-list" holds "Nothing to do yet. Add one above." | 06 sequence I add, tick and delete a todo | must |
| U7 | unit | an item whose text is 300 characters | GET the page | its Row has crossAxisAlignment "start" and children GestureDetector(Icon circle), Expanded(Text), GestureDetector(Icon close); the TextField sits in an Expanded beside Add | 06 component row layout | must |
| U8 | unit | the page tree | inspect the root | the page Column sits in a SingleChildScrollView and the footer follows "todo-list" | 06 component page scroll | should |
| U9 | unit | todoApp on an Engine with its default cache (not cache: false) | GET the page, addTodo "Buy milk", GET the page again | the second answer lists "Buy milk" (cachePolicy "none" holds) | 06 component todo app | must |
| U10 | unit | swiftCapabilityVector() and kotlinCapabilityVector() from schema/gen-native-capabilities.ts | GET the page sending each vector (412 retry as caps-policy-e2e.test.ts does); collect the 3 action replies | the served tree equals the unfiltered one (nothing stripped, no FallbackPrompt); every widget type and action kind in the page and the replies is in both vectors; no Checkbox, InkWell, FloatingActionButton or SnackBar | 02 claim 5 | must |
| U11 | unit | the README.md of examples/server, app, app-ios and app-android | read step 1 and the "Other example apps" table | each has `docker run --rm -p 8080:8080` with `ghcr.io/orca-gateway/demo-server:latest`, a `/releases?q=engine-v` link, `chmod +x`, "Open Anyway", "Run anyway", `task example:dev:server` and "Ready when it prints" quoting "Orca demo server"; app-ios and app-android have a Todo row naming todo and home | 02 claim 6 | must |
| U12 | unit | the root CHANGELOG.md | read it | no "[0.1.0] - Unreleased" body; it links engine/, sdk/, cli/ and the 4 plugins' CHANGELOG.md, and each linked file exists | 06 data root CHANGELOG.md | should |
| U13 | unit | a scratch git repo on main with release.sh, the 10 manifests (engine 0.3.4), an engine/CHANGELOG.md holding "## 0.3.50 - x" and "## 0.3.4 - x" only, a bare local origin, a stub npm on PATH | run release.sh, answer 1 then ⏎ | prints `stop: engine/CHANGELOG.md has no "## 0.3.5"` and "Nothing was changed.", exits non-zero; git status clean, no engine-v0.3.5 tag, manifests unchanged | 02 claim 12 | must |
| U14 | unit | the U13 repo with "## 0.3.5 - 2026-11-20" added and committed | answer 1, ⏎, then n | prints `ok notes, engine/CHANGELOG.md "## 0.3.5"`; the summary has "then a GitHub release"; it stops "aborted" with the tree clean | 06 component notes check | should |
| U15 | unit | a fixture engine/CHANGELOG.md with 0.3.6, 0.3.5 and 0.3.4 sections | run the notes step of engine-release.yml for engine-v0.3.5 | the notes are the Run block (`ghcr.io/orca-gateway/demo-server:0.3.5`, Open Anyway, Run anyway), then exactly the 0.3.5 body; no line from 0.3.6 or 0.3.4 | 02 claim 8 | must |
| I1 | integration | examples/server/index.ts spawned with bun, PORT set to a free port | wait for startup; GET todo/page/home with and without x-api-key demo-key; GET counter/page/home | stdout has "Orca demo server <engine/package.json version> on http://localhost:<port>" and an app list naming todo; todo answers 200 with "Nothing to do yet" with the key and 401 without; counter answers 200 | 06 component demo server entry | must |
| I2 | integration | index.ts running (spawned) | send SIGINT; start a second one and send SIGTERM | each exits with code 0 within 5 s | 06 component stop on signal | must |
| I3 | integration | index.ts running, "Buy milk" added through POST /api/v1/app/todo/action with demo-key | SIGTERM, start it again, GET the page | the list is empty again ("Nothing to do yet") | 06 data todos | should |
| I4 | integration | `bun build --compile examples/server/index.ts` for the host target, the binary copied to a temp dir outside the repo | run it there with PORT set; GET todo/page/home with demo-key; SIGTERM | the same startup line with the version (no file read from the repo at runtime); 200 with "Nothing to do yet"; exit 0 | 02 claim 1 | must |
| E1 | e2e | stage 10; a merged "## 0.3.5" section in engine/CHANGELOG.md | the maintainer runs release.sh (1, ⏎, y) and waits for the engine-v0.3.5 run | npm has 0.3.5; GHCR has :0.3.5 and :latest with one digest; release "Engine 0.3.5" is published, not a draft, with the Run block then the section and assets demo-server-linux-x64, demo-server-windows-x64.exe, demo-server-macos-arm64.zip; the verify job is green and its log shows the image and the Linux download each answering the Todo GET | 04 flow maintainer | must |
| E2 | e2e | after E1 and the User_Actions step that makes the GHCR package public; an Apple-silicon Mac after `docker logout ghcr.io` | the trying-developer pastes the docker run line from examples/app/README.md, runs the Flutter app, taps Todo, adds "Buy milk", taps the dot, then ×, then presses Ctrl+C | the pull needs no login and the startup line prints; the Todo tile is second, under Counter, with the checklist icon and subtitle; the row ticks green with struck text, then goes, leaving the empty text; Ctrl+C stops the container and removes it | 04 flow trying-developer (Flutter, Docker) | must |
| E3 | e2e | after E1; a Mac | the trying-developer downloads demo-server-macos-arm64.zip from /releases?q=engine-v, unzips it in Finder, opens it, uses Open Anyway, opens it again; runs the iOS app with ORCA_APP_ID=todo and ORCA_PATH=home in Xcode; adds, ticks and deletes | it starts after the one Open Anyway step; the iOS Todo draws 04 screen 1 (grey dot, green check, struck grey text, ×) and every step works | 04 flow trying-developer (iOS, macOS download) | must |
| E4 | e2e | the Docker server from E2 running; an Android emulator | the trying-developer runs `task example:android:run APP=todo PAGE=home`, adds a 3-line text, ticks it, deletes it | the app reaches 10.0.2.2:8080 and draws 04 screen 1; the long text wraps with the dot and × on its first line | 04 flow trying-developer (Android, Docker) | should |

### Traceability
| Claim or part | Cases |
|---|---|
| 02 claim 1: trying developers start the demo server, Todo included, with one command and no setup | I4, I1, E2, E3, E4 |
| 02 claim 2: a complete public release, with notes, from one engine tag | E1 |
| 02 claim 3: the first tag's release serves the Todo unaided, then 2 weeks of counts | E1; the counts are under Uncovered |
| 02 claim 4 (q1): 25 pulls and downloads in 2 weeks keep the image and binaries | none needed: manual only, read at stage 12 (Uncovered) |
| 02 claim 5 (q2): Todo add, list, tick, delete; in memory; Flutter tile; iOS and Android; tick everywhere | U10, U3, U5, U6, U9, I3, E2, E3, E4 |
| 02 claim 6 (q3): ghcr.io/orca-gateway/demo-server, version and latest, run line in the notes and READMEs | U11, U15, E1 |
| 02 claim 7 (q4): Linux and Windows x64, macOS arm64 binaries | E1, I4, E3; the Windows start is under Uncovered |
| 02 claim 8 (q5): notes from engine/CHANGELOG.md's section; the root CHANGELOG.md links each package's | U15, U12, E1 |
| 02 claim 9 (appendix): the stub engine Dockerfile is gone | E1 (the verify job's image comes from the new root Dockerfile and serves the Todo) |
| 02 claim 10 (appendix): release on the tag, no draft, then a verify job asks the image and a binary for the Todo | E1 |
| 02 claim 11 (risk): unsigned downloads; the notes give the first-start step | U11, U15, E3 |
| 02 claim 12 (risk): a tag with no section would ship empty notes; the release stops before any change | U13, U14 |
| 06 component todo app | U1, U3, U4, U9 |
| 06 component demo server entry | I1, I4 |
| 06 component stop on signal | I2, E2 |
| 06 component Flutter tile | E2 |
| 06 component README step 1 + Todo row | U11 |
| 06 component iOS/Android apps | U10, E3, E4 |
| 06 component row layout | U7, E4 |
| 06 component page scroll | U8 |
| 06 component image recipe | E1, E2 |
| 06 component image build context | E1 |
| 06 component re-run path | none needed: manual only, used only if E1's run goes red (Uncovered) |
| 06 component notes check | U13, U14 |
| 06 data todos | U5, U6, I3 |
| 06 data "draft" | U2 |
| 06 data engine/CHANGELOG.md section | U13, U14, U15 |
| 06 data root CHANGELOG.md | U12 |
| 06 external ghcr.io/orca-gateway/demo-server, GitHub Releases | E1, E2, E3 |
| 06 job publish job | I4, U15, E1 |
| 06 job verify job | E1 |
| 06 sequences "I add, tick and delete a todo", "I start the demo server with one command", "I stop the demo server" | U3, U4, U6, I1, I2, I4, E2, E3, E4 |
| 06 sequences "I cut an engine release", "the tag makes the release", "it serves the Todo unaided" | U13, U14, U15, E1 |
| 06 sequences "the first tag goes red", "did anyone use it" | none needed: manual only (Uncovered) |
| 04 flow maintainer | E1, U13, U14 |
| 04 flow trying-developer (Flutter, Docker) | E2 |
| 04 flow trying-developer (iOS, macOS download) | E3 |
| 04 flow trying-developer (Android, Docker) | E4 |

### Uncovered, on purpose
- 02 claim 4, the "two weeks of pulls and downloads" half of claim 3, and 06 sequence "did anyone use it": manual
  only. The maintainer reads the GHCR and asset counts on day 14 at stage 12 and subtracts the verify job's 1 pull
  and 1 download. Nothing can run before then.
- 06 component re-run path and 06 sequence "the first tag goes red": manual only. They are tried only if E1's tag run
  goes red. Dispatching on a good release re-uploads with `--clobber`, which resets the download counts claim 4 reads.
- 02 claim 7, the Windows download starting: costs more than it protects. There is no Windows runner or machine in
  this pipeline. It comes from the same `bun build --compile` step as the Linux asset the verify job runs, and U11 and
  U15 check its "Run anyway" text.
- 04's "the downloads listen on this computer only" and "keyboard return adds": not reachable in v1. 06 has no part
  for either. (Note: gate 05 q3 settled the first, every interface, no engine change; 04 already said only Add adds
  when return cannot be sent.)

### Test file plan
- engine/test/todo-example.test.ts: U1, U2, U3, U4, U5, U6, U7, U8, U9, U10. It imports ../../examples/server/todo the
  way navigation.test.ts imports ecommerce. The list is module state, so U1 runs first.
- engine/test/launch-release.test.ts: U11, U12, U13, U14, U15. Script-level bun tests. U13 and U14 run
  scripts/release.sh in a scratch repo. U15 reads the notes step's `run:` script out of
  .github/workflows/engine-release.yml, so that step must stay one script; if it cannot, U15 moves into E1.
- engine/test/demo-server.test.ts: I1, I2, I3, I4. They spawn examples/server/index.ts with bun and run a compiled
  binary built for the host.
- .pipeline/launch-builds/10-uat.md: E1, E2, E3, E4 are hand checks at stage 10. E1 goes first because the others
  need its release and the public GHCR package.
- CI gap: .github/workflows/engine.yml runs only on engine/** and schema/**; a PR touching only examples/server, the
  READMEs, scripts/release.sh, Dockerfile or engine-release.yml skips these three files (question 1).
