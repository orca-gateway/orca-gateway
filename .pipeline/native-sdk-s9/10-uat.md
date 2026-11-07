# 10 · UAT · native-sdk-s9

## Front page

### In one breath
U1 passed on the Pixel 3a (API 34), server on :8097: graceful leaves the Checkbox out, warn puts
its banner above the page, require replaces the page, min SDK 99.0.0 draws the 426 page.
native-widgets: photos load, the heart toggles, typing shows "You typed: pizza", tap and double
tap each show their toast. No bug found; nothing changed at this stage. Nothing pushed yet.

### New for you
nothing new

### Trade-offs
1 noted: the demo's photos are 267 dp wide, centred in their cards; Flutter's rule (only a height).
1 noted: a failed Image draws an empty box on Android; Flutter and iOS draw "!" (S9.11, known).

### Questions for you
1. UAT: the emulator and the server stay up for you: native-widgets is open. (default: ok)
2. Open the PR for feat/native-sdk-s9 to main (18 code commits, S9.1-S9.15)? (default: yes)
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

### Findings
- F1 The food photos are 160 dp high and 267 dp wide (800x480 kept in ratio), centred in a 361 dp
  card, the card's white at both sides. The page gives the Image only `height: 160`; Flutter's
  builder (`sdk/lib/src/builders/primitive_builders.dart` `Image.network(width: null, height:
  160)`, Stack centred and loose) sizes it the same way, which is the rule S9.11b took at gate 09.
  Read from the code, not run on Flutter. Making them fill the card is a demo-page change for every
  SDK, not S9.
- F2 A failed or empty Image draws an empty box on Android (S9.11, said in `Image.kt`); Flutter's
  error builder and Swift draw "!". Question 3 leaves it to 23b.33.
- F3 adb's two `input tap` 40 ms apart did not count as a double tap: Compose, like Flutter's
  `kDoubleTapMinTime`, ignores a second tap sooner than 40 ms. With a 120 ms gap it fired. Not a bug.
- F4 The example server's banner still prints `http://localhost:8080` when started with
  `PORT=8097`; the engine line under it prints the right port. Cosmetic, examples only.

### The PR (question 2)
feat/native-sdk-s9 → main: 28 commits over origin/main (48f8033, PR #15's merge), 18 of them code
(S9.1-S9.15, S9.6b, S9.11b), the rest pipeline notes; 69 files. Title: "feat(sdk-kotlin): degrade
policies, the 426 page, ten widgets and OrcaTheme (S9)". On your yes I push, open it, bind it here
with Auto-fix off, and read its CI once; SDK Kotlin CI is the workflow it touches (also Taskfile
and two READMEs).

### Next
- 11 Release: skipped by default; nothing is published before S10.
- 12 Deploy watch: the PR's CI and your merge.
- After S9: S10 (23b.27e), `0.1.0-alpha.1` on Maven Central.
