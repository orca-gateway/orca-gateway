# 10 · UAT · native-parity-s3

## Front page

### In one breath
Step 3 is ready: A3.1-A3.7 ticked on both SDKs, PR #40 open (orca-gateway/orca-gateway).
The iOS hand check found three Swift gaps; all are fixed here (S-limits, S-routebar, S-shell).
Android and iOS now give the same sizes on the `layout` and `layout-safe` demo pages.

### New for you
nothing new

### Trade-offs
4 auto-decided (minor): fix the Swift gaps in step 3; a plain Row/Column leaves its main axis
unbounded (Flutter's RenderFlex); the Swift Card clip test now overflows as Flutter allows; the
Android back-navigation failure was a starved emulator, no bug.

### Questions for you
1. Merge PR #40 once its checks are green. (default: wait for your merge)
2. After the merge: close the slice, 11 and 13-16 skipped as in s2. (default: yes)

## Appendix

### Where it stands
PR https://github.com/orca-gateway/orca-gateway/pull/40, branch feat/native-parity-s3 at b37ca6d, on main 3cdeef7 (no
rebase needed). Rows A3.1-A3.7 ticked ✅ / ✅ in /Users/amrebada/.claude/plans/native-parity/phase-a-tests.md with test
names, hand checks and the PR link (26 of 54 rows now done on both SDKs).

### Suites on this head
engine `bun test` 751 pass · Flutter 331 pass, analyze clean · Kotlin `./gradlew build --rerun-tasks` core 369, sdk
348, lint clean · Swift `swift test` 240 UI + 368 core, 0 warnings · iOS scheme (iPhone 16 Pro, iOS 18.5) 283 UI + 368
core, GoldenTests 4/4, no golden moved · the three generators leave no diff.

### Hand checks (parity-a pages `layout` and `layout-safe`)
Android API 34 emulator (density 440) and iPhone 16 Pro simulator, both built from this head, sizes measured on
screenshots with a pixel tool (notes: scratchpad hand3/notes.md):
- A3.2 AspectRatio 320×180 · FractionallySizedBox 160, centred · ConstrainedBox around a child asking 300×20: 200×40 ·
  tight 100×30 parent: 100×30 · LimitedBox 100 in a horizontal scroll, full width in the column.
- A3.3 Wrap runs 44 apart, boxes 56 apart, centred runs from x 36, cross end shares the bottom.
- A3.4 Align bottomRight in its corner · factors 96×48 · Flexible 60 / Expanded 160 · both words' glyphs end on the bar.
- A3.5 IntrinsicHeight: 20/60/40 → all 60 · IntrinsicWidth step 50: 70/130/90 → all 150.
- A3.6 Offstage: no gap when hidden; counter and typed text survive. layout-safe on the iPhone: all-edges half from the
  notch (62), top-false half from 0, both above the home indicator; pushed: both from the back bar's bottom (100.3).
- A3.7 contain 100×50 · cover 120×60, 10 spilling each side · scaleDown 100×50.
- Back from layout-safe (GoBack and system back) returns to layout on both.

### What the hand check changed (stage 10 tasks)
- S-limits cdcf6e5: a Swift Container or SizedBox with a set width or height keeps to the parent's limits (Flutter
  `enforce`): first pass drew 300×20 in ConstrainedBox(max 200×60), and 20/60/40 and 70/130/90 under Intrinsic*.
  Reviews: fit pass; quality rework (AddTight in AspectRatio and FractionallySizedBox, reuse BoxLimits) → pass.
- S-routebar 706ed87: a route's navigation bar (pushed back bar, title bar) takes the top edge; the first pass showed
  the top-false half under the back bar. Review: pass (both lenses).
- Android back navigation: failed only on a CPU-starved emulator; on a cold-booted one both GoBack and system back work.

### Follow-ups (in the PR body)
Swift: ConstrainedBox min through a Padding or a nested ConstrainedBox; Positioned, Drawer, AppBar leading and
LimitedBox onto AddTight; IntrinsicWidth around a horizontal Wrap counts the spacing; a true SafeArea edge inside a
false one; colour-only Container measures 10 tall; a Row's flex children inside IntrinsicWidth. iOS: the back bar on
an AppBar-less pushed page. Kotlin: RouteFrame's TopAppBar status-bar inset; a baseline-aligned Row in IntrinsicHeight.
Both: LimitedBox in a plain Column. Carried from #36: Android app events for covered pages, the edge flick, viewport
onVisible, iOS nested same-axis scroll, stale README action counts.

### Merged
PR #40 merged by amrebada at 2026-11-16T03:16:51Z (merge 6a7f0e0, head 2179ff2), every PR check green; main green
at the merge (Engine, Schema, SDK, SDK Swift, SDK Kotlin CI). Gate 10 approved under the standing rule, Q1 answered by
the merge itself; 11 skipped by default; 12 approved; 13-16 skipped (no deploy target).
