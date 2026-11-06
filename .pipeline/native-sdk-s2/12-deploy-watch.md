# 12 · Deploy watch · native-sdk-s2

## Front page

### In one breath
Released: engine 0.3.3 on npmjs and sdk 0.3.2 on pub.dev; both tags on origin at 5a2dbf9.
Main CI is green on that commit (Engine, Schema, SDK Swift, SDK). No 0.4.0 went out.
The first try stopped on an expired npm login after the push; PR #6 makes release.sh check first.

### New for you
Nothing new.

### Trade-offs
1 auto-decided: 13-16 are skipped, because S2 deploys nothing (your call, 2026-11-06, gate 10).

### Questions for you
1. PR #6 (login checks before bumping) is open and mergeable; no CI covers scripts/.
   (default: you merge it when you like)
2. After A: S3 starts as native-sdk-s3 from main; stage 08 adds the DevTools client and
   the events schema. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### Round 2: released
| Check | Result |
|---|---|
| npmjs `@orca-gateway/engine` | 0.3.3 latest, published 2026-11-06T16:11Z; versions 0.3.0-0.3.3, no 0.4.0 |
| pub.dev `orca_gateway` | 0.3.2 latest, published 2026-11-06T16:09Z |
| tags | `engine-v0.3.3` and `sdk-v0.3.2` on origin, both peel to 5a2dbf9, the release commit |
| main CI on 5a2dbf9 | Engine CI, Schema CI, SDK Swift CI and SDK CI succeeded, so `generated.dart` was regenerated |
| main checkout | clean; the `npm version minor` edit (0.4.0) was reverted before publishing |

What went wrong the first time:
- release.sh pushed the release commit, then `npm publish` failed with E404. `npm whoami` gave
  401: the npm login had expired, and npm reports an unauthenticated publish to a scoped package
  as 404.
- The script stopped there. The tags were still local and the sdk was not published.
- You logged in again, then ran the script's remaining steps by hand: the publish and tag push
  for each package.

PR #6 (https://github.com/orca-gateway/orca-gateway/pull/6, `fix/release-login-preflight`)
adds step 1b to release.sh. It runs before anything is bumped or pushed:
- `npm whoami` against the registry the publish will use.
- A stop on an `@scope:registry` mapping that disagrees with publishConfig.
- A maintainer warning.
- pub.dev credentials with a refresh token.
- `git push --dry-run`.

I tested it from a clean tree for five cases: real login, no login, a mapping to GitHub Packages,
a non-maintainer, and no pub credentials. The tree stayed unchanged in every case. It is clean
under shellcheck and parses with bash 3.2. The workspace CLAUDE.md step list could mention step
1b; that file is outside the repo, so I left it.

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
