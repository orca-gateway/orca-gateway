#!/usr/bin/env bash
#
# Publishes a Swift package of this repository to its SwiftPM mirror and
# checks what was published (Epic 23b, task 23b.25). SwiftPM resolves a
# package from a repository root with bare X.Y.Z tags, so the package's
# directory is split out of the monorepo with `git subtree split` and pushed
# to its own repository: sdk-swift/ to orca-gateway/orca-gateway-swift, a
# plugin's iOS package (plugins/<name>/ios/) to its own mirror. The tag says
# which: PACKAGES below holds one line per package.
#
# .github/workflows/sdk-swift-mirror.yml runs it on every sdk-swift-v<X> and
# orca_<name>-ios-v<X> tag that scripts/release.sh pushes. It runs the same
# way against a local bare repository, which is how a release is rehearsed:
#
#   bash scripts/swift-mirror.sh publish sdk-swift-v0.1.0-alpha.1 /tmp/orca-gateway-swift.git
#   bash scripts/swift-mirror.sh verify  file:///tmp/orca-gateway-swift.git 0.1.0-alpha.1 run
#
#   publish <tag> <remote>   split the tag's package directory, check it
#                            builds on its own, push it to <remote> main
#                            (fast-forward only) and tag it there with the
#                            bare version.
#   verify <url> <version> <mode>
#                            resolve the mirror at exactly <version> from a
#                            scratch package, as an app would, and:
#                              run  build and run it (Linux or macOS): it
#                                   prints sdkSemver, which must equal <version>
#                              ios  build it for the iOS simulator (macOS)
#                            The package is the one whose mirror has the
#                            url's name (orca-gateway-swift.git: sdk-swift),
#                            so a rehearsal's bare repository keeps that name.
#                            A plugin has no version to print: `run` builds a
#                            scratch library that imports it (macOS).
#   info <tag>               print the tag's version, mirror, deploy key
#                            secret and whether it is a plugin, as the
#                            name=value lines the workflow reads.
#
# Environment: SWIFT_DOCKER_IMAGE makes `publish` build the split tree in that
# Linux swift image (CI) instead of with the local `swift`.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# One line per package; the next plugin adds its own:
#   tag prefix|directory|mirror (owner/name on GitHub)|deploy key secret|library
# The secret, in the repository's Actions secrets, holds the private half of a
# deploy key with write access on the mirror (docs/User_Actions.md). The
# library is the plugin's product a scratch app imports; sdk-swift's check is
# its own (sdkSemver), so it has none.
PACKAGES=(
  "sdk-swift-v|sdk-swift|orca-gateway/orca-gateway-swift|SWIFT_MIRROR_DEPLOY_KEY|"
  "orca_voice_recorder-ios-v|plugins/orca_voice_recorder/ios|orca-gateway/orca-voice-recorder-swift|ORCA_VOICE_RECORDER_SWIFT_DEPLOY_KEY|OrcaVoiceRecorder"
  "orca_video_player-ios-v|plugins/orca_video_player/ios|orca-gateway/orca-video-player-swift|ORCA_VIDEO_PLAYER_SWIFT_DEPLOY_KEY|OrcaVideoPlayer"
  "orca_google_map-ios-v|plugins/orca_google_map/ios|orca-gateway/orca-google-map-swift|ORCA_GOOGLE_MAP_SWIFT_DEPLOY_KEY|OrcaGoogleMap"
  "orca_push_notification-ios-v|plugins/orca_push_notification/ios|orca-gateway/orca-push-notification-swift|ORCA_PUSH_NOTIFICATION_SWIFT_DEPLOY_KEY|OrcaPushNotification"
)
TAG_PREFIX="" PREFIX="" MIRROR="" SECRET="" LIBRARY=""

die() { printf "error: %s\n" "$*" >&2; exit 1; }
say() { printf "==> %s\n" "$*"; }

# Sets TAG_PREFIX, PREFIX, MIRROR, SECRET and LIBRARY from the line whose tag
# prefix starts $2 (by_tag) or whose mirror is named $2 (by_mirror).
find_package() {
  local by=$1 key=$2 line known=""
  for line in "${PACKAGES[@]}"; do
    IFS='|' read -r TAG_PREFIX PREFIX MIRROR SECRET LIBRARY <<<"$line"
    case "$by" in
      by_tag) [[ "$key" == "$TAG_PREFIX"* ]] && return 0; known+=" $TAG_PREFIX" ;;
      by_mirror) [[ "$key" == "${MIRROR#*/}" ]] && return 0; known+=" ${MIRROR#*/}" ;;
    esac
  done
  [[ "$by" == by_mirror ]] && die "no package has the mirror $key (one of:$known)"
  die "tag must start with one of$known: $key"
}

# Cleanup never decides the outcome: under `set -e` a failing command in an
# EXIT trap becomes the script's exit status, which once failed a release
# whose pushes had all succeeded (sdk-swift-v0.1.0-alpha.1, run 42296248558).
WORK=""
cleanup() {
  if [[ -n "$WORK" ]]; then
    git -C "$REPO_ROOT" worktree remove --force "$WORK/tree" >/dev/null 2>&1 || true
    rm -rf "$WORK" 2>/dev/null || true
    git -C "$REPO_ROOT" worktree prune >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

publish() {
  local tag=$1 remote=$2
  find_package by_tag "$tag"
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
    # The container runs as root. Its build products go to the container's
    # own /tmp, so nothing root-owned is left in the runner's tree.
    docker run --rm -v "$WORK/tree:/src:ro" -w /src "$SWIFT_DOCKER_IMAGE" \
      swift build --scratch-path /tmp/split-build
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
  find_package by_mirror "$identity"
  if [[ -n "$LIBRARY" ]]; then verify_plugin "$url" "$version" "$mode" "$identity"; return; fi
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

# A plugin's check: a scratch library that imports it, built for macOS (run)
# or the iOS simulator (ios). The plugin has no version to print, and needs
# Apple-only frameworks (SwiftUI, through OrcaPlugin; AVFoundation, MapKit,
# UserNotifications), so it has no Linux run.
verify_plugin() {
  local url=$1 version=$2 mode=$3 identity=$4
  WORK=$(mktemp -d)
  mkdir -p "$WORK/Sources/MirrorCheck"
  cat >"$WORK/Package.swift" <<SWIFT
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MirrorCheck",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "MirrorCheckLib", targets: ["MirrorCheck"])],
    dependencies: [
        .package(url: "$url", exact: "$version"),
    ],
    targets: [
        .target(name: "MirrorCheck", dependencies: [
            .product(name: "$LIBRARY", package: "$identity"),
        ]),
    ]
)
SWIFT
  printf 'import %s\n' "$LIBRARY" >"$WORK/Sources/MirrorCheck/MirrorCheck.swift"

  cd "$WORK"
  say "Resolving $url at exactly $version"
  swift package resolve
  if [[ "$mode" == "run" ]]; then
    swift build
    say "The mirror at $version builds a package that imports $LIBRARY"
  else
    xcodebuild -quiet -scheme MirrorCheck \
      -destination "generic/platform=iOS Simulator" build
    say "The mirror at $version builds for the iOS simulator"
  fi
}

# What the workflow needs to know about a tag, as GITHUB_OUTPUT lines.
info() {
  local tag=$1
  find_package by_tag "$tag"
  printf 'version=%s\nmirror=%s\nsecret=%s\n' "${tag#"$TAG_PREFIX"}" "$MIRROR" "$SECRET"
  if [[ -n "$LIBRARY" ]]; then echo "plugin=true"; else echo "plugin=false"; fi
}

case "${1:-}" in
  publish) [[ $# -eq 3 ]] || die "usage: $0 publish <tag> <remote>"; publish "$2" "$3" ;;
  verify)  [[ $# -eq 4 ]] || die "usage: $0 verify <url> <version> <run|ios>"; verify "$2" "$3" "$4" ;;
  info)    [[ $# -eq 2 ]] || die "usage: $0 info <tag>"; info "$2" ;;
  *) die "usage: $0 publish <tag> <remote> | verify <url> <version> <run|ios> | info <tag>" ;;
esac
