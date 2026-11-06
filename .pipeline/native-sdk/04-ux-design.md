# 04 · UX design · native-sdk

## Front page

### In one breath
Three experiences: the native developer's day one (add package, one bootstrap line, pages appear),
the backend author's targets feedback (encode-time warning, surfaced in devtools), and the end user
on iOS: Scaffold as NavigationStack + toolbar, snackbar as a bottom toast, orphans degrade quietly.

### New for you
1. Design tokens (named roles, not raw values) → learning/design-tokens.md

### Trade-offs
1 needs you: iOS snackbar (counter's Reset uses it); default a bottom toast overlay, not silence.
2 needs you: iOS navigation, one NavigationStack per app (pages pushed) vs per page; default app.
3 needs you: author warnings, encode-time log and devtools vs TS types per target; default both.
4 needs you: degraded widget look, invisible vs debug-only placeholder card; default debug card.

### Questions for you
1. iOS UX first? (default: yes; Compose mirrors Material 3, so its UX is already the Flutter UX)
2. Bootstrap? (default: OrcaApp(baseUrl:appId:) in SwiftUI, OrcaApp(baseUrl, appId) in Compose)
3. Theme source? (default: the host app's theme; prop colors and fonts map 1:1; none on the wire)
4. Loading and error screens? (default: platform spinner; OrcaError and FallbackPrompt mirrored 1:1)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-discover module replaces it.

### Developer day one
iOS: Xcode > Add Package > github.com/orca-gateway/orca-gateway-swift (the mirror), 1.0.0. Root view:
OrcaApp(baseUrl: URL("http://localhost:3000"), appId: "counter"). Pages appear. Debug builds print the
capability vector sent and every widget the server degraded.
Android: implementation("com.orcagateway:sdk:1.0.0"); setContent { OrcaApp(baseUrl, appId) }.

### Backend author
PageDefinition.create({ targets: ["ios", "android"] }) makes the encoder log "off-target widget Drawer
on ios" once per page in dev; the devtools error screen lists them. TS types per target can follow.

### End user on iOS: the counter page
Scaffold becomes NavigationStack with .navigationTitle("Counter Example") and an inline toolbar.
Center, Column, Row, SizedBox and Text map 1:1; ElevatedButton becomes Button(.borderedProminent).
ShowSnackbar("Counter reset to 0") becomes a two-second bottom toast (trade-off 1). With that, nothing
in the counter page degrades on iOS.

### Degrade on native
graceful: node stripped; debug builds show a thin grey card "Drawer: not on iOS" (trade-off 4).
warn: page plus a FallbackPrompt banner in the Flutter SDK's colours. require: full-page FallbackPrompt.

### Carried, still open
scope (thin alpha vs parity) · spec source (action fixtures first). Platform order is question 1.
