#!/usr/bin/env bash
#
# Publishes the iOS SDK to its SwiftPM mirror and checks what was published
# (Epic 23b, task 23b.25). SwiftPM resolves a package from a repository root
# with bare X.Y.Z tags, so sdk-swift/ is split out of the monorepo with
# `git subtree split` and pushed to orca-gateway/orca-gateway-swift.
#
# .github/workflows/sdk-swift-mirror.yml runs it on every sdk-swift-v<X> tag
# that scripts/release.sh pushes. It runs the same way against a local bare
# repository, which is how a release is rehearsed:
#
#   bash scripts/swift-mirror.sh publish sdk-swift-v0.1.0-alpha.1 /tmp/orca-gateway-swift.git
#   bash scripts/swift-mirror.sh verify  file:///tmp/orca-gateway-swift.git 0.1.0-alpha.1 run
#
#   publish <tag> <remote>   split the tag's sdk-swift/, check it builds on its
#                            own, push it to <remote> main (fast-forward only)
#                            and tag it there with the bare version.
#   verify <url> <version> <mode>
#                            resolve the mirror at exactly <version> from a
#                            scratch package, as an app would, and:
#                              run  build and run it (Linux or macOS): it
#                                   prints sdkSemver, which must equal <version>
#                              ios  build it for the iOS simulator (macOS)
#
# Environment: SWIFT_DOCKER_IMAGE makes `publish` build the split tree in that
# Linux swift image (CI) instead of with the local `swift`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="sdk-swift"
TAG_PREFIX="sdk-swift-v"

die() { printf "error: %s\n" "$*" >&2; exit 1; }
say() { printf "==> %s\n" "$*"; }

WORK=""
cleanup() {
  if [[ -n "$WORK" ]]; then
    git -C "$REPO_ROOT" worktree remove --force "$WORK/tree" >/dev/null 2>&1 || true
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT

publish() {
  local tag=$1 remote=$2
  [[ "$tag" == "$TAG_PREFIX"* ]] || die "tag must start with $TAG_PREFIX: $tag"
  local version="${tag#"$TAG_PREFIX"}"
  cd "$REPO_ROOT"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null || die "no tag $tag here"

  # The tag must match what the package says it is.
  local file_version
  file_version=$(git show "$tag:$PREFIX/VERSION" | tr -d '[:space:]')
  [[ "$file_version" == "$version" ]] \
    || die "$tag holds $PREFIX/VERSION $file_version, not $version"

  say "Splitting $PREFIX/ at $tag"
  local split
  split=$(git subtree split --quiet --prefix="$PREFIX" "$tag^{commit}")
  say "Split commit $split"

  # Build the split tree alone: nothing in it may need the rest of the repo.
  WORK=$(mktemp -d)
  git worktree add --detach "$WORK/tree" "$split" >/dev/null
  [[ -f "$WORK/tree/Package.swift" ]] || die "the split has no Package.swift at its root"
  [[ -f "$WORK/tree/LICENSE" ]] || die "the split has no LICENSE"
  say "Building the split tree on its own"
  if [[ -n "${SWIFT_DOCKER_IMAGE:-}" ]]; then
    docker run --rm -v "$WORK/tree:/src" -w /src "$SWIFT_DOCKER_IMAGE" swift build
  else
    (cd "$WORK/tree" && swift build)
  fi

  # main only moves forward. A rerun of an older tag leaves it where it is.
  local remote_main
  remote_main=$(git ls-remote "$remote" refs/heads/main | cut -f1)
  if [[ -z "$remote_main" ]]; then
    say "The mirror is empty: main starts at $split"
    git push "$remote" "$split:refs/heads/main"
  elif [[ "$remote_main" == "$split" ]]; then
    say "The mirror's main is already $split"
  else
    git fetch --quiet "$remote" refs/heads/main
    if git merge-base --is-ancestor "$split" FETCH_HEAD; then
      say "The mirror's main already contains $split; it stays"
    else
      # Not a fast-forward: the push fails, and says so, rather than force.
      git push "$remote" "$split:refs/heads/main"
    fi
  fi

  # Tags are fixed: an existing tag on another commit stops here. ls-remote
  # lists an annotated tag's commit as <tag>^{}, after the tag itself.
  local remote_commit
  remote_commit=$(git ls-remote "$remote" "refs/tags/$version" "refs/tags/$version^{}" \
    | tail -1 | cut -f1)
  if [[ -n "$remote_commit" ]]; then
    [[ "$remote_commit" == "$split" ]] \
      || die "the mirror already has $version on $remote_commit, not $split"
    say "The mirror already has $version on $split"
  else
    git push "$remote" "$split:refs/tags/$version"
  fi
  say "Published $version ($split)"
}

verify() {
  local url=$1 version=$2 mode=$3
  case "$mode" in run|ios) ;; *) die "unknown mode: $mode (run or ios)" ;; esac
  local identity
  identity=$(basename "$url" .git)
  WORK=$(mktemp -d)
  mkdir -p "$WORK/Sources/MirrorCheck"

  # SwiftPM executables do not build for iOS, so `ios` checks a library.
  local target="executableTarget" products="" source="main.swift" last
  last='print(GeneratedCapabilities.sdkSemver)'
  if [[ "$mode" == "ios" ]]; then
    target="target"
    products='    products: [.library(name: "MirrorCheckLib", targets: ["MirrorCheck"])],'
    source="MirrorCheck.swift"
    last='public let sdkSemver = GeneratedCapabilities.sdkSemver'
  fi

  cat >"$WORK/Package.swift" <<SWIFT
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MirrorCheck",
    platforms: [.iOS(.v16), .macOS(.v13)],
$products
    dependencies: [
        .package(url: "$url", exact: "$version"),
    ],
    targets: [
        .$target(name: "MirrorCheck", dependencies: [
            .product(name: "OrcaGatewayCore", package: "$identity"),
            .product(name: "OrcaGateway", package: "$identity"),
        ]),
    ]
)
SWIFT

  # The SwiftUI layer, where SwiftUI exists: the root view an app embeds.
  cat >"$WORK/Sources/MirrorCheck/$source" <<SWIFT
import OrcaGatewayCore
#if canImport(SwiftUI)
import OrcaGateway
public let rootView: Any.Type = OrcaApp.self
#endif

$last
SWIFT

  cd "$WORK"
  say "Resolving $url at exactly $version"
  swift package resolve
  if [[ "$mode" == "run" ]]; then
    swift build
    local printed
    printed=$(swift run --skip-build MirrorCheck | tail -1)
    [[ "$printed" == "$version" ]] \
      || die "the mirror at $version reports sdkSemver $printed"
    say "The mirror at $version builds and reports sdkSemver $printed"
  else
    xcodebuild -quiet -scheme MirrorCheck \
      -destination "generic/platform=iOS Simulator" build
    say "The mirror at $version builds for the iOS simulator"
  fi
}

case "${1:-}" in
  publish) [[ $# -eq 3 ]] || die "usage: $0 publish <tag> <remote>"; publish "$2" "$3" ;;
  verify)  [[ $# -eq 4 ]] || die "usage: $0 verify <url> <version> <run|ios>"; verify "$2" "$3" "$4" ;;
  *) die "usage: $0 publish <tag> <remote> | verify <url> <version> <run|ios>" ;;
esac
