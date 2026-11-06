# 12 · Deploy watch · native-sdk-s6

## Front page

### In one breath
PR #12 is merged (388f1b5), with all 7 PR checks green.
Green on the PR: Kotlin core on JDK 17 and 21, Swift core on 5.10 and 6.2, Flutter SDK, Engine.
On main after the merge: Engine and Schema passed; Kotlin, Swift and Flutter still running.
Nothing deploys or releases: sdk-kotlin joins release.sh at S10. T6.1 and T6.2 are green on ubuntu.

### New for you
Nothing new.

### Trade-offs
1 done: UAT passed on your word ("A" at gate 10).
2 noted: the sdk 0.3.3 changelog is on main; pub.dev shows it from the next sdk release.

### Questions for you
1. After A: 13-16 are skipped (nothing runs as a service) and S6 is closed. (default: yes)
2. Mark 23b.27a done in the epic plan, outside the repo? (default: yes, at A)
3. Next: S7 (23b.27b), Compose UI, the counter on the Pixel 3a emulator. (default: when you say go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #12
https://github.com/orca-gateway/orca-gateway/pull/12, merged at 23:00:21Z as 388f1b5. The PR's
7 checks, all success: Codegen drift detection (Schema), Engine `test`, SDK `test` (Flutter),
Core tests on swift 5.10-jammy and 6.2-noble, Core tests on JDK 17 and 21 (the new
`sdk-kotlin.yml`; about a minute each, cold Gradle cache). Each workflow also ran green for the
push of 2b050c1, and for the PR at 4308a06 (the stage 10 commit).

### Main after the merge (388f1b5)
| Workflow | State at writing |
|---|---|
| Engine CI | success |
| Schema CI | success |
| SDK Kotlin CI | running |
| SDK Swift CI | running |
| SDK CI (Flutter) | running |
The same commits passed all three on the PR; the merge adds no code.

### Cleanup
- The Gradle daemon this session started is stopped. No servers ran in S6; ports 8080, 8091 and
  6363 were not touched.
- The differential harness (Swift and Kotlin runners, inputs, outputs) stays in the session
  scratchpad only.

### What S6 leaves for later
- 23b.33 (after S10): both native SDKs match Dart in six string, regex and number corners, with a
  render fixture each.
- Effects inside a `parallel` group may come in a different order on Android than on iOS; the state
  and the set of effects match. No fixture pins that order.
- S7: the OkHttp `OrcaClient` implements `ActionClient`, and the HTTP assertions of Swift's
  server-action test (method, URL, headers) come back with it.
- S8: DevTools reporting from the store, the executor and the renderer.
- This Mac has no JDK 17; only CI builds on the bytecode floor's own JDK.
- From S5, still yours: `docs-site/sidebars.ts` lacks `'guides/ios-sdk',`.

### Next
On A, stages 13-16 are skipped with the reason "S6 has no deployed surface; skipped by the default
accepted at gate 12 (A)", S6 is closed, and row 23b.27a is ticked (question 2). S7 (23b.27b: the
`sdk` Android library with Compose, OkHttp `OrcaClient` and the 412 handshake, the 15 core widgets,
`OrcaApp` on NavHost, `examples/app-android`) starts from main when you say go.
