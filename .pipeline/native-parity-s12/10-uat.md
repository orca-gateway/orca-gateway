# 10 · UAT · native-parity-s12

## Front page

### In one breath
Animation works on both native SDKs: controlled runs, four implicit widgets, Hero, route
transitions from the config, and everything jumps to its end under reduced motion.
Rows B12.1 to B12.7 pass on both, by fixtures, tests and a hand-check on an iOS simulator
and an Android emulator with the `motion` demo app.
The PR is open; the merge is yours; nothing is published.

### New for you
nothing new

### Trade-offs
1 needs you, with a default: iOS fade and slide-up animate the pushed page's content inside
NavigationStack; the plan spoke of a custom presenter. Default: keep. Said in the PR.

### Questions for you
1. Keep the in-stack iOS transitions? (default: keep)
2. Merge the step 12 PR after step 11's: yours. (default: ok; step 13 stacks on it)
3. After A: 11 skipped by default, 12 reads the PR's checks, 13 to 16 skipped. (default: yes)

## Appendix

### Hand-check, both devices (demo app `motion`, server on :8099)

| Check | iOS simulator (18.5) | Android emulator (API 34) |
|---|---|---|
| Controlled: Forward, then Reverse | box grows and darkens, shrinks back; Runs completed 1, then 2 | same |
| AnimatedContainer, Opacity, Align | size and colour, fade, bounce to the corner, all over 600 ms | same |
| AnimatedSwitcher: Swap | Side A fades out while Side B fades in | same |
| Hero: tap the square, then back | page zooms out of the square; back zooms into it | square flies to the large one and back |
| Route fade, slideUp | no system push; content fades in, or rises; back is the system pop | container fades, slides up; pop reverses |
| Route scale, slideRight, slide | system push kept (agreed subset) | each kind plays; pop reverses |

### Not covered by hand
Route kind `none` (pinned by tests on both SDKs).
Reduced motion on a device (pinned by unit tests on both SDKs, B12.7). Hero inside tabs on
Android and on iOS 17: a plain push by design, pinned by tests.
On Android a transition runs on the route container, so on a slow page it plays over the
loading spinner, as in Flutter.
