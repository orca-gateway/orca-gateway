# 12 · Deploy watch · launch-builds

## Front page

### In one breath
PR #27 and the review fixes in PR #28 are in main (bd5c486, 13:37Z); #28's 4 checks passed.
This slice ships with your engine 0.3.5 release: no engine-v0.3.5 tag, release or image yet.
Once you have released and made the image public, I read the run and the release once (E1).

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Release 0.3.5 now: User_Actions "Epic 23: Launch builds", Steps 1-2. Yours: it publishes.
   Say "released" and I read the Engine release run, the release page and the image tags (E1).
   (default: wait for your word)
2. E2-E4 after the release: yours (E4 mine on your word). (default: as on card 10)
3. On A after E1 is green: 13-16 skipped (nothing deployed; the release is the ship), rows 23.3,
   23.6, 23.7, 23.8 ✅ in the epic plan, the close note in a small PR. (default: yes)
4. Day 14 (2026-11-28): Step 4's counts; under 25 drops the image and downloads. (default: you
   read them, or tell me to)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #27 and PR #28
- PR #27 https://github.com/orca-gateway/orca-gateway/pull/27: merged 2026-11-14T09:50:51Z as 74778c4 (head
  9779b5a, the gate 09 approval).
- PR #28 https://github.com/orca-gateway/orca-gateway/pull/28, the 7 review fixes: merged 2026-11-14T13:37:20Z
  as bd5c486 (head d3e44bc). Gate 10 approved with your word "merged"; 11 skipped by default.
- Read once at this card (`gh pr checks 28`): 4 passing, 0 failing, 0 pending (Codegen drift detection and the
  engine `test` job, each twice). `gh run list --workflow engine-release.yml`: no run yet.

### E1, read once after your "released" (2026-11-15): green
- "Engine release" run 43601844026 (push of engine-v0.3.5, 2026-11-14T13:51Z): success. Jobs: "Build the demo
  server, push the image, publish the release", "Ask the image and the Linux download for the Todo page", "Start
  the macOS download on Apple silicon and ask it for the Todo page": all three success, first run, no re-run.
- Release "Engine 0.3.5" (engine-v0.3.5, Latest, not a draft, not a pre-release): the "Run the demo server" block
  (`docker run --rm -p 8080:8080 ghcr.io/orca-gateway/demo-server:0.3.5`, Open Anyway, Run anyway), `---`, then
  the changelog's three Added bullets. Assets: demo-server-linux-x64, demo-server-macos-arm64.zip,
  demo-server-windows-x64.exe.
- `ghcr.io/orca-gateway/demo-server`: :0.3.5 and :latest both sha256:34251c23269e…0a0d4b, read with an anonymous
  registry token (manifest HEAD only, nothing pulled): public.
- Your own pull on the Mac worked (Apple silicon, the amd64 warning as expected); its `docker run -p 8080:8080`
  hit "port is already allocated" (one of your containers holds 8080), not a fault of the image.

### The epic plan rows this slice closes
`.claude/plans/orcagateway-epics.md` lines 514-519: 23.3 Todo app example, 23.6 Docker image publish, 23.7 Single
binary build, 23.8 GitHub release. Their text names `ghcr.io/orcagateway/engine:latest` and a `v0.1.0` tag; the
close note marks them ✅ with what shipped instead (`ghcr.io/orca-gateway/demo-server`, `engine-v<X>` tags).

### Closed (gate 12, your "released" and your standing rule, 2026-11-15)
Engine 0.3.5 released by you with scripts/release.sh; E1 green (above). Gate 12 approved: question 1 answered by
"released", questions 2-4 minor under your standing rule, all defaults. Stages 13-16 skipped ("launch-builds has no
deployed service; the engine 0.3.5 release is the ship"). Epic rows 23.3, 23.6, 23.7 and 23.8 read ✅ Done in
`.claude/plans/orcagateway-epics.md` with what shipped (`ghcr.io/orca-gateway/demo-server`, `engine-v<X.Y.Z>`
releases), not the planned `ghcr.io/orcagateway/engine:latest` and `v0.1.0`.

Still yours:
- E2-E4 (stage 10's table): the Flutter app via Docker on 8080 (your 8080 container stopped first, or the app
  pointed at another port), the iOS app via the macOS download, the Android app via Docker.
- Day 14, 2026-11-28 (User_Actions Step 4): image pulls plus downloads, minus the verify jobs' own 1 pull, 1 Linux
  and 1 macOS download; under 25 drops the image and the downloads.
- The main checkout (`open-source/`, on main) is 234+ commits behind origin with your 2 uncommitted edits; a
  `git pull` there is yours. `~/orca-release` (the release clone) can be deleted.
