# 10 · UAT · native-sdk-s5

## Front page

### In one breath
PR #10 is open: feat/native-sdk-s5 → main, 6 code commits plus pipeline ones. CI is running.
On the simulator now: the iOS alpha under a min of 0.1.0 gets "Update required" (server :8096).
:8095 (min 0.1.0-alpha.1) lets it in; :8097 (min 99.0.0) blocks it. UAT is yours; steps below.

### New for you
Nothing new.

### Trade-offs
1 done: gate 09 defaults kept; the workspace CLAUDE.md release table now lists sdk-swift.
2 noted: the mirror workflow cannot run on a PR; T5.1 waits for your first real release tag.
3 noted: Auto-fix stays off for #10, as for #8, so CI results reach me when you ask.

### Questions for you
1. UAT: do the 426 pages, the README install section and User_Actions read right? (default: none)
2. After A: 11 is skipped by default, 12 records PR #10's CI, 13-16 skipped. (default: yes)
3. After merge, yours: User_Actions Steps 1-4, then release.sh `1,2,9` (engine and sdk patches,
   sdk-swift kept at 0.1.0-alpha.1). (default: yes; I never create repos, secrets or releases)
4. Copy the docs-site page before this worktree is archived (two steps below)? (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### UAT steps
The simulator panel shows the iPhone 16 Pro (iOS 18.5) with app-ios. Three example servers run from
the worktree's `examples/server`, all mine, stopped at the next gate: :8097
(`ORCA_MIN_SDK_VERSION=99.0.0`), :8096 (`0.1.0`) and :8095 (`0.1.0-alpha.1`). Ports 8080 (Docker),
8091 (another bun) and 6363 (DevTools) are left alone.

To point the app at a server, change the URL in:
```
SIMCTL_CHILD_ORCA_SERVER_URL=http://localhost:8096 SIMCTL_CHILD_ORCA_APP_ID=counter \
  SIMCTL_CHILD_ORCA_PATH=home SIMCTL_CHILD_ORCA_DEVTOOLS=0 xcrun simctl launch \
  --terminate-running-process booted com.orcagateway.examples.counter
```

1. The gate, live (on screen now, :8096): "Update required", "needs version 0.1.0 or later".
   - :8097: the same page with 99.0.0.
   - :8095: the counter draws; `-`, `+` and Reset work as in S2.
2. The docs, on the PR branch:
   - [sdk-swift/README.md](https://github.com/orca-gateway/orca-gateway/blob/feat/native-sdk-s5/sdk-swift/README.md):
     the alpha banner, Install (Xcode and Package.swift), the `OrcaApp` root view.
   - `docs/User_Actions.md`, "Epic 23b: Native SDKs — iOS SDK mirror": 5 steps for a non-developer.
   - The docs-site page (question 4), with `t docs:dev` once copied.
3. Optional, release.sh without risk: the rehearsal clone's origin and mirror are local bare repos.
   ```
   cd /private/tmp/claude-501/-Users-amrebada-workspace-orca-gateway-open-source--claude-worktrees-keen-leakey-4c4de7/89f1a544-a9c8-4749-a84f-4dbbb61fc572/scratchpad/t54/mono
   SWIFT_MIRROR_URL=$PWD/../orca-gateway-swift.git bash scripts/release.sh
   ```
   Type `9`; it is at `0.1.0-alpha.2` (tagged), so the prompt offers next and release; answer `n`
   at "Proceed?". Nothing there reaches GitHub.

### PR #10
https://github.com/orca-gateway/orca-gateway/pull/10, opened at this stage, bound to this session,
Auto-fix off. Its code commits: a436961 (engine gate, 23b.32), 9238cbe (release.sh, 23b.25),
1ef2859 and f7971cd (mirror script and workflow, 23b.25), 4dbaf8e (docs, 23b.26). The branch
contains origin/main 374216e, so nothing needed merging.

At writing, 2 checks had passed (one Codegen drift run, one SDK `test` run) and the rest were
pending: Engine `test`, Schema, the Linux core on swift 5.10 and 6.2, and the iOS UI job. Each
workflow runs twice, for the push and for the PR. `sdk-swift-mirror.yml` does not run: it only
starts on a release tag.

### Gate 09 answers carried out
- Question 3: the workspace `CLAUDE.md` release section lists `sdk-swift` (manifest
  `sdk-swift/VERSION`, tag `sdk-swift-v`, the mirror workflow) and gains its pre-release prompt,
  its validation, its tag order and its pre-reqs (the repo, the deploy key, `SWIFT_MIRROR_URL` for
  rehearsals). Its stale "all four packages" line now says 1-9. Outside git.
- Question 1: the page waits for your copy:
  1. `cp /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/keen-leakey-4c4de7/docs-site/docs/guides/ios-sdk.mdx /Users/amrebada/workspace/orca-gateway/open-source/docs-site/docs/guides/`
  2. In `docs-site/sidebars.ts`, Guides, add `'guides/ios-sdk',` after `'guides/capability-policies',`.

### Release (question 3)
- Before: User_Actions "iOS SDK mirror" Steps 1-4 (the empty public repo, a key pair, the deploy
  key with write access, the secret `SWIFT_MIRROR_DEPLOY_KEY`). release.sh stops at its login check
  until the repo exists.
- Then `bash scripts/release.sh` on main, `1,2,9`:
  - engine `P`: the pre-release gate.
  - sdk `P`: S3's DevTools builders and S4's 426 page, waiting since S4.
  - sdk-swift: Return keeps `0.1.0-alpha.1`.
- Then the "SDK Swift Mirror" run: publish, then the Linux, macOS and iOS verify jobs. Its green
  run is T5.1; stage 12 or a later ask can read it.

### Next
- 11 Release: skipped by default (config.json); question 3 is the release.
- 12 Deploy watch: PR #10's CI.
- 13-16: nothing is deployed; skipped at gate 12 as for S2 to S4.
- S6 (23b.27, Kotlin) is the last slice of the epic.
