# 05 · Technical design · launch-builds

## Front page

### In one breath
A todo.ts app joins the examples server: kept in memory; add, tick, delete send a replaceComponent.
A new engine-release.yml, on an engine-v* tag or a re-run, builds 3 downloads and the image,
publishes the release, then asks both for the Todo; release.sh checks the notes first.
5 resolved, 0 open.

### New for you
nothing new

### Trade-offs
2 needs you: first-tag failure, re-run vs PR rehearsal (recommended: re-run);
long lists, whole page scrolls vs only the list (recommended: whole page)

### Questions for you
1. If the first engine tag's run goes red? (default: you re-run it for that tag from Actions, as
   sdk-kotlin-publish allows; the other way, a PR rehearsal of the build, costs minutes per PR)
2. Long Todo lists? (default: the whole page scrolls and the footer follows the list, as the other
   examples scroll; 04 drew the footer at the screen's bottom; only-the-list scrolling is untried)
3. Downloads listen on every interface, as the engine does today? (default: yes, no engine change;
   Windows may ask about its firewall once; this-computer-only needs a new engine option)
4. Verify pulls the image logged in? (default: yes, so the first release goes green before you make
   the package public; an anonymous pull stays red until that User_Actions step)

## Appendix

### Components
v0 (naive architect, 2026-11-14):
- todo app: a page "home" with a TextField, an Add ElevatedButton, one Row per item (a GestureDetector
  `circle`/`check_circle` dot, Text with lineThrough when done, a GestureDetector `close`), the empty text and the
  footer. Server actions addTodo, toggleTodo and deleteTodo each answer with one replaceComponent of the keyed
  "todo-list" Column, built by the same function render uses; new: examples/server/todo.ts
- demo server entry: registers todoApp (10 apps), awaits engine.start() and prints "Orca demo server <engine/package.json
  version> on http://localhost:<server.port>"; existing: examples/server/index.ts
- Flutter tile: one `_Example` second in `_examples` (Todo, the checklist icon, appId todo, path home, the 04
  subtitle); existing: examples/app/lib/main.dart
- README step 1 (Docker, download with the first-start step, Bun) plus a Todo row under "Other example apps";
  existing: examples/server/README.md, examples/app/README.md, examples/app-ios/README.md, examples/app-android/README.md
- image recipe: distroless cc-debian12 copies the workflow's Linux binary, nonroot, EXPOSE 8080; the stub
  `bun build src/server.ts` goes; existing: Dockerfile (rewritten)
- publish job: on an engine-v* tag, one ubuntu runner runs `bun build --compile examples/server/index.ts` for
  bun-linux-x64, bun-windows-x64 and bun-darwin-arm64, zips the macOS one, pushes the image and creates the release;
  new: .github/workflows/engine-release.yml (job publish)
- verify job: runs after publish on a fresh runner and asks the image and the Linux download for the Todo page;
  new: .github/workflows/engine-release.yml (job verify)
- notes check: after the bump choice, greps engine/CHANGELOG.md for `^## X.Y.Z( |$)`; prints "ok notes" or stops
  before any change, and the summary gets the "then a GitHub release" line; existing: scripts/release.sh
- iOS and Android apps: no code change; they open the Todo with ORCA_APP_ID=todo ORCA_PATH=home
  (`task example:android:run APP=todo PAGE=home`); existing: examples/app-ios, examples/app-android

Added by issues:
- re-run path (issue 1): engine-release.yml also runs on workflow_dispatch with a `tag` input and checks out
  refs/tags/<tag>, as sdk-kotlin-publish.yml:25-30, 62-64 does; the release step creates the release, or, when it
  exists, uploads the assets with `--clobber` and rewrites the notes; the image push repeats as it is
- image build context (issue 1): the Dockerfile is built from a context holding only the Linux binary (the root
  .dockerignore drops examples/), so no COPY reaches into the tree
- stop on signal (issue 2): examples/server/index.ts stops the engine and exits on SIGINT and SIGTERM, so Ctrl+C
  ends `docker run` (the binary is PID 1 in distroless, which drops unhandled signals) and the downloads alike
- row layout (issue 4): each item Row has crossAxisAlignment "start" and its Text inside Expanded, and the TextField
  beside Add sits in Expanded (as examples/server/native-widgets.ts:167-172), so long text wraps and the dot and ×
  stay on the first line in all three apps (Flutter and Kotlin Rows give a bare child unbounded width)
- page scroll (issue 5): the page's Column sits in a SingleChildScrollView, as examples/server/server-actions.ts:127
  does, so rows past the screen's height (about six with the keyboard up) can still be ticked and deleted; the
  footer follows the list instead of sitting at the screen's bottom (recommended, needs you: q 2)

### Data
v0 (naive architect, 2026-11-14):
- todos: a module-level array {id, text, done}, one per server, lost on stop; new: examples/server/todo.ts
- "draft": page state, a string, kept in step with the field by `onChange: SetState("draft", V.event("value"))` as
  native-widgets.ts does; new key on the todo page
- "## X.Y.Z - date" section: written in the PR before release.sh, read by the check and by the workflow; existing:
  engine/CHANGELOG.md (+ one section per tag)
- root changelog: the stale "[0.1.0] - Unreleased" body becomes links to engine/, sdk/, cli/ and each plugin's
  CHANGELOG.md; changed: CHANGELOG.md
- ghcr.io/orca-gateway/demo-server: tags X.Y.Z and latest, pushed with GITHUB_TOKEN (packages: write), label
  org.opencontainers.image.source set to the repo; new: GHCR package (external)
- release engine-vX.Y.Z: title "Engine X.Y.Z", notes = the 6-line Run block with the version filled in + the
  changelog section, 3 assets as in 04; new: GitHub Releases (external, contents: write)
- usage count: each asset's download_count (`gh api .../releases`) plus the total on the GHCR package page; existing
  GitHub data, read by hand on day 14
- manual step "make demo-server public after the first engine-v run"; changed: docs/User_Actions.md (workspace
  level, + entry)

Added by issues:
- todo id (issue 3): `crypto.randomUUID()` when the item is added, a string, never the array's length or an index;
  toggleTodo and deleteTodo take `{id: string}`, so an id never repeats, not even across a server restart

### Sequences
v0 (naive architect, 2026-11-14):
- "I add, tick and delete a todo": app → GET /api/v1/app/todo/page/home with demo-key → todo.ts renders the array
  (cachePolicy "none") → typing sets "draft" in the app → Add → serverAction addTodo{text: draft} → trimmed; a blank
  one returns no actions, otherwise pushed at the bottom → replaceComponent "todo-list" + setState "draft" to "".
  Dot → toggleTodo{id} flips done; × → deleteTodo{id} removes it (unknown id: no change) → replaceComponent
  "todo-list", which shows the empty text when nothing is left
- "I start the demo server with one command": README → `docker run ...:latest`, or download → unzip/chmod → Open
  Anyway / Run anyway → open → index.ts starts 10 apps → startup line → the app reaches localhost:8080 (the emulator
  uses 10.0.2.2)
- "I cut an engine release": write "## X.Y.Z" and merge → release.sh: 1, ⏎ → the grep passes (otherwise "stop ...
  Nothing was changed.") → summary, y → bump commit → npm publish → push engine-vX.Y.Z
- "the tag makes the release": tag push → publish job → 3 binaries → `docker build` with Dockerfile, push :X.Y.Z and
  :latest → awk takes the section, the Run block goes in front → `gh release create engine-vX.Y.Z --title "Engine
  X.Y.Z"` with 3 assets, published, no draft
- "it serves the Todo unaided": verify job → docker login with GITHUB_TOKEN → `docker run :X.Y.Z` → polls GET
  todo/page/home with x-api-key demo-key for up to 60 s, wanting 200 and "Nothing to do yet" → `gh release download`
  demo-server-linux-x64 → runs it with PORT=8081 → same GET → green. A red run leaves the release as it is (04).
- "did anyone use it": on day 14 the maintainer reads the counts, subtracts verify's 1 pull + 1 download, and
  compares with 25

Added by issues:
- "the first tag goes red" (issue 1): fix the workflow on main → Actions › Engine release › Run workflow, tag
  engine-vX.Y.Z → the same jobs on the tag's tree → the release is created, or completed with `--clobber` → verify
- "I stop the demo server" (issue 2): Ctrl+C in the `docker run` terminal → SIGINT → index.ts stops the engine and
  exits 0 → `--rm` removes the container, 8080 is free; `docker stop` sends SIGTERM, same path, no 10 s wait

### Not handled, on purpose
v0 (naive architect, 2026-11-14):
- Persistence and live updates: todos die with the server; another app sees a change only when it reopens the page
  (02, 04). A store or a push channel would each be one more part.
- Concurrency: actions run one at a time on Bun's single thread, so two apps cannot lose each other's change; a tap
  on a row already deleted elsewhere is "unknown id: no change".
- Abuse and size: no cap on the number of items or the text length beyond the 1 MB body limit and rateLimit 100/s,
  and demo-key is public. Fine for a demo kept in memory that a restart empties.
- Localhost-only downloads (04 open decision): Engine.start passes no hostname to Bun.serve, so the binaries listen
  on all interfaces (the LAN can reach them; Windows may ask about the firewall). Binding to localhost needs a
  hostname option in engine/src/core/engine.ts plus HOST=0.0.0.0 in the image; v0 takes the cheaper side.
- Private image after the first push: verify pulls logged in, so it is green while others still cannot pull. An
  anonymous pull would catch that but turns the first release red until the User_Actions step is done.
- macOS and Windows downloads are cross-compiled and never started by CI. If Apple silicon kills the cross-compiled
  binary, build it on a macos-14 runner (runner minutes); stage 10 tries both.
- amd64 image only (02 risk): arm64 needs buildx with QEMU or a second runner, after the count says it is used.
- Partial failure: npm already has the version when the tag runs, so a red publish job leaves npm without a release
  until a dispatch redoes it (issue 1). A slip inside the tag's own tree (the Dockerfile, examples/server) cannot be
  redone for that tag; it ships in the next patch.
- Hand-pushed tags skip release.sh's check, and the workflow re-checks neither the section nor the tag against
  engine/package.json. The grep and the awk read the heading separately and can drift; one shared script would be one
  more part.
- Verify only asks for the page: no add, tick or delete in CI, and no check that iOS and Android draw it; stage 10
  does that by hand.
- Counts: GHCR shows only a total, with no days and no users; a download that never starts still counts; no baseline
  (02 risk).
- Keyboard return does not add: TextField fires only onChange (engine/src/components/input/text-field.ts), so only
  Add adds (04's fallback).
- `docker build .` on a laptop needs the Linux binary built first (the Dockerfile serves the workflow only); `latest`
  moves on every engine tag, fine with one release line.

### Issues resolved
| # | Issue | Change | Trade-off |
|---|---|---|---|
| 1 | The first tag is the workflow's first run; a slip leaves it with no release | workflow_dispatch with a tag input; the release step tolerates an existing release; the image context is the binary | one manual dispatch if the first tag goes red, vs a PR rehearsal costing runner minutes (q1) |
| 2 | Ctrl+C does not stop the Docker demo server (PID 1 drops unhandled signals) | index.ts stops and exits on SIGINT and SIGTERM | same output: two lines of demo code, the run line unchanged |
| 3 | A reused todo id ticks or deletes the wrong item | ids from `crypto.randomUUID()`, never a length or an index | same output: the screen is the same; 36 characters per row's action |
| 4 | A long todo pushes × off screen in Flutter and Android | Text and TextField in Expanded, item Row crossAxisAlignment "start" | same output: the wrapped row 04 drew; one node per row |
| 5 | Rows past the screen's height cannot be reached (no scroll) | the page Column in a SingleChildScrollView; the footer follows the list | the footer moves up from 04's bottom edge, vs only the list scrolling, untried in the three apps (q2) |

### Open issues
none: the challenger's sixth pass found no issue worth a change at this size.
