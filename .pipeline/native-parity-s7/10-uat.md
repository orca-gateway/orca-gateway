# 10 · UAT · native-parity-s7

## Front page

### In one breath
Step 7 is ready: A7.1-A7.4 ticked on both SDKs, PR #52 open (orca-gateway/orca-gateway).
Hand checks pass on the `rich` page on both devices; the branch sits on main 2ca21c9e.
49 of the 54 Phase A rows are now done on both SDKs; step 8 is next.

### New for you
nothing new

### Trade-offs
2 still with you (defaults applied): A7.4 corrected to Flutter's one-cell Table (no wire change);
SelectableText on iOS is a read-only UITextView (word and range selection), not .textSelection.

### Questions for you
1. Merge PR #52 once its checks are green. (default: wait for your merge)
2. Keep the Table and SelectableText defaults above. (default: yes; say so to change)
3. After the merge: close the slice, 11 and 13-16 skipped as in s6. (default: yes)

## Appendix

### Where it stands
PR https://github.com/orca-gateway/orca-gateway/pull/52, branch feat/native-parity-s7, on main 2ca21c9e (rebased
on 3880607 first, then on 2ca21c9e once PR #50 merged, dropping step 6's commits). Rows A7.1-A7.4 ticked ✅ / ✅ in
/Users/amrebada/.claude/plans/native-parity/phase-a-tests.md with test names, hand checks, Flutter line references and
the PR. A7.4 corrected (Table: one-cell rows, TableBorder.all, columnWidths unread); A7.1-A7.3 gain Flutter notes
(no row weakened).

### Suites
On the head rebased on 3880607: engine 832 pass · Flutter 545 pass, analyze clean · `swift test` UI 578, core 640 ·
iOS scheme UI 739, core 640 · Kotlin core 658, sdk 814, lint clean · app-ios and app-android build · the three
generators leave no diff · no golden moved. Main's #50 merge (06422c1e) has the same tree as step 6 inside the branch,
and #51 touches no SDK or schema file, so these hold on 2ca21c9e. After that rebase the engine suite and the three native plugins (Swift and Gradle builds against these SDKs) were rerun: see the PR body.

### Hand checks (parity-a page `rich`)
iPhone 16 Pro simulator and Android API 34 emulator; details in 09-implementation.md and the scratchpad notes
s7/hand-checks.md. All four rows pass on both devices. Android: the drag past the end of a maxLines box scrolls the
page (Compose nested scroll; follow-up).

### Known differences and follow-ups
In the PR body. For you: the engine does not export ImageIcon from its barrels (npm users cannot import it; own
small PR), and the cloud Go registry after step 6. Others: a span's own height, Swift Text under a DTS at a fixed 14,
per-run lines below iOS 18, Icon src file:// and the null-src glyph, DTS resets at Drawer and SliverAppBar, the Text
decoration renderers vs Skia.

### Next
Step 8 (native-parity-s8): dialogs, bottom sheets, tooltips and snackbars (A8.1-A8.5), with your 2026-11-15 call
(draw SnackBar and Tooltip on iOS) logged as yours, and rows A8.1 and A8.5 corrected to Flutter (openDialog is a bottom sheet that
ignores `dismissible`; SnackBar is a static inline bar).
