# 12 · Deploy watch · native-sdk

## Front page

### In one breath
PR 1 is open (orca-gateway/orca-gateway#1, 84 files), with its companion orca-gateway/cloud#1.
First CI read: codegen drift and one test job green; the Flutter and cloud Go jobs still running.
main has no branch protection, so merging is one click; S0 reaches no user, so the watch is CI only.

### New for you
Nothing new.

### Trade-offs
1 needs you: squash (one commit per slice on main) vs merge commit (keeps the two); default: squash.
2 needs you: Auto-fix on PR 1 (the app wakes me on CI, conflicts, comments) vs manual; default: on.
3 needs you: protect main now (require the 3 workflows) vs later; default: later, release epic.

### Questions for you
1. Who merges PR 1 when green? (default: you; I never merge without your words)
2. Merge order, open-source first then cloud? (default: yes; the Go registry mirrors the manifest)
3. After the merge, start S1 (23b.9-12, Swift package + models) as /pipeline:start? (default: yes)
4. Stages 13-16 (health, behaviour, feedback) for S0, which has no runtime surface? (default: skip)

## Appendix

**Placeholder:** this stage is rendered by pipeline-core; the pipeline-ship module replaces it.

Links: https://github.com/orca-gateway/orca-gateway/pull/1 (feat/native-sdk-s0 → main, +4418/−342, 84 files incl. `.pipeline/`) and https://github.com/orca-gateway/cloud/pull/1 (chore/native-sdk-s0-registry → main, registry only). Bodies cross-link each other.
Opened with the `amrebada` gh login per command (`GH_TOKEN`), since the active gh account `amrebada-eg` is not a collaborator; your active gh account was not switched.
First CI read (one read, no polling): open-source `Codegen drift detection` pass, `test` pass ×1, `test` pending ×1 (each workflow runs twice: push + pull_request); cloud `app-server` test pending. Both PRs report MERGEABLE, no reviews requested.
What the watch covers: schema drift (manifest + TS registry), engine tests, SDK tests, cloud app-server build. What it cannot: nothing deploys, no user sees S0; the first observable surface is the counter page on iOS in S2.
Bookkeeping: this artifact and its card are not yet committed; they ride along on the next `.pipeline/` commit on the branch (before merge, so the gate history lands with PR 1).
Known local-only failure, not in CI: the caps-412 engine test needs port 8080 (Docker holds it here).
