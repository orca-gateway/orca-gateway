# 10 · UAT · native-sdk

## Front page

### In one breath
S0 has one behaviour a person can see: a page that declares targets and uses a Checkbox logs one
warning per page in dev. I ran it through the real pipeline (text in the appendix). The rest is
tests, 12 engine and 24 SDK, all green. Nothing reaches a phone until S2 draws the counter on iOS.

### New for you
Nothing new.

### Trade-offs
1 needs you: accept S0 on my run plus the tests vs rerun the 3 commands yourself; default: my run.
2 needs you: 11 Release skipped (config) vs publish engine+sdk patch now; default: skip until S2.
3 needs you: S1-S6 as one /pipeline:start each with 01-07 skipped vs B back to 09 here; default new.

### Questions for you
1. Warning wording, "uses widgets outside its declared targets ... (not on ios)"? (default: keep)
2. At stage 12, push feat/native-sdk-s0 and open PR 1 against main? (default: yes, CI is the watch)
3. Push cloud chore/native-sdk-s0-registry and open its PR at the same time? (default: yes)
4. Commits are in: open-source 5153c3f, cloud 8d9c7d0. Amend anything before the push? (default: no)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

Walk, 3 commands from `open-source/`:
1. `cd engine && bun test test/action-schema-sync.test.ts test/widget-targets.test.ts test/target-check.test.ts` → 12 pass
2. `cd sdk && flutter test test/conformance test/watch_builder_dotted_key_test.dart` → 24 pass
3. `cd engine && bun run /private/tmp/claude-501/-Users-amrebada-workspace-orca-gateway-open-source/b3e64ae2-6aaa-4ac3-aa8e-a056a2edc500/scratchpad/uat-off-target.ts` → first render logs once, second render is silent
Observed on 3: `[orca] page "settings" uses widgets outside its declared targets: Checkbox (not on ios). Those clients will degrade them via the capability vector.`
Commits: open-source `5153c3f` on `feat/native-sdk-s0` (25 files + `.pipeline/`); cloud `8d9c7d0` on `chore/native-sdk-s0-registry` (registry only).
Left alone in cloud: `go.work.sum` (touched by `go build`) and an untracked `agent-result-code-mindmap.html` that is not from this work.
Not accepted here because it does not exist yet: anything a phone shows; the first visible UAT is the counter page in S2.
Next: 11 Release is skipped by default (config.json); 12 Deploy watch for S0 means PR 1 CI (schema diff, engine, SDK, cloud registry diff).
