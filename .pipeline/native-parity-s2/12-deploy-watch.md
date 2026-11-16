# 12 · Deploy watch · native-parity-s2

## Front page

### In one breath
PR #36 is merged (3cdeef7, by you). Every check was green on the PR, including the iOS simulator UI
job on Xcode 16.4 and both Flutter versions. On main, Engine and Schema CI are green at the merge;
the SDK jobs were still running when this was written. Nothing is deployed or published.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. After A: 13 to 16 skipped (no deploy target in config.json), as gate 10 said. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Checks
PR #36 (head 04363bd): Codegen drift detection, Core tests (swift 5.10-jammy and 6.2-noble, linux), SDK tests and
example (JDK 17 and 21), UI tests and example (iOS simulator, Xcode 16.4), Flutter (3.47.9 and stable), engine test:
all pass. Main at the merge commit 3cdeef7: Engine CI and Schema CI success; SDK CI, SDK Swift CI and SDK Kotlin CI in
progress (read once, not polled; step 3's PR shows main's state again).

### Deploy
config.json: deploy stage and prod are null, store none. Versions move only through scripts/release.sh (the user).
