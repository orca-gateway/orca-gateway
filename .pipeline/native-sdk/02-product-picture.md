# 02 · Product picture · native-sdk

## Front page

### In one breath
One Orca backend, three SDKs (Flutter, SwiftUI, Compose), identical state and behaviour; the look
follows a tiered catalog: core renders everywhere, material maps to platform idioms or degrades,
flutter-only stays Flutter. Fresh clients: the wire and the Flutter SDK may still change to fit.

### New for you
1. Capability profiles (core + extension tiers) → learning/capability-profiles.md

### Trade-offs
1 auto-decided: fresh clients, no backward-compatibility constraint (your call, 2026-11-05).
2 needs you: catalog shape, tiered core/material/flutter-only vs one flat catalog, per-SDK ad hoc.
3 needs you: wire names, keep Flutter names as Orca's vocabulary vs rename now while it is free.
4 needs you: material tier on iOS, platform idioms vs Material look vs unsupported (degrade).

### Questions for you
1. Promise on the box? (default: same state and behaviour everywhere; the look follows the tier)
2. Packages? (default: Swift Package OrcaGateway via SPM; com.orcagateway:sdk via Maven Central)
3. Where do tiers live? (default: a tier field per widget in widget-registry.json, for every SDK)
4. Day-one story? (default: OrcaApp(baseUrl:) renders the counter example server, unchanged)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-discover module replaces it.

### Picture
Who: an iOS or Android team that will not adopt Flutter. They install one package, write
OrcaApp(baseUrl:), point it at the same Bun server the Flutter app uses, and pages, flows, tabs,
state and server actions behave exactly as in the Flutter app. Only the look follows the tier.

### Tier sketch (estimate; the version 0 mapping doc fixes it)
core ≈63: layout, text, image, icon, inputs, progress, gestures, clips, basic animation; everywhere.
material ≈20: Scaffold, AppBar, BottomNav, Drawer, BottomSheet, Dialog, SnackBar, FAB, Card,
buttons, PullToRefresh, Tooltip; on iOS: idiom, Material look, or degrade, per trade-off 4.
flutter-only ≈9: slivers, SliverAppBar, IntrinsicWidth/Height, Baseline, Hero; caps vector says no.

### Mechanism
Tiers need no new runtime: Epic 25b's capability vector already declares per-widget support, so a
tier is a manifest field plus a policy default. With fresh clients this can land as a breaking change.

### Carried from 01, still open
platform order (Compose vs SwiftUI first) · scope (thin alpha vs parity) · spec source (action fixtures).
