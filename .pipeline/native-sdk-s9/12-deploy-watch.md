# 12 · Deploy watch · native-sdk-s9

## Front page

### In one breath
PR #16 is open (feat/native-sdk-s9 → main), bound here with Auto-fix off; main merged in first,
no change to the tree. Its CI had not reported yet when this card was written; the PR bar shows it.
You merge. Nothing deploys or releases. The emulator and the UAT server are stopped.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Merge PR #16 once its checks are green (you merge; I read its state on your reply). (default: ok)
2. After A, once merged: 13-16 skipped (no deployed surface), S9 closed, 23b.27d ticked,
   the failed-Image "!" added to 23b.33. (default: yes)
3. Next: S10 (23b.27e), `0.1.0-alpha.1` on Maven Central. (default: go)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #16
https://github.com/orca-gateway/orca-gateway/pull/16, opened at this stage (gate 10 answer 2,
"A"), bound to this session, Auto-fix off, auto-merge off. Title "feat(sdk-kotlin): degrade
policies, the 426 page, ten widgets and OrcaTheme (S9)". Before the push, `origin/main` (48f8033,
PR #15's merge) was merged in through the app (8d781c0): one conflict in `.pipeline/tradeoffs.jsonl`
(main's side added nothing; S9's seven entries kept, the file checked as valid JSON lines); the
merge changed no file in the tree (`git diff 49a266e 8d781c0` empty), so the last build stands:
core 113, sdk 127, lint 0. The PR: 65 files, +7144 −273 over main; 18 S9 code commits
(S9.1-S9.16, S9.6b, S9.11b), the S9 pipeline notes, and five copies of PR #15's commits that add
no diff. Expected workflows: SDK Kotlin CI (JDK 17 and 21), and the Swift workflows and Schema CI
if their paths match (Swift's recording of the demo page changed). Read once at this card: no
checks reported yet.

### Cleanup
- The example server on :8097 is stopped (it ran five times: graceful, warn, require, min SDK 99,
  then the fixed demo page); the emulator is closed (`adb emu kill`).
- Docker on 8080, the bun on 8091 and your Orca Gateway DevTools app on 127.0.0.1:6363 were not
  touched (DevTools is still running).
- An iPhone 16 Pro (iOS 18.5) simulator ran Swift's GoldenTests and StackTests for S9.16;
  xcodebuild left it shut down.

### What S9 leaves for later
- 23b.33: a failed or empty Image draws an empty box on Android, where Flutter and iOS draw "!"
  (gate 10 answer 3, "A"); with S8's list (the six Dart corners, Swift's three flex drifts).
- F4 at 10: the example server's banner prints port 8080 whatever `PORT` says (cosmetic).
- A public builder hook for hosts (08 F4), the DevTools compression reply (S8 F1), keeping the
  page stack across rotation (S7 F1).
- S10 (23b.27e): Maven Central needs your Sonatype Central account, a namespace and a signing
  key; the steps go to `docs/User_Actions.md` when S10 runs.

### Next
On A after your merge: stages 13-16 skipped with the reason "S9 has no deployed surface; skipped
by the default accepted at gate 12 (A)", S9 closed, row 23b.27d ticked in the epic plan and the
failed-Image item added to 23b.33. S10 starts from main on your go.

### Closed (gate 12, "A", 2026-11-07)
PR #16 merged at 19:26:55Z as 738b78f (head c90d3e0). Its checks at c90d3e0, 6 of 6 success: SDK
Kotlin CI on JDK 17 and 21, SDK Swift CI core tests (swift 5.10-jammy, 6.2-noble), SDK Swift UI
CI (iOS simulator), Schema CI codegen drift. Stages 13-16 skipped ("S9 has no deployed surface;
skipped by the default accepted at gate 12 (A)"). Epic plan: 23b.27d ✅ Done; 23b.33 gains
Kotlin's failed-Image "!". These closing notes ride on feat/native-sdk-s10, cut from main.
