# 12 · Deploy watch · native-sdk-s7

## Front page

### In one breath
PR #13 is merged (113dc06), all PR checks green; on main, SDK Kotlin and Schema passed too.
Nothing deploys or releases. The UAT server and the emulator are stopped.
Your question: buttons follow each platform's look (Material, iOS) unless something pins it.
Three ways to pin one brand look on both; the appendix compares them.

### New for you
Nothing new.

### Trade-offs
1 needs you: one look on both platforms. Default: a host theme on each side (iOS has it; Android in
  S9), plus server style props where a page needs it. Alternative: a server-wide theme (new row).

### Questions for you
1. After A: 13-16 skipped (nothing runs as a service), S7 closed, 23b.27b ticked. (default: yes)
2. Consistent look: S9 brings Android's OrcaTheme as Swift's; add a server theme row? (default: no)
3. Next: S8 (23b.27c), the adapters: navigation, URL, clipboard, share, DevTools. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #13
https://github.com/orca-gateway/orca-gateway/pull/13, merged at 09:11:20Z as 113dc06. The PR's
checks, 6 of 6 success: SDK Kotlin on JDK 17 and 21 (both modules, Robolectric, lint, the golden
compared on ubuntu, the example's debug build) and Schema (Generated.kt drift), for push and PR. On
main after the merge, at 113dc06: SDK Kotlin CI and Schema CI success. The stage 10 commit (6fdc37b)
was pushed after the merge, so it rides with S8's branch, as S6's close commits did.

### A consistent look on Android and iOS (your question at gate 10)
Today each SDK draws a button the platform's way (Material 3 on Android, iOS bordered styles), as
decided at native-sdk gates 02 and 03 ("platform idioms"). A button takes the native look only for
what nothing else sets. Three ways to make both platforms match, smallest first:
| Way | Who sets it | Covers | State |
|---|---|---|---|
| Server style props on a button | the page author | `backgroundColor`, `foregroundColor`, `borderRadius`, `borderColor`, `padding` (both SDKs); `elevation` (Android only, Swift ignores it) | works today |
| Host theme | the app developer, once per platform | every Elevated, Outlined and Text button: one closure each, e.g. a pill in the brand colour; a button the server styled keeps the server's look | iOS: `OrcaTheme` (23b.31). Android: S9 (23b.27d, "theme hooks") |
| Server-wide theme (design tokens) | the server, once per app | primary colour, corner radius, font, applied by every SDK as the defaults | not built; a wire-format change across engine, Flutter, Swift, Kotlin and a fixture (a new 23b row) |
The default keeps platform idioms and gives a brand look through the host theme. A server-wide
theme fits if the server, not each app, should own the brand; it is question 2 (default: not now).

### Cleanup
- The example server on :8097 is stopped; the emulator is closed (`adb emu kill`). Docker on 8080,
  the other bun on 8091 and DevTools on 6363 were not touched.
- The API 34 system image stays installed (reinstalled at stage 10); the API 36 one is still
  incomplete, untouched.
- The Linux golden check (copy, logs, container image `eclipse-temurin:21-jdk`) stays in the
  scratchpad and Docker's image cache.

### What S7 leaves for later
- S8: navigation adapter (NavHost routes, back, app state shared across pages), openUrl, clipboard,
  share, DevTools client and its event fixtures; the refused-caps DevTools event Swift never sends.
- A new activity fetches the page again from its initial state (F1 at 10).
- 23b.33 (after S10): the six Dart corners and Swift's three flex drifts.
- AGP 9.0.1 prints Gradle's deprecation notice in the example build.

### Next
On A, stages 13-16 are skipped with the reason "S7 has no deployed surface; skipped by the default
accepted at gate 12 (A)", S7 is closed, and row 23b.27b is ticked. S8 starts from main on your go.
