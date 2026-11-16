# 12 · Deploy watch · native-parity-s6

## Front page

### In one breath
PR #50 is merged (06422c1e, by you). All 11 checks on the PR were green. On main at the merge,
Engine, Schema, SDK, SDK Swift and SDK Kotlin CI are green. Nothing is deployed or published.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. After A: 13 to 16 skipped (no deploy target in config.json), as gate 10 said. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Checks
PR #50 (head 8360c7ad): 11 of 11 checks success. Main at the merge commit 06422c1e: Engine CI, Schema CI, SDK CI,
SDK Swift CI and SDK Kotlin CI success; Native Plugins CI was still queued there, and passed on the next main commit
2ca21c9e (PR #51, the map plugin), which builds the plugins against the same SDKs (read once, not polled).

### Deploy
config.json: deploy stage and prod are null, store none. Versions move only through scripts/release.sh (the user).
For the user: regenerate the cloud's Go registry (`tools/gen-go-registry.ts`; four widgets gained `ios`).

### Next
Step 7 (native-parity-s7) is rebased on main 2ca21c9e and opens its own PR against main.
