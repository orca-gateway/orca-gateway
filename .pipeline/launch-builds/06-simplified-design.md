# 06 · Simplified design · launch-builds

## Front page

### In one breath
parts: 20 → 20: components 12, stores 4, external dependencies 2, background jobs 2; nothing went.
The one cut offered, folding the verify job into the publish job, stays out by memory: your call
"then a verify job" (2026-11-07), so a flaky Todo check re-runs alone, without rebuilding.

### New for you
nothing new

### Trade-offs
1 auto-decided: keep a separate verify job (memory "central-release-mode", your call, 2026-11-07)

### Questions for you
none: the one priced cut was decided by memory (Trade-offs); every other proposal was declined.

## Appendix

Simplifier (pipeline:design-simplifier, 2026-11-14) counted 20 parts, as I did; it offered one cut and declined ten.

### Simplifications applied
| What | Instead of | Saves | Costs |
|---|---|---|---|
| none | | | |

### Declined, and why
- One release job: the verify steps at the end of the publish job (saves a job, its checkout and second login,
  about 15 lines of YAML). Kept apart by memory "central-release-mode" (your call 2026-11-07, "then a verify
  job"): a flaky 60 s poll would re-run the 3 builds, the push and a `--clobber` upload that resets download counts.
- Verify only the image, not the download: 02 decided "runs a binary"; only the download proves the asset starts.
- Drop the Docker image (4 parts): 01 and 02 chose it; `docker run` starts two of 04's three developer flows.
- `--init` in the run lines instead of stop on signal: issue 2 back; saves no part.
- A counter for todo ids: issue 3 back; no smaller than `crypto.randomUUID()`.
- Drop the re-run path: issue 1 back; gate 05 answer 1 took it.
- Drop row layout or page scroll: issue 4 or issue 5 back.
- Fold the issue additions and the no-code iOS/Android entry into their hosts: a relabel, no code removed.
- Step 1 once in examples/server/README.md, linked from the app READMEs: saves about 40 repeated lines, but 04 drew
  the block in each README and every developer flow gains a stop.
- The notes check in the workflow instead of release.sh: the tag runs after npm has the version, so a missing
  section could no longer stop "before any change" (03 q2).
- Delete root CHANGELOG.md instead of linking it: the same one-file edit; 02 q5 chose the links.
- Drop the "draft" state: TextField fires only onChange, so Add has no other way to send the text.

### The design, simplified
Components (12):
- todo app (new examples/server/todo.ts): page "home", cachePolicy "none", inside a SingleChildScrollView (issue 5).
  A TextField (onChange SetState "draft") in Expanded beside an Add ElevatedButton; below, a keyed "todo-list" Column
  of item Rows (crossAxisAlignment "start"): a GestureDetector dot (`circle` grey / `check_circle` green), the Text in
  Expanded (grey with lineThrough when done) and a GestureDetector `close` (issue 4); then the empty text "Nothing to
  do yet. Add one above." and the footer "Kept on the server until it stops.", which follows the list. addTodo{text},
  toggleTodo{id}, deleteTodo{id} each answer with one replaceComponent "todo-list", built by the function render uses.
- demo server entry (examples/server/index.ts): registers todoApp (10 apps), awaits engine.start(), prints "Orca demo
  server <engine/package.json version> on http://localhost:<port>".
- stop on signal (issue 2): index.ts stops the engine and exits 0 on SIGINT and SIGTERM.
- Flutter tile (examples/app/lib/main.dart): an `_Example` second in `_examples` (Todo, checklist icon, appId todo,
  path home, "Add, tick and delete items, kept in server memory").
- README step 1 + Todo row (examples/server, app, app-ios, app-android READMEs): Docker `:latest`, a download from
  /releases?q=engine-v with the first-start step, or Bun, then "Ready when it prints ..."; a Todo row in app-ios and
  app-android's "Other example apps".
- iOS/Android apps: no code change; ORCA_APP_ID=todo ORCA_PATH=home, or `task example:android:run APP=todo PAGE=home`.
- row layout (issue 4) and page scroll (issue 5): as in the todo app above, counted apart as 05 named them.
- image recipe (root Dockerfile rewritten): distroless cc-debian12 copies the Linux binary, nonroot, EXPOSE 8080; the
  stub `bun build src/server.ts` goes.
- image build context (issue 1): `docker build` gets a context holding only the Linux binary (.dockerignore drops
  examples/).
- re-run path (issue 1): workflow_dispatch with a `tag` input checks out refs/tags/<tag>, as sdk-kotlin-publish.yml
  does; the release step creates the release, or, when it exists, uploads with `--clobber` and rewrites the notes.
- notes check (scripts/release.sh): after the bump choice, greps engine/CHANGELOG.md for `^## X.Y.Z( |$)`, prints
  "ok notes" or stops before any change; the summary gets the "then a GitHub release" line.
Data (4):
- todos: a module-level array {id from `crypto.randomUUID()` (issue 3), text, done}; new at the bottom; lost on stop.
- "draft": page state, a string.
- engine/CHANGELOG.md "## X.Y.Z - date" section per tag: written in the PR before release.sh; read by the check and
  by the publish job's awk.
- root CHANGELOG.md: the stale 0.1.0 body becomes links to engine/, sdk/, cli/ and each plugin's CHANGELOG.md.
External dependencies (2):
- ghcr.io/orca-gateway/demo-server: tags X.Y.Z and latest, pushed with GITHUB_TOKEN (packages: write), label
  org.opencontainers.image.source; made public by hand per a docs/User_Actions.md entry.
- GitHub Releases: engine-vX.Y.Z "Engine X.Y.Z", notes = the Run block + the changelog section, 3 assets (contents: write).
Background jobs (2):
- publish job (.github/workflows/engine-release.yml), on an engine-v* tag or a dispatch: `bun build --compile
  examples/server/index.ts` for bun-linux-x64, bun-windows-x64 and bun-darwin-arm64 (zipped), image build and push,
  the release.
- verify job (same file), after publish on a fresh runner: logged-in pull of :X.Y.Z, the Linux download, the Todo GET.
Sequences:
- "I add, tick and delete a todo": app → GET /api/v1/app/todo/page/home (demo-key) → todo.ts renders the array →
  typing sets "draft" → Add → addTodo{text: draft} → trimmed; blank returns no actions, else pushed at the bottom →
  replaceComponent "todo-list" + setState "draft" ""; dot → toggleTodo{id}, × → deleteTodo{id} (unknown id: no
  change) → replaceComponent "todo-list" (the empty text when none are left).
- "I start the demo server with one command": README → `docker run --rm -p 8080:8080 ...:latest`, or download →
  unzip/chmod → Open Anyway / Run anyway → open → index.ts starts 10 apps → startup line → the app reaches
  localhost:8080 (the emulator uses 10.0.2.2).
- "I stop the demo server": Ctrl+C → SIGINT → index.ts stops the engine, exits 0 → `--rm` removes the container;
  `docker stop` → SIGTERM, same path.
- "I cut an engine release": write "## X.Y.Z" and merge → release.sh: 1, ⏎ → the notes check passes (else "stop ...
  Nothing was changed.") → summary, y → bump commit → npm publish → push engine-vX.Y.Z.
- "the tag makes the release": tag push → publish job → 3 binaries → docker build from the binary-only context →
  push :X.Y.Z and :latest → awk takes the section, the Run block in front → `gh release create engine-vX.Y.Z --title
  "Engine X.Y.Z"` with 3 assets, published.
- "it serves the Todo unaided": verify job → docker login (GITHUB_TOKEN) → `docker run :X.Y.Z` → polls GET
  todo/page/home with x-api-key demo-key up to 60 s for 200 and "Nothing to do yet" → `gh release download`
  demo-server-linux-x64 → run with PORT=8081 → same GET → green; a red run leaves the release as it is.
- "the first tag goes red": fix the workflow on main → Actions › Engine release › Run workflow, tag engine-vX.Y.Z →
  the jobs on the tag's tree → the release is created, or completed with `--clobber` → verify.
- "did anyone use it": on day 14 the maintainer reads the counts → subtracts verify's 1 pull + 1 download → vs 25.
