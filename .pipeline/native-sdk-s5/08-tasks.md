# 08 · Tasks · native-sdk-s5

## Front page

### In one breath
S5 ships the iOS alpha. release.sh gains `sdk-swift` with a `mirror` publisher; its tag starts a CI
job that splits `sdk-swift/` into orca-gateway-swift and tags `0.1.0-alpha.1` there (23b.25).
Docs: an iOS install guide, banners and the epic rows (23b.26). The engine reads pre-releases.
Done: a clean CI runner resolves the mirror at 0.1.0-alpha.1 and builds against it (T5.1).

### New for you
The mirror is the subtree split chosen at native-sdk 03 → learning/git-subtree-split-mirror.md

### Trade-offs
1 needs you: the mirror keeps `Tests/` (inert there, plain pushes), or strips them as 05 said
  (one extra commit per release, mirror main force-moved). Default: keep them.
2 needs you: release.sh on a pre-release offers: publish as is, next alpha, or drop the label,
  then M/m/P as today. Default: those three.
3 auto-decided: semver order in the engine (0.1.0-alpha.1 < 0.1.0); engine tests, no fixture.
4 auto-decided: CI pushes the mirror with a deploy key; release.sh only tags, as for devtools.

### Questions for you
1. You create the empty public repo orca-gateway/orca-gateway-swift and its deploy key, by the
   steps I add to User_Actions.md? (default: yes; I never create repos or secrets)
2. docs-site is gitignored, so its page cannot ride in the PR. I write it in your main checkout's
   docs-site, outside git, as the rest of it is? (default: yes; the README is the tracked guide)
3. After the PR merges, you run release.sh: sdk-swift "as is" (0.1.0-alpha.1), engine patch.
   (default: yes; I never publish)
4. Add the pre-release gate as epic row 23b.32 at stage 09? (default: yes, outside the repo)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-build module replaces it.

### Rows
23b.25 and 23b.26 come from `.pipeline/native-sdk/08-tasks.md` lines 62-63. 23b.32 is proposed here
(question 4); you asked for the fix in S5 at native-sdk-s4 gate 09 (question 4).

| # | Task | Acceptance Criteria |
|---|------|-------------------|
| 23b.25 | `scripts/release.sh` gains `sdk-swift\|sdk-swift\|sdk-swift-v\|mirror\|sdk-swift/VERSION`: reads and writes the plain `VERSION` file, regenerates `Generated.swift` (`sdkSemver`) with `gen-native-capabilities.ts` on a bump, validates with `swift package describe` and `swift build`, and pushes the `sdk-swift-v<X>` tag last. Pre-release versions get the choices of trade-off 2. `.github/workflows/sdk-swift-mirror.yml` on `sdk-swift-v*` (and by hand with a tag): checkout with full history, `git subtree split --prefix=sdk-swift`, `swift build` on the split tree, push it to `orca-gateway-swift` `main` and the bare tag `<X>` with the deploy key, then a second job on a fresh runner resolves the mirror at exactly `<X>` from a scratch package and builds it (Linux core; macOS the SwiftUI layer). `sdk-swift/LICENSE` (BSL 1.1, as `engine/` and `sdk/` carry their own copy). | T5.1: the verify job passes on a real tag. Before that, at 09: the split pushed into a local bare repo, tagged, and resolved by file URL from a scratch package that builds. T5.4 (new): release.sh driven to its summary in a throwaway clone for each choice, then aborted; nothing pushed. |
| 23b.26 | `sdk-swift/README.md`: banner from "not ready" to "alpha", an install section (Xcode → Add Package → the mirror URL, `exact: "0.1.0-alpha.1"`; the root view), absolute links, so they work in the mirror. The root `README.md` lists `sdk-swift/` in Architecture. `docs/User_Actions.md`: the mirror repo and deploy key steps, and the 23b paragraph that says the mirror needs nothing is corrected. The docs-site page "iOS SDK (alpha)" (question 2). Epic plan: the iOS rows ticked. | T5.2: banner, install section, epic rows and User_Actions entry exist; README links resolve from the mirror's root. |
| 23b.32 | (question 4) `engine/src/core/min-sdk-version.ts`: `parseSemver` accepts `X.Y.Z-pre.N` and `+build`; `compareSemver` follows semver precedence: a pre-release sorts below its release, identifiers compare left to right, numeric ones as numbers. Malformed versions still pass the gate. | T5.3 (new): `0.1.0-alpha.1 < 0.1.0-alpha.2 < 0.1.0-beta < 0.1.0 < 0.1.1`; `alpha.10 > alpha.9`; build metadata ignored; a min of `0.1.0` blocks `0.1.0-alpha.1` with the 426 page; garbage still allowed. The iOS app on the simulator gets the 426 page live with `ORCA_MIN_SDK_VERSION=99.0.0`. |

### Trade-off 1: tests in the mirror
05 decided "read `../schema/fixtures` at run time; the mirror ships no tests". The point was one
copy of the fixtures. A subtree split carries `Tests/` (750 KB, most of it goldens), which cannot
run outside the monorepo.
- **Default, keep them.** The mirror is exactly the split, every push is a fast-forward, and a
  tag points at a commit that also exists in the monorepo's split history. SPM never builds a
  dependency's test targets, so consumers see no difference. The README says tests run in the
  monorepo.
- **Alternative, strip them.** After the split, one commit deletes `Tests/` and the two
  `testTarget` lines and gets the tag. The next split does not contain that commit, so the
  mirror's `main` moves with `--force-with-lease` each release (tags stay fixed).

### Trade-off 2: release.sh and pre-releases
`bump_core` splits on dots, so `0.1.0-alpha.1` makes it fail. The first Swift release is the
version already in `VERSION`, which was never tagged.
- **Default.** For a version with a `-pre` label, the prompt offers `[k]eep` (publish as is, only
  when its tag does not exist yet), `[n]ext` (`alpha.1` → `alpha.2`) and `[r]elease` (drop the label:
  `0.1.0`), then M/m/P on the core as today. Plain versions keep today's prompt.
- **Alternative.** Edit `VERSION` by hand for pre-releases. CLAUDE.md forbids hand edits, so the
  script would need a flag to skip the bump.

### Trade-off 3: semver order (auto-decided)
The engine follows semver precedence (semver.org, item 11), written by hand as today (no
dependency). The rule is behaviour, not wire format, so it gets engine tests and no conformance
fixture. A server configured with a min-SDK that equals a release blocks that release's alphas,
which is the point.

### Trade-off 4: who pushes the mirror (auto-decided)
native-sdk 03 chose a CI-pushed mirror. `GITHUB_TOKEN` cannot write to another repository, so the
job uses a deploy key with write access on `orca-gateway-swift` (its private half as the Actions
secret `SWIFT_MIRROR_DEPLOY_KEY`). release.sh only bumps, tags and pushes the tag, as it does for
devtools. Alternative: release.sh pushes the split from your machine with your git login, which
needs no secret but makes the mirror depend on the machine that releases.

### Findings while planning
F1 `orca-gateway/orca-gateway-swift` does not exist yet (`gh repo view` finds nothing).
F2 `docs/User_Actions.md` says the iOS mirror needs nothing configured; with a CI push it needs the
   repo and the deploy key. The entry is corrected at 09.
F3 `docs-site/` is in `.gitignore` (line 54) and exists only in your main checkout, so the 23b.26
   page cannot be part of the PR (question 2).
F4 `sdk-swift/` has no LICENSE; a split without one would publish code with no licence file.
F5 `Generated.swift` holds `sdkSemver` from `VERSION`; Schema CI fails when they differ, so a
   release must regenerate it, as release.sh already does for the Dart SDK.
F6 README links such as `../sdk/` break in the mirror; they become absolute GitHub links.
F7 The engine applies no min-SDK unless `setMinSdkVersion` is called (`protocol.json`'s
   `minSdkVersion` feeds codegen only), so reading pre-releases blocks nobody by default.
F8 `examples/app-ios` keeps its local path dependency: it builds against the code in the PR.

### Tests (T5 group)
- T5.1: the verify job on the real tag (after you release), and the local rehearsal at 09.
- T5.2: as in 23b.26.
- T5.3: engine unit tests in `engine/test/min-sdk-version.test.ts`, plus the live 426 page on iOS.
- T5.4: release.sh in a throwaway clone, fed each answer, aborted at "Proceed?".

### CI
New: `sdk-swift-mirror.yml` (tag-triggered, two jobs). Engine CI runs the new min-SDK tests. Schema
CI already checks `Generated.swift`. Nothing else changes.

### Commits on feat/native-sdk-s5 (conventional)
1. chore(pipeline): native-sdk-s4 gates 10 and 12, S4 closed (done)
2. chore(pipeline): native-sdk-s5 stages 01-08
3. fix(engine): the min-SDK gate reads pre-release versions (23b.32)
4. feat(scripts): release.sh publishes sdk-swift through the mirror (23b.25)
5. ci: split sdk-swift into orca-gateway-swift on its release tag (23b.25)
6. docs(sdk-swift): alpha install guide, licence, banners (23b.26)
7. chore(pipeline): stage 09 onward

### Not in S5
- The release itself, the mirror repo and its secret: yours (questions 1 and 3).
- Kotlin (S6, 23b.27).
- Moving `examples/app-ios` onto the published package.
