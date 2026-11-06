---
topic: swiftui-proposal-layout
status: new
first_seen: native-sdk/01 2026-11-05
seen: native-sdk/01
---
# SwiftUI proposal-based layout

**Concept**  Flutter pushes constraints down; children must fit, and Row splits spare space by flex.
SwiftUI proposes a size; the child picks its own. HStack/VStack lack flex and main-axis alignment.

**Why here**  Row/Column to HStack/VStack is a translation, not a rename: Spacer() for alignment,
frame(maxWidth: .infinity) + layoutPriority for Expanded, and an explicit frame since stacks hug.

**When not**  Compose. Its Row/Column, Arrangement and Modifier.weight match Flutter nearly 1:1.

**Tiny example**  Flutter: Row(mainAxisAlignment: spaceBetween, children: [A, B])
SwiftUI: HStack { A; Spacer(); B }.frame(maxWidth: .infinity)

**Go deeper**  https://developer.apple.com/documentation/swiftui/layout-fundamentals
https://docs.flutter.dev/ui/layout/constraints · engine/src/components/layout/column.ts
