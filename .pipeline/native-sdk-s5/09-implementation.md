# 09 · Implementation · native-sdk-s5

## Front page

### In one breath
S5 is built on feat/native-sdk-s5: 5 code commits (23b.25, 26, 32); nothing pushed or published.
The engine reads pre-releases: under a min of 99.0.0 the iOS app now shows the 426 page live.
release.sh lists sdk-swift as 9; its tag starts sdk-swift-mirror.yml: split, push, tag, verify.
Rehearsed in throwaway clones: alpha.1 kept, then alpha.2, mirrored, resolved, built and run.
Tests: engine 691 of 692 (port 8080 is Docker's); T5.2, T5.3, T5.4 and the T5.1 rehearsal green.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: CI and rehearsals share scripts/swift-mirror.sh, so the rehearsal ran CI's code.
2 auto-decided: a kept alpha with nothing to commit is tagged at HEAD, no empty release commit.
3 auto-decided: release.sh stops before any change when the mirror repo cannot be reached.

### Questions for you
1. A guard blocks my writes to your main checkout, so the docs-site page is in the worktree. You
   copy it with the two steps in the appendix? (default: yes; nothing else sits outside git)
2. Push and open the S5 PR at stage 10? (default: yes; nothing merged, released or created)
3. Add sdk-swift to the release table in the workspace CLAUDE.md? (default: yes, outside the repo)
4. After merge: you create the mirror repo and key (User_Actions), then release.sh 9, Return.
   (default: as agreed at 08; T5.1 turns green only on that first real run)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Tasks, status and evidence
| # | Status | Evidence |
|---|---|---|
| 23b.32 | done | `parseSemver` accepts `X.Y.Z-pre` and `+build` and still returns `[major, minor, patch]` (its export in `core/index.ts` is unchanged); `compareSemver` follows semver.org §11: core first, a release above its pre-releases, identifiers left to right, numbers as numbers and below words, the longer label wins a tie, build metadata ignored. Malformed input still compares as 0, so garbage passes the gate. T5.3: 5 new unit tests in `min-sdk-version.test.ts` (the order `0.1.0-alpha.1 < alpha.2 < beta < 0.1.0 < 0.1.1`, `alpha.10 > alpha.9`, the semver.org examples, build metadata, a min of `0.1.0` blocking `0.1.0-alpha.1`), plus 2 e2e cases in `caps-policy-e2e.test.ts` (426 with the blocking page; at or above the min, and garbage, pass). Live on iOS below. Commit a436961 |
| 23b.25 | done | `release.sh`: `sdk-swift\|sdk-swift\|sdk-swift-v\|mirror\|sdk-swift/VERSION`, last in the list so numbers 1-8 stay; plain `VERSION` read and write; pre-release prompt `[k]eep` (only while untagged, then the default) / `[n]ext` / `[r]elease` / M/m/P; an existing tag stops it before any change; `Generated.swift` regenerated with `gen-native-capabilities.ts`; validation `swift package describe` and `swift build`; mirror tags pushed after registry packages, devtools still last. `scripts/swift-mirror.sh publish` splits with `git subtree split`, checks VERSION matches the tag and that the split has Package.swift and LICENSE, builds it alone, pushes `main` fast-forward only and the bare tag; `verify` resolves the mirror at `exact:` from a scratch package. `.github/workflows/sdk-swift-mirror.yml`: on `sdk-swift-v*` or by hand with a tag; publish with the deploy key; verify on Linux (build and run), macOS (build and run) and the iOS simulator (build). Commits 9238cbe, 1ef2859, f7971cd |
| 23b.26 | done | `sdk-swift/README.md`: alpha banner, Install (Xcode and Package.swift, `exact: "0.1.0-alpha.1"`), `OrcaApp` root view, absolute links, licence. `sdk-swift/LICENSE` (the BSL 1.1 copy `sdk/` carries). Root README Architecture lists `sdk-swift/`; `examples/app-ios/README.md` says alpha and points at Install; the `Package.swift` comment says the mirror carries `Tests/`. Outside git: `docs/User_Actions.md` gains "Epic 23b: Native SDKs — iOS SDK mirror" (5 steps: the empty repo, a key pair, the deploy key with write access, the secret `SWIFT_MIRROR_DEPLOY_KEY`, the first release) and the Maven section no longer says the mirror needs nothing; the epic plan's 23b table gains a Status column (23b.1-24 and 28-31 done, 25, 26 and 32 "S5 PR") and row 23b.32; the docs-site page "iOS SDK (alpha)" (question 1). T5.2: the mirror's README has no `../` link; `capabilities.json` and `LICENSE` resolve at its root. Commit 4dbaf8e |

### The 426 page, live (T5.3)
The example server on :8097 with `ORCA_MIN_SDK_VERSION=99.0.0` answers the iOS app's
`x-orca-sdk-version: 0.1.0-alpha.1` with 426 and `{error: sdk_version_too_old, minSdkVersion:
99.0.0, clientSdkVersion: 0.1.0-alpha.1, page}`; an unversioned request still gets 200. The
counter app on the iPhone 16 Pro simulator shows the red "Update required" prompt: "This app needs
version 99.0.0 or later to continue." The server is stopped.

### Rehearsals (T5.1 before the real tag, T5.4)
All in the scratchpad, against local bare repositories; nothing reached GitHub.
- Mirror: `publish sdk-swift-v0.1.0-alpha.1` into an empty bare repo: split 94aa6ca, the split tree
  builds alone (macOS swift, and the CI path in `swift:6.2-noble`), `main` and `0.1.0-alpha.1`
  pushed. The mirror root: `.gitignore LICENSE Package.swift README.md Sources Tests VERSION
  capabilities.json`, 22 commits of history.
- Verify at exactly `0.1.0-alpha.1`: macOS build and run prints `0.1.0-alpha.1`; Linux in
  `swift:6.2-noble` the same; the iOS simulator build passes.
- Guards: a rerun gives the same split and pushes nothing; a rerun of an older tag leaves `main`;
  a tag whose VERSION differs stops; a mirror tag moved to another commit stops.
- release.sh in a clone with a local origin and mirror (`SWIFT_MIRROR_URL`), aborted at
  "Proceed?": Return keeps `0.1.0-alpha.1`; `n` gives `alpha.2`, `r` `0.1.0`, `P` `0.1.1`; a bad
  answer asks again; devtools beside it keeps the M/m/P prompt (`0.2.1+1 → 0.2.2+1`).
- Two full runs: keep (nothing to commit, HEAD tagged `sdk-swift-v0.1.0-alpha.1`, tag pushed), then
  with the tag present the prompt drops keep and refuses `k`; `n` makes `chore(release): version
  bump` (VERSION and Generated.swift, sdkSemver `0.1.0-alpha.2`) and its tag. The mirror then
  fast-forwards to 460af2e on top of 94aa6ca, and verify at `alpha.2` prints `0.1.0-alpha.2`.

### Test results
| Where | Result |
|---|---|
| Engine, `bun test` | 691 pass, 1 fail: the caps-412 test that needs port 8080 (Docker holds it here) |
| `min-sdk-version.test.ts`, `caps-policy-e2e.test.ts` | 24 and 13 pass |
| Engine `tsc -p tsconfig.build.json --noEmit` | clean |
| `bash -n`, `shellcheck -S warning` on both scripts | clean |
| `gen-native-capabilities.ts`, `gen-widget-registry.ts` | no drift |
| Workflow YAML | parses (no actionlint here) |

### Docs-site page (question 1)
Written to the worktree's gitignored copy:
`.claude/worktrees/keen-leakey-4c4de7/docs-site/docs/guides/ios-sdk.mdx` (install, root view,
what the alpha draws, minimum SDK, button styles, DevTools, the example). To put it in your site:
1. `cp /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/keen-leakey-4c4de7/docs-site/docs/guides/ios-sdk.mdx /Users/amrebada/workspace/orca-gateway/open-source/docs-site/docs/guides/`
2. In `docs-site/sidebars.ts`, Guides, add `'guides/ios-sdk',` after `'guides/capability-policies',`.
Copy it before the worktree is archived; the worktree copy goes with it.

### Findings worth remembering
- F1 A PreToolUse guard refuses writes to the main checkout from this worktree, so 08's question 2
  could not run as planned (question 1).
- F2 The release table in the workspace `CLAUDE.md` lists 8 packages; sdk-swift is not there
  (question 3). Its ordering example `2,5,6,7,8` still holds: sdk-swift is 9.
- F3 xcodebuild names a one-target package's scheme after the package, not its library product;
  the first iOS verify failed on it (fixed in f7971cd).
- F4 `git subtree split` gives the same commit for the same history, so the mirror's `main` only
  ever fast-forwards, and a rerun is a no-op.
- F5 The workflow pins GitHub's ed25519 host key. If GitHub ever rotates it, the publish job fails
  on ssh and that line needs the new key.
- F6 The iOS 426 page draws its prompt at the top, edge to edge (the root is a bare
  FallbackPrompt), as S4's `degrade-426` golden shows. Not changed in S5.
- F7 The engine changed, so its next patch (`@orca-gateway/engine` 0.3.3 → 0.3.4) carries the
  pre-release gate; release it with sdk-swift (08 question 3).

### For ship (stage 10) to know
Nothing deploys. Push the branch and open the PR. CI on the PR: Engine (the new tests; port 8080 is
free there), Schema, SDK Swift (Linux) and SDK Swift UI (the PR touches `sdk-swift/`).
`sdk-swift-mirror.yml` runs only on a release tag, so the PR cannot exercise it; T5.1 is green
only when your first `release.sh` run's tag passes it. Before that run: User_Actions "iOS SDK
mirror" Steps 1-4.
