# 09 · Implementation · native-parity-s14

## Front page

### In one breath
group 1 of 7 · tasks: 1 green, 0 blocked · cases: C14.1-C14.5 Flutter fixtures green · all green
T1: 14 offline cases Flutter runs through its real preload and flow cache; 7 breaks caught.
Flutter matched every row correction; its two quirks are pinned on purpose and said so.

### New for you
nothing new

### Trade-offs
1 auto-decided: a /config failure pinned by status, not Flutter's text (the natives carry a status)

### Questions for you
1. Blocked tasks: none. (default: none)
2. Next: group 2 (the store, the flow cache and preload in both cores). (default: go)
3. needs: decision 3 for G5-G7: persistState/clearState in all three SDKs, or drop. (default: wait)

## Appendix

### Group 1
#### T1 · Offline fixtures, Flutter as oracle (6835ab0)
Files: schema/offline-fixture.schema.json (new) · schema/fixtures/offline/01_static_flow_boot.json (new) ·
schema/fixtures/offline/README.md (new) · sdk/test/conformance/offline_fixtures_test.dart (new) ·
schema/navigation-config.schema.json
Cases: C14.1/F-C14.5/F → green (flutter test 364 = 349 + 15; analyze clean; red first; 7 deliberate breaks caught)
Changed: a draft-07 format; 14 cases (first boot, fresh, fresh with no saved config, stale, offline with a saved
config, a /version 500 is offline, offline with nothing saved, forceUpdate, cleanup, an unversioned removed flow keeps
its pages, a dynamic route never served, the cache never reads the config's pages, the unversioned-flow quirk, a stale
/config failure with no fallback); the runner drives Flutter's real OrcaApp.preload + StaticFlowManager over MockClient
and an in-memory SharedPreferencesAsync; forceUpdate's schema description now says it blocks with its screen.
Decisions: the store fake implements SharedPreferencesAsync (no new dependency) · a /config failure as {status} ·
the store after checked by key set, exact versions, pages by path set
Review fit: pass · Review quality: pass

### Test run
Group 1 (..6835ab0): sdk `flutter test` 364, `flutter analyze` clean · engine `bun test` 751 · Swift and Kotlin
unchanged (no file of theirs touched). Files changed: the task's only.

### Blocked
none

### Not done
none

### For ship (stage 10) to know
- G5-G7 wait on the user's decision 3 (persistState/clearState).
