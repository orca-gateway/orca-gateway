# 09 · Implementation · native-parity-s13-slivers

## Front page

### In one breath
group 3 of 3 · tasks: 6 green, 0 blocked · cases: 13 of 13 green · all suites green
G1: render fixture 69, a Flutter test that measures the bar, the `slivers` demo app.
G2: both cores: the item list of one scroll view and the bar's maths, 21 Flutter cases each.
G3: both UI layers: one lazy scroll view, the bar drawn by the SDK, 73 widgets advertised.
Merged with main 941e789 (step 14) afterwards; generated files regenerated.

### New for you
nothing new

### Trade-offs
3 auto-decided, yours to overturn: the SDK draws the collapsing bar, not the system large-title
bar · the bar collapses only as the first sliver of a vertical view · `elevation` casts no
shadow, as Flutter's Material 3 bar.

### Questions for you
1. Approve the stage? Device hand-checks are recorded in stage 10. (default: go)
2. Keep the SDK-drawn bar, or go back to the system bars the plan named? (default: keep)

## Appendix

### Group 1

#### T1 · Render fixture 69, Flutter widget test with the bar's extents
Files: schema/fixtures/render/69_custom_scroll_view_slivers.json · sdk/test/sliver_widgets_test.dart
Cases: C-fix (Flutter), C-flutter → green. 29 nodes from the engine's own encoder; 21 bar cases
measured on Flutter's render objects (paint, layout, box, toolbar opacity).
Review fit: pass · Review quality: pass

#### T2 · `slivers` demo app, example test, native parity test
Files: examples/server/slivers.ts · index.ts · README.md · engine/test/slivers-example.test.ts ·
engine/test/parity-b-slivers.test.ts
Cases: C-demo, C-caps → green (the two native-vector tests went green with group 3).
Review fit: pass · Review quality: pass

### Group 2

#### T3 · Swift core: SliverItems, SliverAppBarGeometry
Cases: C-items-S, C-geo-S → green; all 21 Flutter cases at 0.0001.
Review fit: a clamp on collapsedHeight below 56 and on a negative top padding departed from Flutter
and the Kotlin twin, fixed · Review quality: an input type only the tests used, removed; fixed

#### T4 · Kotlin core: the same
Cases: C-items-K, C-geo-K → green; all 21 Flutter cases at 0.0001.
Review fit: pass · Review quality: pass

### Group 3

#### T5 · Swift UI: CustomScrollView and the four slivers
Files: Widgets/Slivers.swift · Lists.swift · Layout.swift · Structure.swift · Refresh.swift ·
NodeView.swift · capabilities.json · Generated.swift · README.md · SliverTests.swift · count pins
Cases: C-fix (Swift), B13.1-S, B13.2-S, C-fallback-S → green (SliverTests 25 on the simulator).
Review fit: the bar was an overlay, so a drag starting on it did not scroll; it now sits inside
the scroll content. flexibleSpace was forced to the bar's height; now loose, as Flutter. fixed ·
Review quality: flattened slivers were not recorded for an outgoing switcher copy; three
duplications with Lists.swift; fixed

#### T6 · Kotlin UI: the same
Files: widgets/Slivers.kt · Lists.kt · NodeView.kt · WidgetBuilders.kt · capabilities.json ·
Generated.kt · README.md · SliverTest.kt · count pins
Cases: C-fix (Kotlin), B13.1-K, B13.2-K, C-fallback-K → green (SliverTest 31).
Review fit: a floating bar did not come back on a drag after a jump, then after a restored
position; flexibleSpace forced; fixed in two passes · Review quality: a copied half of NodeView
that double-fired a stray child's lifecycle triggers, extracted; fixed

### Test run
After merging main 941e789: engine 809 · Flutter +543, analyze clean · Swift macOS 0 failures, 0
warnings; simulator package tests TEST SUCCEEDED · Kotlin BUILD SUCCESSFUL, core 622, sdk 697, lint
clean · both example builds succeed · generators leave no diff.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
Limits, all in the READMEs: the bar collapses only as the first sliver of a vertical, non-reversed
view, elsewhere it is a box that scrolls away · iOS: a floating bar also comes back on a programmatic
scroll toward the top (Flutter and Android: only on a drag) · Android: after a jump or a restored
position with rows of mixed heights the bar may open early or late by the estimate's error · scroll
metrics are estimates unless rows share one length · `elevation` casts no shadow · inside a Scaffold
on Android the bar starts below the status bar (the Scaffold has taken the inset).
Not covered by a test: shrinkWrap with a collapsing bar on iOS; a tween on a flattened sliver's props.
