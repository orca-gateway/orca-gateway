# 10 · UAT · native-parity-s13

## Front page

### In one breath
Reorderable lists and sub-pages work on both native SDKs, and the Flutter SDK's SubPage now
follows the same written contract. Rows B13.3, B13.4 and B13.5 pass on both, by shared
fixtures, tests and a hand-check on an iOS simulator and an Android emulator.
Rows B13.1 and B13.2 (sliver widgets) are not built: they need Phase A step 5 on main.
The PR is open; the merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
1 your call, taken: the SubPage contract is defined and Flutter is fixed to follow it.
1 for you to know: this changes how SubPage behaves in the Flutter SDK (it was half working).

### Questions for you
1. Merge the step 13 PR after step 12's (#41): yours. (default: ok)
2. Sliver widgets in a later PR, once Phase A step 5 is on main? (default: yes)
3. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

### Hand-check, both devices (demo apps `reorder` and `subpage`, server on :8099)

| Check | iOS simulator (18.5) | Android emulator (API 34) |
|---|---|---|
| Reorder: row 0 dropped between rows 2 and 3 | `0 → 3`; Bread, Coffee, Apples, Dates, Eggs | same |
| Reorder: last row to the top | not repeated by hand (tests) | `4 → 0`; Eggs first |
| SubPage loads with its param | Detail A, "Opened from: the host page" | same |
| Host +1, sub-page +1, then its server action (+10) | Host count 1, Detail count 21: no clash | same |
| Join C | Detail C below Detail A, full width, own count 30, then 31 after its +1 | same |
| Replace with B | both pages gone, Detail B alone with count 20 | same |

### Not covered by hand
A nested SubPage, a failed fetch, and a sub-page kept across a list drop: pinned by tests on all
three SDKs. The Flutter demo was not run on a device; its widget tests cover the same steps.
