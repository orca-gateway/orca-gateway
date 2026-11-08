# 12 · Deploy watch · native-sdk-s10

## Front page

### In one breath
PR #17 merged at 22:26Z as 07d5279; SDK Kotlin CI green on JDK 17 and 21 at its head bba1141.
The JDK 17 leg staged the publication and built the scratch app from it: M10 holds on a runner.
Nothing is on Maven Central yet: no sdk-kotlin tag exists. 23b.27e's acceptance is your release.

### New for you
nothing new

### Trade-offs
none

### Questions for you
1. Release when your Sonatype steps are done (User_Actions Steps 1-6); then reply, and I read the
   "SDK Kotlin Publish" run once. (default: wait for you)
2. On a green run and your A: 13-16 skipped (no deployed service), S10 closed, 23b.27e ✅.
   (default: yes)
3. To close S10 before the release instead, say "close now": 23b.27e reads "merged, release
   yours", ticked after your first release. (default: wait)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

### PR #17
https://github.com/orca-gateway/orca-gateway/pull/17
- Merged 2026-11-07T22:26:07Z as 07d5279 (head bba1141). You merged it before gate 10's "A".
- Read once at this card:
  - checks 2 of 2 success;
  - "SDK tests and example (JDK 17, linux)": build and test, example, "Stage the Maven publication",
    "Verify a scratch consumer against the staged publication", all success;
  - "SDK tests and example (JDK 21, linux)": build and test, example success; the two Maven steps
    skipped by design (JDK 17 leg only).
- Tags: `git/matching-refs/tags/sdk-kotlin-v` is empty, so no release has started.

### What waits for your release (M12)
After User_Actions Steps 1-5 (account, the DNS TXT record for `com.orcagateway`, key, token, the
four secrets), Step 6 is: `bash scripts/release.sh` → 10 → Return → y. That pushes
`sdk-kotlin-v0.1.0-alpha.1`. "SDK Kotlin Publish" then runs two jobs:
1. "Sign and release to Maven Central".
2. "Resolve both artifacts from Maven Central": it waits up to 45 minutes for repo1.maven.org,
   then runs `scripts/maven-verify.sh` against it.
When the second job passes, 23b.27e is met. If the first job names a missing secret, fix it and
re-run.

### Cleanup
Nothing running: no server, no emulator. Scratch files stay in the session scratchpad until it is
cleared. Not touched: Docker on 8080, the bun on 8091, your DevTools app on 6363.

### What S10 leaves for later
- 23b.33, the parity row: the native SDKs match Dart in six corners, plus Kotlin's failed-Image "!"
  and Swift's three flex drifts.
- Earlier carry-overs:
  - a public builder hook for hosts (S9 08 F4);
  - the DevTools compression reply (S8 F1);
  - keeping the page stack across rotation (S7 F1);
  - the example server's banner port (S9 F4).
- Your docs-site copy of `android-sdk.mdx`, and `sidebars.ts` if it lists guides by hand.

### Next
- On a green publish run and your A: stages 13-16 skipped ("S10 has no deployed service; skipped by
  the default accepted at gate 12 (A)"), S10 closed, 23b.27e ✅ Done in the epic plan.
- Then the next slice, 23b.33, on your go.

### Closed (gate 12, "A https://github.com/orca-gateway/orca-gateway/actions/runs/42420597668", 2026-11-08)
The linked run is "SDK Kotlin CI" on the push to main (07d5279, created 22:26:10Z), not "SDK Kotlin
Publish": both legs success, the JDK 17 leg's "Stage the Maven publication" and "Verify a scratch
consumer" success. Read at closing: no `sdk-kotlin-v*` tag, 0 runs of sdk-kotlin-publish.yml, and
`repo1.maven.org/…/sdk/0.1.0-alpha.1/sdk-0.1.0-alpha.1.pom` answers 404. So the gate is approved on
your "A" and stages 13-16 skipped ("S10 has no deployed service; skipped by the default accepted at
gate 12 (A)"), but 23b.27e's acceptance (the artifact resolves from Central) is not met yet: its row
reads "S10 merged (PR #17); the Maven Central release is the deployer's (User_Actions Step 6)", not
✅. After your release, the "SDK Kotlin Publish" run's verify job is the proof; then the row is ✅.
