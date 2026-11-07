# 10 · UAT · native-sdk-s7

## Front page

### In one breath
PR #13 is open: feat/native-sdk-s7 → main. Both of its checks, SDK Kotlin and Schema, are green.
The counter runs on the Pixel 3a API 34 emulator: 412, retry, page; + twice shows 2; Reset shows
0 and the snackbar. The emulator and the server on :8097 are up for you; steps below.

### New for you
Nothing new.

### Trade-offs
1 done: gate 09 defaults kept. The API 34 image is reinstalled (it now has system.img); epic row
  23b.27b says PR #13; Swift's three flex drifts joined row 23b.33, after S10.
2 noted: Auto-fix stays off for #13, as for #8, #10 and #12.

### Questions for you
1. UAT: does the counter look and behave right on the emulator window? (default: ok)
2. After A: 11 skipped by default, 12 records PR #13's CI and merge, 13-16 skipped. (default: yes)
3. Next after merge: S8, the adapters (navigation, URL, clipboard, share, DevTools). (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### UAT steps
The emulator window ("Android Emulator - Pixel_3a_API_34…") shows Orca Counter, served by
`examples/server` from this worktree on :8097. Docker on 8080, the other bun on 8091 and DevTools on
6363 are untouched.
1. On the emulator: tap `+` and `-`, then Reset. The count changes; Reset shows the snackbar
   "Counter reset to 0" at the bottom for 4 seconds.
2. Relaunch, or point it at another app on the same server:
   ```
   cd /Users/amrebada/workspace/orca-gateway/open-source/.claude/worktrees/keen-leakey-4c4de7
   task example:android:run URL=http://10.0.2.2:8097
   task example:android:run URL=http://10.0.2.2:8097 APP=basic-actions PAGE=home
   ```
   basic-actions draws, but its navigation, URL, clipboard and share buttons do nothing until S8.
3. Read, on the PR branch: [examples/app-android/README.md](https://github.com/orca-gateway/orca-gateway/blob/feat/native-sdk-s7/examples/app-android/README.md),
   [sdk-kotlin/README.md](https://github.com/orca-gateway/orca-gateway/blob/feat/native-sdk-s7/sdk-kotlin/README.md),
   and the PR description.
Screenshots (sent to you): loaded at 0, after + twice at 2, after Reset at 0 with the snackbar.

### What I ran
- `sdkmanager --uninstall` then install of `system-images;android-34;google_apis;arm64-v8a`
  (revision 14, 1.6 GB from dl.google.com). The folder now has `system.img`, `vendor.img`,
  `ramdisk.img` and `userdata.img`; the AVD boots Android 14 on `sdk_gphone64_arm64`, 1080x2220,
  440 dpi. The API 36 image (Pixel 9 Pro XL AVD) is still incomplete; not touched.
- `task example:android:run URL=http://10.0.2.2:8097`: installDebug, then `am start` with the extras.
- Server log: GET `/page/home` 412, POST 200 (page rendered), and 15 s later a GET 200 with the hash
  already known (the activity was created again, so OrcaApp fetched again; no saved state yet).
- `adb shell input tap` on `+` twice and on Reset; `screencap` after each; `uiautomator dump`
  found "Counter Example", "0", "-", "+", "Reset" before the taps.

### PR #13
https://github.com/orca-gateway/orca-gateway/pull/13, opened at this stage, bound to this session,
Auto-fix off. Code commits: 66bead9, 6c1f0be, 71442c0, bf76df5, 05efc76, f3fbf37, 81cd0d5, ef57d0c,
9dd23f0. Pipeline commits: c4216b0 and 91c6b79 (S6 close), fac9ae4 (S7 stage 08), 9747822 (stage
09). origin/main had not moved since 388f1b5.
| Workflow | Push | PR |
|---|---|---|
| SDK Kotlin CI (`./gradlew build`, the example, JDK 17 and 21) | success | success |
| Schema CI (Generated.kt drift) | success | success |
The golden compared on ubuntu (its marker names only the Robolectric SDK). The other workflows did
not trigger: the PR touches no engine, Flutter or Swift path.

### Gate 09 answers carried out
- Question 1: the API 34 image is reinstalled and the emulator run is done (above).
- Question 2: row 23b.33 now also lists Swift's flex drifts (`spaceAround`, `gap` with
  `spaceEvenly` and `spaceAround`, a Column's `baseline`), with a Swift layout test per case.
- Question 3: the branch is pushed and PR #13 is open.

### Findings
- F1 A new activity (a configuration change or a relaunch) fetches the page again and starts from
  its initial state; the hash is known by then, so it is one fast GET. S8's router can keep the
  stack and app state across it.
- F2 The example build prints Gradle's "deprecated features" notice (from AGP 9.0.1); the SDK
  build does not fail on it. Worth a look when AGP is bumped.

### Next
- 11 Release: skipped by default; nothing is published before S10.
- 12 Deploy watch: PR #13's CI and the merge.
- 13-16: nothing is deployed; skipped at gate 12 as for S1 to S6.
- S8 (23b.27c): navigation (NavHost routes, back), system (openUrl, clipboard, share), DevTools
  client and its event fixtures; basic-actions and server-actions run on the emulator.
