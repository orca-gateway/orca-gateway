# Issues · launch-builds · stage 05

One entry per challenger call, in order. The design before entry n is v0 plus entries 1 to n-1.
At most 5 entries per round; what would come next waits under "Open issues" in `05-tech-design.md`.

## Issue 1 · The first tag is the workflow's first run
Options: a) workflow_dispatch with a tag input, and a release step that tolerates an existing release · b) a pull_request run of the same build, image and Todo check, with no push and no release
Chosen: a) (recommended, needs you: q 1)
Why: the smallest fix; it follows sdk-kotlin-publish.yml (dispatch with a tag, checks out the tag); b) costs runner minutes on every such PR and still cannot try the GHCR push or `gh release create`
Changed: Components + re-run path, + image build context (.dockerignore drops examples/); Sequences + "the first tag goes red"; Not handled "Partial failure" narrowed

## Issue 2 · Ctrl+C does not stop the Docker demo server
Options: a) two `process.on` lines in examples/server/index.ts (SIGINT, SIGTERM) · b) `--init` in every run line (4 READMEs and the notes' Run block)
Chosen: a) (same output)
Why: two lines of demo code cover the image and the 3 downloads; the run line stays as 04 drew it, and a bare line typed by hand still stops
Changed: Components + stop on signal; Sequences + "I stop the demo server"

## Issue 3 · A reused todo id ticks or deletes the wrong item
Options: a) a module-level counter from 1, number ids · b) `crypto.randomUUID()`, string ids
Chosen: b) (same output)
Why: as small as the counter and built into Bun; ids never repeat even across a restart, which the counter would reuse for a page left open
Changed: Data + todo id

## Issue 4 · A long todo pushes × off the screen
Options: a) Expanded around the Text (and the TextField), item Row crossAxisAlignment "start" · b) addTodo cuts the text to about 30 characters
Chosen: a) (same output)
Why: gives the wrapped row 04 drew; all three apps draw Expanded; b) cuts what the user typed and still overflows with large fonts
Changed: Components + row layout

## Issue 5 · Rows past the screen's height cannot be reached
Options: a) SingleChildScrollView around the whole page Column · b) only the list scrolls: "todo-list" becomes a ListView inside Expanded
Chosen: a) (recommended, needs you: q 2)
Why: the smallest fix and the pattern the examples already use (server-actions.ts:127, native-widgets.ts:153); b) keeps 04's footer at the bottom but a ListView inside Expanded is untried in the three apps
Changed: Components + page scroll; the footer follows the list (a change from 04's screen 1)
