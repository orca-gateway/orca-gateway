# 12 · Deploy watch · native-sdk-s1

## Front page

### In one breath
PR 2 is merged: you merged it at 09:35 UTC as merge commit b87a6ed. All 5 checks were green on
its head. Main CI on b87a6ed is green in all 4 workflows, including the new SDK Swift CI on Linux
with Swift 5.10 and 6.2. Nothing is published; the core has no runtime to watch until S2.

### New for you
Nothing new.

### Trade-offs
1 needs you: merge kept as a merge commit, not squashed per gate 12; default leave it (as PR 1).
2 needs you: stages 13-16, skip (no runtime surface) vs run; default skip, as for S0.

### Questions for you
1. Rest of the S1 pipeline history (gates 10-12): land it how? (default: first commit of S2)
2. PR #3 now conflicts with main on schema.yml: have its session merge main in? (default: yes)
3. Next slice: start S2 (OrcaClient, renderer, counter page) as native-sdk-s2? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR 2
https://github.com/orca-gateway/orca-gateway/pull/2, head 6a0fafb, merged 2026-11-06T09:35:37Z by
amrebada as merge commit b87a6ed (all 8 branch commits kept). Checks on the head:
| Workflow | Job | Result |
|---|---|---|
| Engine CI | test | success |
| SDK CI | test | success |
| SDK Swift CI | Core tests (swift 5.10-jammy, linux) | success |
| SDK Swift CI | Core tests (swift 6.2-noble, linux) | success |
| Schema CI | Codegen drift detection (incl. Generated.swift) | success |

### Main after the merge
`gh run list --branch main` on b87a6ed: SDK Swift CI, Engine CI, Schema CI and SDK CI all
completed with success. Auto-fix was not turned on: PR 2 was already merged when gate 10 closed.

### Gate 12 decision vs what happened
Gate 12 of native-sdk chose "squash, one commit per slice"; PR 1 and PR 2 were both merged as
merge commits. History is linear apart from the merge commits, each slice's commits are
task-sized, and nothing on main needs undoing. Default: leave both as they are, and either
squash from S2 on or update the decision to "merge commit".

### Related PR
https://github.com/orca-gateway/orca-gateway/pull/3 (the follow-up approved at gate 09, from its
own session): Flutter `formatDate`, a `generated.dart` drift check in Schema CI, and `release.sh`
regenerating it. Open; now CONFLICTING with main because both PRs edit the path filters and
the tail of `.github/workflows/schema.yml`. Keeping both sides resolves it.

### Pipeline history not yet on main
Gate 10 approval, the stage 11 skip, this artifact and its card. They are committed locally on
feat/native-sdk-s1 after 6a0fafb and are not pushed.

### Nothing to observe yet
S1 ships no runtime: no app, no network call, no published package. Observation (13-16) starts
with S2, the first slice a phone can show, just as S0 skipped it.
