# 12 · Deploy watch · native-parity-s7

## Front page

### In one breath
PR #52 is merged (4a7f389b, by you). 14 of its 15 checks were green; the map plugin's iOS run was
still queued. On main, Engine, Schema and SDK Swift CI are green; the rest were still running.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. After A: 13 to 16 skipped (no deploy target in config.json), as gate 10 said. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Checks
PR #52 (head 0ebffbeb): Codegen drift detection, Core tests (swift 5.10-jammy and 6.2-noble), SDK tests and example
(JDK 17 and 21), UI tests and example (iOS simulator), Flutter (3.47.9 and stable), engine test, the voice recorder and
video player Swift packages, and the three plugins' Gradle builds: success. orca_google_map Swift package (macOS, iOS
simulator) was queued at the merge and never ran on the PR; its macOS `swift build --build-tests` + `swift test` passed
locally on this head (28 tests). Main at 4a7f389b, read once at 2026-11-16 ~19:56Z: Engine, Schema and SDK Swift CI
success; SDK CI and SDK Kotlin CI in progress; Native Plugins CI queued. Not polled; step 8's PR runs them all again.

### Deploy
config.json: deploy stage and prod are null, store none. Versions move only through scripts/release.sh (the user).
For the user: the engine does not export ImageIcon from its barrels (own small PR); the cloud Go registry after step 6.

### Next
Step 8 (native-parity-s8) is rebased on main 4a7f389b; its task plan (stage 08) is being written.
