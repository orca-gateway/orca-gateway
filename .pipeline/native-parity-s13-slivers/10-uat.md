# 10 · UAT · native-parity-s13-slivers

## Front page

### In one breath
CustomScrollView and the four sliver widgets work on both native SDKs as one scroll surface,
with a collapsing bar that honours pinned, floating, snap, expandedHeight and collapsedHeight.
Rows B13.1 and B13.2 pass on both, by fixture, tests and a hand-check on an iOS simulator and
an Android emulator with the `slivers` demo app. With them Phase B is 34 of 34 on each SDK.
The PR is open; the merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
1 needs you, with a default: the SDK draws the collapsing bar itself; the plan named the
system large-title bar and LargeTopAppBar. Default: keep. Said in the PR.

### Questions for you
1. Keep the SDK-drawn bar? (default: keep)
2. Merge the PR: yours. (default: ok)
3. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

### Hand-check, both devices (demo app `slivers`, server on :8099)

| Check | iOS simulator (18.5) | Android emulator (API 34) |
|---|---|---|
| One surface: bar, heading, grid of 6, 40 rows, "End of list" | all move together; the end is reached | same |
| Grid: 3 across, spacing 8, ratio 1.5 | drawn as GridView's cells | same |
| Pinned, expandedHeight 200 | collapses to the 56 toolbar and stays; title and action stay | same |
| A drag that starts on the bar | scrolls the view and collapses the bar | same |
| Floating | scrolls away; a 70 pt reverse drag brings 70 pt of it back mid-list | re-enters fully on a longer reverse drag |
| Plain, expandedHeight 120 | scrolls away with the content | same |
| Top inset | the bar runs under the status bar | the bar starts below it (Scaffold took the inset) |

### Not covered by hand
snap (pinned by tests on both SDKs with Flutter's numbers), collapsedHeight (tests), a horizontal or
reversed CustomScrollView (tests), the slivers outside a CustomScrollView (tests).
