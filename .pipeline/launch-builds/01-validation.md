# 01 · Validation · launch-builds

## Front page

### In one breath
Go, with the image and binaries made the examples demo server, not the bare engine (a library).
Smallest: a Todo example; the demo server as a GHCR image and Linux/macOS/Windows binaries;
a GitHub release per engine tag with notes and those binaries. All go out only when you tag.

### New for you
1. the riskiest-assumption test → learning/riskiest-assumption.md

### Trade-offs
1 needs you: image and binaries, the examples demo server (default) vs drop them (23.3 + 23.8 only)

### Questions for you
1. Who is it for? (default: developers trying Orca at launch; and you, cutting releases)
2. Why now? (default: Epic 23 is the open-source launch; the SDKs are done, this is what's left)
3. Success in one line? (default: one `engine-v*` tag gives a release with notes, 3 binaries and
   a GHCR image; `docker run` of it serves the Todo example to the example Flutter app)
4. What could be cut? (default: nothing; if cut, the image and binaries go first)

## Appendix

### Riskiest assumption and its cheapest check
Assumption: someone trying Orca would run a ready-made demo server (an image or a binary) instead of cloning the
repo and running `bun run` on the examples; the example apps already need Flutter, Xcode or Android Studio.
Check: after the first tagged release, count GHCR pulls and binary downloads for two weeks (both are free to read
on GitHub). Building them is cheap because the release is tag-triggered; the count decides whether they stay.

### Challenge
Objection (challenger, serious): 23.6 and 23.7 treat a library as an app you can run. `engine/src/server.ts`
registers no app and the Dockerfile compiles exactly that stub, so the "engine" image and binaries would serve
nothing, and a developer cannot add pages to a downloaded binary; npm (`@orca-gateway/engine`) already covers
anyone with pages. Plan lines 517-518 date from scaffolding, before the engine was an npm library. 23.8's binary
assets inherit the problem.
Answer: the image and the binaries become the examples demo server (examples/server: counter, ecommerce,
server-actions … and the new Todo), a ready-to-run backend the example Flutter, iOS and Android apps point at; the
bare-engine Dockerfile goes. If you would rather not ship a demo server, question 4 cuts them.

### Smaller versions
- nothing: no Todo example; engine tags keep shipping with no GitHub release or notes; CHANGELOG.md stays at
  "[0.1.0] - Unreleased" (the engine is at 0.3.4); the stub Dockerfile keeps promising an engine image.
- smallest: the Todo example (23.3) in the examples server; the examples demo server as a GHCR image (23.6) and
  `bun build --compile` binaries for Linux, macOS and Windows (23.7); a GitHub release per `engine-v*` tag with
  notes from an up-to-date CHANGELOG and the binaries (23.8). Tag-triggered, nothing published by the build.
- full: also a Dockerfile in the `orca` CLI's project scaffold so developers ship their own server as an image;
  multi-arch images; one release-notes flow across every package release.sh tags.

### Kind of idea
feature: Epic 23's rows are the spec, written before the engine became an npm library; validation checked each
row against the repo as it is, which turned 23.6 and 23.7 from "the engine" into "the examples demo server".
