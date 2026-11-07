# 10 · UAT · native-sdk-s10

## Front page

### In one breath
PR #17 is open (feat/native-sdk-s10 → main), bound here, Auto-fix off; main had not moved.
Its two SDK Kotlin CI checks (JDK 17, 21) were pending at this card; JDK 17 runs maven-verify.
S10 has no screen to try: its proof is the 09 rehearsals and this CI. Nothing is published.
The release is yours after the merge: User_Actions "Maven Central publishing", Steps 1-6.
Epic row 23b.27e now reads "S10 PR #17".

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. UAT, optional: in this worktree run `bash scripts/release.sh`, type 10, press Return,
   answer `n` at "Proceed?" (nothing changes). (default: skip it)
2. Merge PR #17 once its checks are green (you merge; I read its state on your reply). (default: ok)
3. After A: 11 skipped by default; 12 watches PR #17, your merge and, after your release, the
   "SDK Kotlin Publish" run. (default: yes)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #17
https://github.com/orca-gateway/orca-gateway/pull/17, opened at this stage on gate 09's "A"
(question 1, default yes), bound to this session, Auto-fix off, auto-merge off. Title
"feat(sdk-kotlin): release the Android SDK to Maven Central (S10)". Before the push,
`origin/main` was still 738b78f (PR #16's merge), already in the branch, so nothing was merged.
The PR: 26 files, +1344 −53 over main, in 12 commits:
- code, one per task: S10.1 67a3191, S10.3 6b50b14, S10.2 a9d349e, S10.4 6d26eba, S10.1b 830927a,
  S10.5 52097b2;
- the S9 closing notes and the S10 pipeline notes.
Read once at this card (`get_status`): mergeable; 2 checks pending, 0 passing, 0 failing.
Expected: SDK Kotlin CI on JDK 17 and 21. The JDK 17 leg also stages the publication and runs
`bash scripts/maven-verify.sh` on it, which is M10 on a real runner. The Swift and Schema
workflows don't match this PR's paths. The body is in the session scratchpad (`pr-s10.md`).

### What UAT covers here
There's no app change to tap through. The cases ran at 09:
- M1-M5: release.sh, in throwaway clones against a local bare origin.
- M6-M8, M15: the staging repo, signing with a throwaway key, the baseline build.
- M9: maven-verify against the staging repo.
- M11: each step of the publish workflow, as bash.
- M16: the scratch app's compile classpath.
- M13 and M14: the docs, reviewed against the code.
M10 runs in this PR's CI. M12 (the verify job against Central) runs only on your real tag.

Question 1 is the one hands-on look:
- release.sh from this worktree lists `10) sdk-kotlin 0.1.0-alpha.1 (maven)`.
- It checks your JDK and Android SDK and asks keep/next/release.
- At "Proceed?", `n` stops it with nothing written.
It needs a clean tree (this worktree is clean) and runs `git push --dry-run` as its login check.

### After the merge (yours, User_Actions "Maven Central publishing")
1. A Central Portal account, the `com.orcagateway` namespace (a DNS TXT record on
   orcagateway.com), a signing key, a publishing token, and the four Actions secrets.
2. Step 6, from your `open-source` folder, with `JAVA_HOME` and `ANDROID_HOME` exported:
   `bash scripts/release.sh`, then 10, Return, y.
3. Watch "SDK Kotlin Publish". Its verify job ends 23b.27e: `com.orcagateway:sdk:0.1.0-alpha.1`
   resolves from a clean Gradle project.
Also yours: copying `docs-site/docs/guides/android-sdk.mdx` into your checkout (09 question 2;
the command is in 09's appendix).

### Cleanup
- No server or emulator ran in S10.
- Throwaway clones, scratch Gradle projects and logs are in the session scratchpad
  (`scratchpad/s10/`). The throwaway signing keys were deleted after their runs.
- Not touched: Docker on 8080, the bun on 8091, and your DevTools app on 6363.

### Next
- 11 Release: skipped by default (config.json). The Maven Central release is yours after the
  merge, with release.sh.
- 12 Deploy watch: PR #17's CI, your merge, then the "SDK Kotlin Publish" run once you tag.
