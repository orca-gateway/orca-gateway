# 12 · Deploy watch · native-sdk-s5

## Front page

### In one breath
PR #10 is merged (fea34cb) with every check green. You released engine 0.3.4, sdk 0.3.3, iOS alpha.
The iOS alpha is live on orca-gateway-swift. Its first mirror run went red after a good publish.
The cause was cleanup: root-owned build files. PR #11 fixed it; the rerun passed 4 of 4 (T5.1).
Nothing else deploys. The UAT servers are stopped.

### New for you
Nothing new.

### Trade-offs
1 done: UAT passed on your word ("A" at gate 10); the release ran on your machine as planned.
2 done: the mirror fix went out as PR #11 on your "Yes, fix it"; the published code never changed.
3 noted: pub.dev warned that sdk/CHANGELOG.md has no 0.3.3 entry; it published anyway.

### Questions for you
1. After A: 13-16 are skipped (nothing runs as a service) and S5 is closed. (default: yes)
2. Mark 23b.25, 23b.26 and 23b.32 done in the epic plan, outside the repo? (default: yes, at A)
3. Add the missing 0.3.3 entry to sdk/CHANGELOG.md in S6's first PR? (default: yes)
4. docs-site: sidebars.ts still lacks `'guides/ios-sdk',`; you add it. (default: yours, no rush)
5. Next: S6 (23b.27, the Kotlin SDK), the last slice of Epic 23b. (default: when you say go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #10
https://github.com/orca-gateway/orca-gateway/pull/10, merged at 21:07:16Z as fea34cb. Final checks:
Codegen drift detection, Core tests on swift 5.10-jammy and 6.2-noble (Linux), UI tests and example
(iOS simulator), and SDK `test`: all success. After the merge, Engine CI, Schema CI and SDK Swift CI
passed on fea34cb. Engine CI includes the new min-SDK tests and the caps-412 test, which needs port
8080 (free on CI).

### The release (you ran `release.sh` with `1,2,9`)
| Package | Version | Where | Tag |
|---|---|---|---|
| engine | 0.3.4 | npm `@orca-gateway/engine`, `latest` (seen at 21:3xZ) | `engine-v0.3.4` |
| sdk | 0.3.3 | pub.dev `orca_gateway`, latest | `sdk-v0.3.3` |
| sdk-swift | 0.1.0-alpha.1 (kept) | `orca-gateway/orca-gateway-swift` `main` and tag at 94aa6ca | `sdk-swift-v0.1.0-alpha.1` |

The release commit db39434 `chore(release): version bump` changed the engine and sdk manifests and
`generated.dart`; sdk-swift kept its VERSION, so its tag sits on the same commit. Engine CI, Schema
CI and SDK CI passed on db39434. npm asked for a browser login during the publish (its 2FA flow);
the script waited and went on.

Before the release: `release.sh` first stopped at its mirror check, since the repo did not exist yet,
and changed nothing. You then did User_Actions Steps 1-4: a public, empty repo, then a key pair; the
deploy key "orca-sdk-claude" with write access matches it; the secret `SWIFT_MIRROR_DEPLOY_KEY` was
set at 21:20:42Z; the local key files are deleted.

### The mirror runs
| Run | Ref | Result |
|---|---|---|
| [42296248558](https://github.com/orca-gateway/orca-gateway/actions/runs/42296248558), tag push | db39434 | publish red, verify skipped |
| [42297535448](https://github.com/orca-gateway/orca-gateway/actions/runs/42297535448), manual | main 602d8bc | 4 of 4 success |

- Run 1 split 94aa6ca, built it, pushed `main` and `0.1.0-alpha.1`, and printed "Published". Then the
  exit cleanup failed: the build had run in a root container on the mounted tree and left root-owned
  `.build` files. Under `set -e`, a failing EXIT trap became the job's status. Docker Desktop on
  macOS maps ownership to the user, which is why the 09 rehearsal passed.
- Checked from this Mac against the real mirror before the fix: macOS build and run, Linux in
  `swift:6.2-noble`, and the iOS simulator build. All report or build `0.1.0-alpha.1`.
- [PR #11](https://github.com/orca-gateway/orca-gateway/pull/11), merged as 602d8bc. The container
  builds into its own `/tmp` with the tree mounted read-only, and cleanup ends in `|| true`. The
  publish job checks out its own ref, so a manual run from main uses main's script. Tests: a harness
  reproduced the trap failure, the read-only build leaves no `.build`, and publish and rerun against
  a local bare mirror both exit 0.
- Run 2 found `main` and the tag already at 94aa6ca and pushed nothing. Then linux (core), macos
  (SwiftUI) and the iOS simulator each resolved the mirror at exactly `0.1.0-alpha.1` and built it;
  the run jobs printed `sdkSemver 0.1.0-alpha.1`. This is T5.1, green.

### Cleanup
- The UAT servers on :8095, :8096 and :8097 are stopped. Docker on 8080, the other bun on 8091 and
  DevTools on 6363 were not touched. The simulator keeps app-ios installed.
- Rehearsal clones and bare repos stay in the session scratchpad only.
- docs-site: `docs/guides/ios-sdk.mdx` is copied into your main checkout; `sidebars.ts` does not list
  it yet (question 4).
- The workspace CLAUDE.md release section lists sdk-swift (gate 09, question 3).

### What S5 leaves for later
- `sdk/CHANGELOG.md` has no 0.3.3 entry (question 3); the engine's changelog was not checked.
- The iOS 426 page draws its prompt at the top, edge to edge (09 F6).
- From S4: S2's Card does not fill under stretch; Flutter's ClipRRect reads only a number radius;
  ecommerce's search reads `V.event("query")` while both SDKs send `{value}`; CI's Xcode 16.4 has a
  golden for counter only.
- The GitHub ed25519 host key is pinned in the mirror workflow (09 F5).

### Next
On A, stages 13-16 are skipped with the reason "S5 has no deployed surface; skipped by the default
accepted at gate 12 (A)", S5 is closed, and the epic rows are ticked (question 2). S6 (23b.27:
`sdk-kotlin/`, Gradle, kotlinx.serialization, Compose M3, Maven Central with the Sonatype steps
already in User_Actions) starts from main when you say go.
