# 01 · Validation · native-sdk

## Front page

### In one breath
Native SwiftUI and Compose SDKs read today's wire format; Flutter names stay on the wire.
Row/Column is not the risk: 34 of 92 widgets are Material chrome or Flutter render-model, and no
fixture pins what the 23 action kinds do. On iOS, native look vs same page everywhere: pick one.

### New for you
1. SwiftUI proposal-based layout vs Flutter constraints → learning/swiftui-proposal-layout.md

### Trade-offs
1 needs you: wire vocabulary, keep Flutter names (your idea) vs neutral names; default keep Flutter.
2 needs you: first platform, Compose (near 1:1, fast proof) vs SwiftUI (the hard one, iOS signal).
3 needs you: scope, thin alpha behind capability negotiation vs parity with the Flutter SDK.
4 needs you: Material chrome on iOS, Material look (as Flutter today) vs iOS idioms vs unsupported.

### Questions for you
1. Who is this for? (default: iOS/Android teams that will not adopt Flutter but want one backend)
2. Why now, before cloud 24-57? (default: version 0 this week; spike only if its gap list is short)
3. Success line? (default: fixtures 01-10, one setState and one serverAction round trip, a Scaffold
   page in platform chrome, and the server degrading one unsupported widget via the caps vector)
4. What is cut? (default: offline, plugins, devtools, animations, slivers; chrome per trade-off 4)
5. iOS tech: SwiftUI or Compose Multiplatform for both? (default: SwiftUI; the look is trade-off 4)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-discover module replaces it.

### Challenge (round 2, your X)
Round 1 promised "native look" and "same backend, same page" and scoped a spike that proves neither.
34 of 92 registry widgets are Material chrome (Scaffold, Drawer, SnackBar, FAB, inputs) or Flutter
render-model (slivers, Intrinsic*, Hero, Baseline). On iOS each is drawn Material (what Flutter does
today, so no regression) or re-idiomed (native, but pages diverge and nothing pins them). And the only
fixtures are 24 render fixtures: the 796-line action executor has no executable spec at all.
Answer: decide trade-off 4 first, make version 0 classify all 92 widgets, and add action fixtures to
schema/fixtures/ before any native code; the Go port (Epic 25) needs those fixtures anyway.

### Smaller versions
0. Mapping doc: classify all 92 widgets per platform as 1:1 / idiom / unsupported; list the gaps.
1. Spike: one platform renders fixtures 01-10 plus one setState and one serverAction; not published.
2. Thin alpha: ~20 widgets, values + transforms, 3 actions, caps vector; chrome per trade-off 4.

### Row/Column: are they similar?
| Flutter | Compose | SwiftUI |
|---|---|---|
| Row/Column + mainAxisAlignment | Row/Column + Arrangement (1:1) | HStack/VStack + Spacer() idiom |
| Expanded(flex) | Modifier.weight (1:1) | frame(maxWidth: .infinity) + layoutPriority |
| mainAxisSize.max default | fillMaxWidth (1:1) | hugs by default; add frame to fill |

### Kind of idea
feature: validated by demand signal and a bounded spike, not by a bug report or a ticket.
