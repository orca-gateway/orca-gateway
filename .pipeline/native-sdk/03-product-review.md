# 03 · Product review · native-sdk

## Front page

### In one breath
Reviewed from four seats: backend author, iOS developer, maintainer, market. The picture holds with
three fixes: per-platform targets generalising isSupportedOnWeb instead of a new tier enum, an own
repo for the iOS SDK (SPM needs bare semver tags at a repo root), and a new OSS epic, 23b.

### New for you
1. Read-only mirror repo via git subtree split → learning/git-subtree-split-mirror.md

### Trade-offs
1 needs you: platform flags, targets array per widget (generalises isSupportedOnWeb) vs tier enum.
2 needs you: iOS SDK home, separate repo orca-gateway-swift vs monorepo plus CI-pushed mirror.
3 needs you: wire names; DivKit and Nativeblocks went neutral; default keep Flutter names (DX).
4 needs you: iOS look; default idioms, and the eight with no counterpart degrade via caps vector.

### Questions for you
1. Minimum platforms? (default: iOS 16, for NavigationStack and sheet detents; Android minSdk 24)
2. Where in the plan? (default: new Epic 23b Native SDKs; User_Actions entry for Sonatype and GPG)
3. Author feedback? (default: a Page declares targets; the encoder warns on off-target widgets)
4. Icons on iOS? (default: bundle the Material Icons font first; SF Symbols map as a later option)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-discover module replaces it.

### Four seats
Backend author: must know what is safe where; targets on the Page plus an encoder warning beats a doc.
iOS developer: judges install (SPM), look (trade-off 4), binary size and iOS 16; never sees Flutter.
Maintainer (you, solo): sync points grow from 5 to 7, CI runs the fixtures on three SDKs, release.sh
gains two publishers; Maven Central needs a Sonatype account and a GPG key, SPM needs only a repo.
Market: DivKit (iOS, Android, Web, Flutter) and Nativeblocks (iOS, Android, RN) both pair a neutral
vocabulary with native renderers; Orca's edge is typed TS authoring plus state, actions and offline.

### Findings
F1 isSupportedOnWeb is already a per-widget platform flag (all 92 true today); a targets array such as
["flutter","web","ios","android"] generalises it, and tier becomes derived documentation.
F2 SPM resolves Package.swift at a repo root and needs bare X.Y.Z tags; release.sh tags pkg-vX.Y.Z and
CLAUDE.md forbids bare tags, so the monorepo cannot host the Swift package directly.
F3 No Swift or Kotlin code exists; the epic plan runs to Epic 60; OSS epics are 1-23, hence 23b.

### Carried, still open
platform order (Compose vs SwiftUI first) · scope (thin alpha vs parity) · spec source (action fixtures).
