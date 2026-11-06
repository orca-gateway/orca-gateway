---
topic: git-subtree-split-mirror
status: new
first_seen: native-sdk/03 2026-11-05
seen: native-sdk/03
---
# Read-only mirror via git subtree split

**Concept**  Keep one monorepo as the source of truth and let CI publish one folder's history to a
second read-only repo with git subtree split, tagged with the bare semver tags consumers need.

**Why here**  SPM wants Package.swift at the repo root and plain X.Y.Z tags; release.sh tags pkg-v.
A mirror gives SPM what it wants without moving the iOS SDK out of open-source/.

**When not**  The package has its own contributors and issues; then a real separate repo is simpler.

**Tiny example**  git subtree split --prefix=sdk-swift -b swift-mirror
git push git@github.com:orca-gateway/orca-gateway-swift.git swift-mirror:main  # tag 1.0.0 there

**Go deeper**  https://git-scm.com/docs/git-subtree · scripts/release.sh (publisher per package)
