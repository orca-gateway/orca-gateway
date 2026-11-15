# 12 · Deploy watch · native-parity-s1

## Front page

### In one breath
PR #33 is merged (82e9027, by you). Every check was green on the PR, including the iOS simulator UI
job on Xcode 16.4, and the merge commit on main is green too. Nothing is deployed or published:
the SDKs ship only through release.sh, which is yours to run.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. After A: 13 to 16 skipped (no deploy target in config.json), as gate 10 said. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Checks
PR #33 (head b9e828e): Codegen drift detection, Core tests (swift 5.10-jammy and 6.2-noble, linux), SDK tests and
example (JDK 17 and 21), UI tests and example (iOS simulator, macos-15, Xcode 16.4), Flutter (3.47.9 and stable),
engine test: all pass. Main at the merge commit 82e9027: the same jobs (the iOS UI job runs on pull requests only),
all completed with success.

### Deploy
config.json: deploy stage and prod are null, store none. Versions move only through scripts/release.sh (the user).
