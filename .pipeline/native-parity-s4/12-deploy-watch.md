# 12 · Deploy watch · native-parity-s4

## Front page

### In one breath
PR #44 is merged (992652c, by you). Every check was green on the PR after one rerun of the JDK 17
job (a Maven Central rate limit). On main at the merge, Engine, Schema, SDK, SDK Swift and SDK
Kotlin CI are all green. Nothing is deployed or published.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. After A: 13 to 16 skipped (no deploy target in config.json), as gate 10 said. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Checks
PR #44 (head d16d855): Codegen drift detection, Core tests (swift 5.10-jammy and 6.2-noble, linux), SDK tests and
example (JDK 17 after one rerun, and JDK 21), UI tests and example (iOS simulator), Flutter (3.47.9 and stable), engine
test: all pass. Main at the merge commit 992652c and after PR #43 (8a7276f): Engine CI, Schema CI, SDK CI, SDK Swift CI
and SDK Kotlin CI success (read once, not polled).

### Deploy
config.json: deploy stage and prod are null, store none. Versions move only through scripts/release.sh (the user).

### Next
Step 5 (native-parity-s5) rebases on main 8a7276f and opens its own PR against main.
