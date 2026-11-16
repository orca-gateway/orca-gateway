# 12 · Deploy watch · native-parity-s3

## Front page

### In one breath
PR #40 is merged (6a7f0e0, by you). Every check was green on the PR, including the iOS simulator UI
job and both Flutter versions. On main at the merge, Engine, Schema, SDK, SDK Swift and SDK Kotlin
CI are all green. Nothing is deployed or published.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. After A: 13 to 16 skipped (no deploy target in config.json), as gate 10 said. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Checks
PR #40 (head 2179ff2): Codegen drift detection, Core tests (swift 5.10-jammy and 6.2-noble, linux), SDK tests and
example (JDK 17 and 21), UI tests and example (iOS simulator), Flutter (3.47.9 and stable), engine test: all pass.
Main at the merge commit 6a7f0e0 (on top of PR #37's 4f225e0): Engine CI, Schema CI, SDK CI, SDK Swift CI and SDK
Kotlin CI success (read once, not polled).

### Deploy
config.json: deploy stage and prod are null, store none. Versions move only through scripts/release.sh (the user).

### Next
Step 4 (native-parity-s4) rebases on main 6a7f0e0 between its groups and opens its own PR against main.
