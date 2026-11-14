# 09 · Implementation · launch-builds

## Front page

### In one breath
group 2 of 2 · tasks: 1 green, 0 blocked · cases: 19 of 19 green · bun test: 730 pass, 1 fail
T5 Demo server: index.ts registers the Todo (10 apps), prints "Orca demo server <version> on
http://localhost:<port>", and stops with exit 0 on Ctrl+C and SIGTERM; I1-I4, compiled binary too.
The one fail is the baseline's: a test binds 8080, which another local process holds.

### New for you
nothing new

### Trade-offs
3 auto-decided: same output (handlers before start, engine.stop(), a clean test env)

### Questions for you
1. Blocked tasks: none.
2. This is the last group: `A` approves the stage. (default: approve)

## Appendix

### Group 1

#### Task T1 · Todo app page and Flutter tile
Files: examples/server/todo.ts (new) · engine/test/todo-example.test.ts (new) · examples/app/lib/main.dart
Cases: U1-U10 → green (10 pass; red first, todo.ts missing) · baseline unchanged
Changed: todoApp (id todo, page home "Todo", cachePolicy none, page state "draft"): SingleChildScrollView → Padding →
  Column with an Expanded TextField beside Add, todoList() keyed "todo-list", the footer; addTodo, toggleTodo and
  deleteTodo reply with todoList() as one replaceComponent; crypto.randomUUID() ids; resetTodos() for tests.
  main.dart: a Todo `_Example` second after Counter (Icons.checklist, todo/home, the 04 subtitle).
Decisions: 1. needs you: replaceComponent is in neither native vector; U10 accepts it after checking both native
  ActionExecutor sources list it (question 3) · 2. U3/U6 compare with a fresh GET after resolving V.static (same
  output) · 3. an unknown id replies with the unchanged list (smaller code)
Review fit: engine/tsconfig.tsbuildinfo changed outside the file list (a scratch tsc run), fixed
Review quality: pass
Not done: registering todoApp in examples/server/index.ts is T5's (group 2); the tile is checked by hand (E2)

#### Task T2 · README step 1 and Todo rows
Files: examples/server/README.md · examples/app/README.md · examples/app-ios/README.md · examples/app-android/README.md
  · engine/test/launch-readmes.test.ts (new)
Cases: U11 → green (6 pass; 6 fail before the README edits) · baseline unchanged
Changed: step 1 "Start the demo server. Pick one:" a. Docker `:latest`, b. the newest Engine release
  (/releases?q=engine-v) with chmod +x, the macOS zip, Open Anyway, Run anyway, c. `task example:dev:server`, then
  the Ready line; a `| Todo | todo | home | add, tick, delete |` row in app-ios and app-android; app-android also
  `task example:android:run APP=todo PAGE=home`; examples/server/README.md's "## Running" opens with the block.
Decisions: 1. the Ready line as a code span (plain quotes hide <version>) · 2. `./demo-server-linux-x64` after
  chmod +x · 3. the docker line on one line (all same output)
Review fit: pass
Review quality: pass
Not done: examples/server/README.md's "## Examples" table lists no todo.ts (out of scope, said the fit review: the
  table already missed native-widgets.ts and record-page.ts at baseline)

#### Task T3 · Notes check and changelog links
Files: scripts/release.sh · CHANGELOG.md · engine/CHANGELOG.md · engine/test/launch-release.test.ts (new)
Cases: U12, U13, U14 → green · baseline unchanged (shellcheck: the same 3 SC2005 notes, now lines 516-522)
Changed: release.sh `check_engine_notes` after the engine's version prompt: `^## X.Y.Z( |$)` with dots escaped;
  "ok notes" or a 3-line stop to stderr, exit 1, before any change; the summary line "then a GitHub release: notes,
  demo image, 3 downloads". Root CHANGELOG.md: per-package links (7 files). engine/CHANGELOG.md: "## 0.3.5 -
  2026-11-14" with 3 Added bullets. Tests in a mkdtemp scratch repo with a bare origin and a stub npm.
Decisions: 1. the check after each package's prompt, normal and pre-release · 2. stop to stderr in red, ok in green
  · 3. the real node, only npm stubbed (all same output)
Review fit: pass
Review quality: pass
Not done: nothing

#### Task T4 · Release workflow, image recipe, CI paths
Files: .github/workflows/engine-release.yml (new) · Dockerfile · .github/workflows/engine.yml ·
  engine/test/engine-release-notes.test.ts (new)
Cases: U15 → green (1 pass, 29 expects; red first, ENOENT) · baseline unchanged
Changed: "Engine release" on an engine-v* tag or a dispatch with `tag`; checks out refs/tags/<tag>; version must
  equal engine/package.json's. publish: 3 binaries (bun build --compile), the image from a binary-only context, the
  source label, :<version> and :latest; one-script notes step (exact `## <version>( |$)`, a missing section fails);
  gh release create, or upload --clobber + edit on a re-run. verify (own job): logged-in pull, 60 s Todo GET on the
  image, then on the downloaded Linux binary (PORT=8081). Dockerfile: distroless, /app/demo-server, nonroot, 8080.
  engine.yml: 7 paths added to push and pull_request.
Decisions: 1. the Run block as a ### heading, a sh block and list items, then --- · 2. the macOS zip holds one file
  `demo-server` · 3. a per-tag concurrency group, as sdk-kotlin-publish.yml (all same output)
Review fit: pass
Review quality: pass
Not done: not run here: the cross-compile (target not cached), actionlint (not installed), docker; both workflows
  parse (Bun.YAML) and every run: script passes bash -n

### Group 2

#### Task T5 · Demo server registers Todo, stops cleanly
Files: examples/server/index.ts · engine/test/demo-server.test.ts (new)
Cases: I1, I2, I3, I4 → green (4 pass; red before, each timed out waiting for the new startup line) · baseline
  unchanged (730 pass, 1 fail; no demo-server process left; the mkdtemp dir removed)
Changed: index.ts registers todoApp as the 10th app with the same middleware loop; imports engine/package.json for
  the version (the compile embeds it); awaits engine.start() and prints "Orca demo server <version> on
  http://localhost:<server.port>"; a "- todo: /api/v1/app/todo/page/home" route line; SIGINT and SIGTERM call
  engine.stop() and exit 0. Tests: Bun.spawn on a free port (never 8080, 8091, 6363), a 15 s wait for the startup
  line, leftovers killed in afterEach; I3 POSTs /api/v1/app/todo/action; I4 compiles into a mkdtemp dir, runs there.
Decisions: 1. handlers registered just before `await engine.start()` · 2. engine.stop(), not close() · 3. spawned
  servers drop REDIS_URL, ORCA_FALLBACK_POLICY, ORCA_MIN_SDK_VERSION (all same output)
Review fit: pass
Review quality: pass
Not done: nothing

### Test run
`cd engine && bun test` · 730 pass, 1 fail, 731 tests across 34 files · server.test.ts › (unnamed): EADDRINUSE on
8080 (baseline; another local process holds 8080). Group 1's run: 726 pass, 1 fail, 727 across 33 files.
`shellcheck scripts/release.sh`: the 3 baseline SC2005 notes. `cd examples/app && flutter analyze`: No issues found!

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- E1 needs a real engine tag: the 0.3.5 section is written (dated 2026-11-14; move the date if the release is later).
- The GHCR package starts private: the docs/User_Actions.md entry (main session) makes it public before E2.
- Not tried locally: the cross-compile to linux-x64, windows-x64 and darwin-arm64, the docker build, actionlint.
- The verify job's Todo GET needs T5's index.ts (done in group 2) and a real tag.
- The macOS and Windows downloads are cross-compiled and never started by CI; E3 starts the macOS one by hand.
