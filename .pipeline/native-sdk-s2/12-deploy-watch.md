# 12 · Deploy watch · native-sdk-s2

## Front page

### In one breath
PR #5 is open with the CHANGELOG entries for engine 0.3.3 and sdk 0.3.2 plus S2's pipeline notes.
Its 2 checks are running. Main has been green since PR #4 (4 of 4 workflows). Nothing is published.
Merge #5, run release.sh from the main checkout, and say "released"; I then check what landed.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: 13-16 are skipped, because S2 deploys nothing (your call, 2026-11-06, gate 10).

### Questions for you
1. When you say "released", I check npmjs 0.3.3, pub.dev 0.3.2, both tags, main CI. (default: yes)
2. After this gate: S3 starts as native-sdk-s3, cut from main once #5 is in. Its stage 08 adds
   the DevTools client and the events schema. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### What S2 shipped, and where it stands
| Item | State |
|---|---|
| PR #4, S2 (23b.15-19) | merged 2026-11-06T14:22:45Z as 022b45f; all 8 checks green on 521dd56, including the golden on Xcode 16.4 and iOS 18.5 |
| main after #4 | Engine CI, Schema CI, SDK Swift CI and SDK CI all succeeded |
| SDK Swift UI (macOS) | runs nightly at 03:00 UTC and on PRs; tonight's run is its first on main |
| PR #5, changelogs | https://github.com/orca-gateway/orca-gateway/pull/5, mergeable, 2 checks pending |
| engine 0.3.3 / sdk 0.3.2 | not published; you run `release.sh` after #5 (gate 11) |

### What I check after "released"
- `npm view @orca-gateway/engine version` on registry.npmjs.org is 0.3.3. GitHub Packages should
  not get it, since `~/.npmrc` has no scope mapping.
- `https://pub.dev/api/packages/orca_gateway` reports 0.3.2 as latest.
- The tags `engine-v0.3.3` and `sdk-v0.3.2` are on origin, and the release commit
  `chore(release): version bump` is on main.
- Schema CI on that commit is green. That shows `generated.dart` was regenerated with
  `kSdkSemver` 0.3.2.
- The plugins still resolve against sdk 0.3.2 with `^0.3.0`; nothing in them changes.

### Branches
- `feat/native-sdk-s2` is merged and has no new work.
- `docs/release-engine-0.3.3-sdk-0.3.2` (PR #5) carries the changelogs and the pipeline commits
  for gates 10-11. This stage's commit goes there too, before it merges.
- S3's branch is cut from main after #5.

### Observe (13-16)
They are skipped, as decided at gate 10. S2 is a library plus an example app run on a simulator,
so there is nothing deployed to observe. The first observable surface is a published Swift
package (S5).
