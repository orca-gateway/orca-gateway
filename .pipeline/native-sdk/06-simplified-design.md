# 06 · Simplified design · native-sdk

## Front page

### In one breath
Cut to a walking skeleton on iOS: 21 widgets (the 15 the core examples use plus 6), all 9 Value
kinds, 31 transforms, 13 ops ported whole, 12 of 28 actions, four adapters (HTTP, renderer, nav,
toast); no storage, dialogs, tabs, animations, offline or plugins; Compose repeats it afterwards.

### New for you
1. Walking skeleton: the thinnest end-to-end slice first → learning/walking-skeleton.md

### Trade-offs
1 needs you: resolver, port all 9/31/13 (pure, fixtured) vs only what examples use; default all.
2 needs you: actions in alpha, the 12 the core examples use vs all 28; default 12, rest degrade.
3 needs you: first codegen, caps vector and prop names vs full decoders; default caps and names.
4 needs you: mirror timing, local path until alpha publish vs mirror from day one; default later.

### Questions for you
1. Widget list? (default: the 21 in the appendix, the core examples' 15 plus six basics)
2. Examples that must run? (default: counter, basic-actions, server-actions, capability-demo)
3. Alpha label? (default: 0.1.0-alpha.1 on the mirror, experimental banner as in engine-dart)
4. Compose timing? (default: after the iOS alpha passes both fixture sets; same slices in Kotlin)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-design module replaces it.

### Alpha surface, iOS
Widgets (21): AppBar, Card, Center, Column, Divider, ElevatedButton, FallbackPrompt, OutlinedButton,
Padding, Row, Scaffold, SingleChildScrollView, SizedBox, Text, TextButton (the four core examples) plus
Icon, Image, Container, Expanded, Spacer, TextField. Everything else lacks the ios target until it
lands, so the server degrades it.
Values: all 9 kinds, 31 transforms, 13 BoolExpr ops. The examples use 11 transforms, but porting all is
cheaper than documenting a partial resolver, and fixtures 01-24 already test the whole set.
Actions (12 of 28): setState, actionGroup, conditionalAction, navigate, goBack, serverAction,
showSnackbar (as toast), showToast, openUrl, copyToClipboard, share, lifecycle. Cut for now: add,
update and deleteComponent, updateSubPage, animateForward and Reverse, openDialog, closeDialog,
openDrawer, switchTab, persistState, clearState, refetchPage, debugLog.
Adapters: OrcaClient (caps headers), Renderer and Registry, Navigation (one NavigationStack),
Presentation (toast only), System (clipboard, share, openUrl). Cut: Storage, sheets, alerts, TabView.

### Cut entirely from the alpha
Offline and static flows, plugins, devtools WebSocket, telemetry, animations (tween values decode but do
not animate), Compose (follows), the mirror (local path dependency from examples/app-ios until publish).

### Slices, shape only; stage 07 sizes them
S0 contract: re-sync action.schema.json to 28 kinds; targets field on all 92 widgets (the iOS orphans
   without ios); action fixtures for the 12 kinds; the Flutter SDK runs both fixture sets.
S1 skeleton core: Swift models, resolver, store; XCTest passes render fixtures 01-24. No UI yet.
S2 skeleton UI: OrcaClient, renderer with the 15, counter page on an iPhone; snackbar as a toast.
S3 executor: 12 kinds with effects; action fixtures pass; basic-actions and server-actions run.
S4 degrade: FallbackPrompt, debug placeholder, graceful strip; capability-demo runs; the six extras.
S5 publish: mirror, tag 0.1.0-alpha.1, Epic 23b, User_Actions entry, README experimental banner.
S6 Compose: S1 to S4 in Kotlin against the same fixtures; Maven Central with its User_Actions entry.

### Carried
None. Scope is now sized; the spec source (action fixtures first) is S0.
