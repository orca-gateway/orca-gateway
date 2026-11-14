---
name: maintainer
kind: internal, cuts every release
first_seen: launch-builds/02 2026-11-14
---
# Maintainer

**Goal**  One engine tag gives a complete public release, nothing left to finish by hand.
**Context**  Runs scripts/release.sh; DevTools tags already get a GitHub release from a workflow, engine tags none.
**Frustration**  Engine 0.3.4 shipped with no GitHub release; the root CHANGELOG.md still says "0.1.0 Unreleased".
**Comfort**  High: owns release.sh and the tag workflows; preflight checks stop a release before any change.
