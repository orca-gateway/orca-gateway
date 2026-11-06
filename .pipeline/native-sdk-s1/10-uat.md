# 10 · UAT · native-sdk-s1

## Front page

### In one breath
S1 has nothing a person can see. It is a Swift library and its tests; the first screen is S2's
counter page. PR 2 is open against main: 7 commits plus .pipeline/, mergeable. CI started with
2 checks green and 8 pending, including the new SDK Swift CI on Linux. Nothing is merged.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: accept on my run plus the tests (your call, 2026-11-06, native-sdk 10).
2 auto-decided: 11 Release skipped, publish after S2 (your call, 2026-11-06, native-sdk 10).
3 auto-decided: squash-merge, one commit per slice (your call, 2026-11-06, native-sdk 12).

### Questions for you
1. Turn on Auto-fix for PR 2, as for PR 1? (default: yes, on approve)
2. Stage 12 watch is PR 2's CI: schema drift, SDK Swift CI x2, engine, SDK. (default: yes)
3. Merge stays yours after green CI; I do not merge. (default: yes, squash per gate 12)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

PR: https://github.com/orca-gateway/orca-gateway/pull/2, `feat/native-sdk-s1` → `main`, 7 commits
(edeb720 … ab9a3c8 plus two pipeline commits), mergeable. State at opening: 2 checks passing,
8 pending, 0 failing.

Walk, 3 commands from `open-source/` (what I ran before the push):
1. `task sdk-swift:test` → 49 tests, 0 failures (macOS, Swift 6.4.2)
2. the job's steps in `swift:5.10-jammy` and `swift:6.2-noble` (docker, read-only mount) →
   `swift build --build-tests` with no warnings, then 49 tests, 0 failures, on each
3. `bun run schema/codegen.ts && git diff --exit-code` → registry, `generated.dart` and
   `Generated.swift` unchanged; caps hash `38cde8c4…4c36`

A quick look at what S2 will use, from the tests: fixture 22's template renders from page state,
fixture 06 resolves `theme.color` through a dotted path, and a `setState` reducer on the store
notifies only the node watching `count`.

Follow-up proposed as a card (gate 09 Q2/Q3): the Flutter SDK `formatDate` gap and a
`generated.dart` drift check in `schema.yml`, as their own PR.

Not accepted here, because it does not exist yet: OrcaClient, any rendering, the executor. The
first visible UAT is the counter page on a simulator in S2, then the stop-or-go.

Next: 11 Release is skipped by default (config.json). 12 Deploy watch for S1 means PR 2's CI.
