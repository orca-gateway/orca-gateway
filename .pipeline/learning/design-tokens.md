---
topic: design-tokens
status: new
first_seen: native-sdk/04 2026-11-05
seen: native-sdk/04
---
# Design tokens

**Concept**  Named roles (surface, onSurface, titleLarge) instead of raw colours and sizes; each
platform maps a role to its own value, so one page can look native everywhere.

**Why here**  Orca's wire carries raw values (fontSize 48, hex colours); the theme lives in the host
app; roles would let iOS pick SF Pro and system colours without the backend knowing.

**When not**  When pixel parity across platforms is the promise; raw values are the direct way.

**Tiny example**  { "style": { "role": "headlineLarge" } } maps to Flutter textTheme.headlineLarge,
SwiftUI .font(.largeTitle), Compose MaterialTheme.typography.headlineLarge

**Go deeper**  https://m3.material.io/foundations/design-tokens · sdk/lib/src/widgets/ (app config)
