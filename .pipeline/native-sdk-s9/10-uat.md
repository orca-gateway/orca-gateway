# 10 · UAT · native-sdk-s9

## Front page

### In one breath
Your "images in cards not stretched": fixed in the demo page (S9.16, c10730b): each card's photo
now sits in a 160 dp box with an expanding Stack, so it fills the card by Flutter's rules on every
SDK. No SDK change. New test R1 failed first; both reviews passed; on the emulator the photos fill
their cards. U1 (round 1) stands: the three policies and the 426 page draw. Nothing pushed yet.

### New for you
nothing new

### Trade-offs
1 auto-decided: fix the demo page, keep the SDK's Flutter Image rule (your call, 2026-11-07).
1 noted: a failed Image draws an empty box on Android; Flutter and iOS draw "!" (S9.11, known).

### Questions for you
1. UAT: native-widgets is open on the emulator with the fix (server on :8097). (default: ok)
2. Open the PR for feat/native-sdk-s9 (18 code commits), merging main in first? (default: yes)
3. Leave the "!" for a failed Image to 23b.33, the parity row? (default: yes)
4. After A: 11 skipped by default, 12 watches the PR's CI and your merge. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### U1 on the emulator (what I ran and saw)
Pixel 3a API 34 (`sdk_gphone64_arm64`, cold boot), `examples/server` from this branch with
`PORT=8097`, restarted for each policy; the example app built from this branch
(`./gradlew :app:assembleDebug`, then `task example:android:run URL=http://10.0.2.2:8097 APP=…
PAGE=…`, later `adb shell am start` with the same extras). Docker on 8080, the bun on 8091 and
your DevTools app on 6363 untouched. Every first request: GET 412, then 200 with the Kotlin vector
(25 widgets).
| Step | Result |
|---|---|
| capability-demo `degrade`, default policy (graceful) | "Above the checkbox." and "Below the checkbox."; the Checkbox left out, no prompt |
| the same with `ORCA_FALLBACK_POLICY=warn` | orange banner "Some content needs an update … (widget.Checkbox)" above the page; the Checkbox drawn as "Unsupported content" between the two lines |
| the same with `ORCA_FALLBACK_POLICY=require` | one red "Update required … (widget.Checkbox) … update from your app store" prompt, no page |
| native-widgets `home` with `ORCA_MIN_SDK_VERSION=99.0.0` | server answers 426; the app draws "Update required: This app needs version 99.0.0 or later", not an error |
| native-widgets `home`, default server | app bar, search field, "You typed:", two cards with the picsum.photos images, badges, ratings, prices, Flex row with the gradient, Spacer row, the gesture box |
| tap the pizza heart | outlined heart → filled (fav_pizza) |
| type "pizza" in the search field | the field shows it; "You typed: pizza" below |
| tap the box | toast "Tapped" |
| double tap the box | toast "Double tapped" |
Screenshots (sent to you): the four policy pages and native-widgets before and after the taps.

### Your report at gate 10 (round 1): "images in cards not stretched"
Cause: `examples/server/native-widgets.ts` foodCard put `Image(height: 160, fit: cover)` in a
`Stack` with the default loose fit; the Orca Flutter builder (`sdk/lib/src/builders/
primitive_builders.dart` `Image.network(width: null, height: 160)`, Stack centred, `layout_builders.dart`)
then sizes the photo by its 800x480 ratio, 267 dp, centred. Kotlin follows that rule (S9.11b,
gate 09 "A"); SwiftUI's `.aspectRatio(contentMode: .fill)` filled the width, which is why iOS
looked right. So the page relied on a behaviour Flutter does not have.
Fix (S9.16, commit c10730b, a fresh implementer; fit and quality both pass): the card's Stack
sits in `Container(height: 160)` with `fit: "expand"`; Column stretch gives the Container the
card's width, the expanding Stack gives the photo the whole 361x160 dp box, `cover` fills it. No
SDK or engine change. Kotlin's recording re-recorded (one Container per card, Stack fit, ids
shifted); Swift's re-recorded too, byte-identical to Kotlin's. New test
`r1_theCardPhotoSpansTheCard`: red first on the old page ("expected:<722> but was:<0>"), green
after. G3's golden is byte-identical (an emptied Image draws nothing; the badge and heart were
already at the card's corners). Swift on the iPhone 16 Pro iOS 18.5 simulator: GoldenTests 4/4,
StackTests 5/5, its golden unchanged. Build: core 113, sdk 127, lint "No issues found".
Emulator, server restarted on the new page: both photos fill their cards edge to edge, top
corners rounded, the heart's white circle and the badge at the corners (screenshot sent).

### Findings
- F1 (round 1) The food photos were 267 dp wide, centred in a 361 dp card: the page gave the Image
  only a height inside a loose Stack, and Flutter's rule (Kotlin's since S9.11b) sizes it by its
  ratio. Fixed in round 2 at the page, below.
- F2 A failed or empty Image draws an empty box on Android (S9.11, said in `Image.kt`); Flutter's
  error builder and Swift draw "!". Question 3 leaves it to 23b.33.
- F3 adb's two `input tap` 40 ms apart did not count as a double tap: Compose, like Flutter's
  `kDoubleTapMinTime`, ignores a second tap sooner than 40 ms. With a 120 ms gap it fired. Not a bug.
- F4 The example server's banner still prints `http://localhost:8080` when started with
  `PORT=8097`; the engine line under it prints the right port. Cosmetic, examples only.

### The PR (question 2)
feat/native-sdk-s9 → main: 30 commits over origin/main (48f8033, PR #15's merge); 73 files. 18 are
S9 code (S9.1-S9.16, S9.6b, S9.11b), the rest S9 pipeline notes, and 5 are copies of PR #15's
commits (b974f47, 38b18d3, 3e63374, 3434322, d5193fb; `git cherry` shows the same patches are on
main, so they add no diff). Merging origin/main in first keeps every commit id these notes cite;
a rebase would drop the 5 copies but change all the ids. Title: "feat(sdk-kotlin): degrade
policies, the 426 page, ten widgets and OrcaTheme (S9)". On your yes I push, open it, bind it here
with Auto-fix off, and read its CI once: SDK Kotlin CI for certain, and the Swift workflows if
they watch `sdk-swift/Tests` (Swift's recording of the demo page changed).

### Next
- 11 Release: skipped by default; nothing is published before S10.
- 12 Deploy watch: the PR's CI and your merge.
- After S9: S10 (23b.27e), `0.1.0-alpha.1` on Maven Central.
