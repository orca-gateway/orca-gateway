#!/usr/bin/env bash
#
# Interactive release tool for the Orca Gateway monorepo.
#
# Walks you through bumping versions, validating, committing, tagging, and
# publishing one or more packages in a single atomic flow. See CLAUDE.md
# (section "Releasing & version bumps") for context.
#
# Run from anywhere inside open-source/:
#   bash scripts/release.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# --- Package registry --------------------------------------------------------
# Each line:  name|path|tag-prefix|publisher|version-file
# publisher ∈ { npm, pub, github-release, mirror, maven }
#   mirror: the tag push starts .github/workflows/sdk-swift-mirror.yml, which
#   splits the package into its own repository and tags it there (SwiftPM
#   needs Package.swift at a repository root and bare X.Y.Z tags).
#   maven: the tag push starts .github/workflows/sdk-kotlin-publish.yml, which
#   signs and releases com.orcagateway:sdk-core and com.orcagateway:sdk to
#   Maven Central (the signing key and Central token are GitHub secrets).
# New packages go at the end, so the numbers people type stay the same.
PACKAGES=(
  "engine|engine|engine-v|npm|engine/package.json"
  "sdk|sdk|sdk-v|pub|sdk/pubspec.yaml"
  "cli|cli|cli-v|pub|cli/pubspec.yaml"
  "devtools|devtools|devtools-v|github-release|devtools/pubspec.yaml"
  "orca_google_map|plugins/orca_google_map|orca_google_map-v|pub|plugins/orca_google_map/pubspec.yaml"
  "orca_push_notification|plugins/orca_push_notification|orca_push_notification-v|pub|plugins/orca_push_notification/pubspec.yaml"
  "orca_video_player|plugins/orca_video_player|orca_video_player-v|pub|plugins/orca_video_player/pubspec.yaml"
  "orca_voice_recorder|plugins/orca_voice_recorder|orca_voice_recorder-v|pub|plugins/orca_voice_recorder/pubspec.yaml"
  "sdk-swift|sdk-swift|sdk-swift-v|mirror|sdk-swift/VERSION"
  "sdk-kotlin|sdk-kotlin|sdk-kotlin-v|maven|sdk-kotlin/VERSION"
)

# The public repository the mirror workflow pushes to. The override exists
# for rehearsals against a local bare repository.
SWIFT_MIRROR_URL="${SWIFT_MIRROR_URL:-https://github.com/orca-gateway/orca-gateway-swift.git}"

# --- Output helpers ---------------------------------------------------------
c_red()    { printf "\033[31m%s\033[0m" "$*"; }
c_green()  { printf "\033[32m%s\033[0m" "$*"; }
c_yellow() { printf "\033[33m%s\033[0m" "$*"; }
c_bold()   { printf "\033[1m%s\033[0m" "$*"; }

die() { printf "%s %s\n" "$(c_red error:)" "$*" >&2; exit 1; }

# --- Version IO -------------------------------------------------------------
read_version() {
  local file=$1
  case "$file" in
    *.json)
      grep -E '"version"[[:space:]]*:[[:space:]]*"' "$file" | head -1 \
        | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
      ;;
    *.yaml)
      grep -E '^version:[[:space:]]+' "$file" | head -1 | awk '{print $2}'
      ;;
    */VERSION)
      head -1 "$file" | tr -d '[:space:]'
      ;;
    *) die "unsupported manifest: $file" ;;
  esac
}

write_version() {
  local file=$1 new=$2
  case "$file" in
    *.json)
      local tmp; tmp=$(mktemp)
      awk -v new="$new" '
        BEGIN{done=0}
        /^[[:space:]]*"version"[[:space:]]*:/ && !done {
          sub(/"[0-9][^"]*"/, "\"" new "\"")
          done=1
        }
        {print}
      ' "$file" > "$tmp"
      mv "$tmp" "$file"
      ;;
    *.yaml)
      sed -i.bak -E "s/^version:[[:space:]]+.*/version: $new/" "$file"
      rm -f "${file}.bak"
      ;;
    */VERSION)
      printf "%s\n" "$new" > "$file"
      ;;
  esac
}

# A pre-release label (`0.1.0-alpha.1`) is dropped before M/m/P: 0.1.0-alpha.1
# -> patch -> 0.1.1. The pre-release choices are bump_pre's.
bump_core() {
  local cur=$1 level=$2
  local core="${cur%%+*}"
  core="${core%%-*}"
  local maj min pat
  IFS='.' read -r maj min pat <<<"$core"
  case "$level" in
    major) printf "%d.0.0" "$((maj+1))" ;;
    minor) printf "%d.%d.0" "$maj" "$((min+1))" ;;
    patch) printf "%d.%d.%d" "$maj" "$min" "$((pat+1))" ;;
  esac
}

bump_version() {
  # Preserves a +N build suffix (devtools/pubspec) by resetting it to +1 on bump.
  local cur=$1 level=$2
  local core; core=$(bump_core "$cur" "$level")
  if [[ "$cur" == *"+"* ]]; then
    printf "%s+1" "$core"
  else
    printf "%s" "$core"
  fi
}

# The pre-release choices for a version with a `-label`:
#   next     0.1.0-alpha.1 -> 0.1.0-alpha.2 (a label with no number gains .1)
#   release  0.1.0-alpha.1 -> 0.1.0
has_pre() { local core="${1%%+*}"; [[ "$core" == *-* ]]; }

bump_pre() {
  local cur=$1 kind=$2
  local core="${cur%%+*}"
  local base="${core%%-*}" label="${core#*-}"
  case "$kind" in
    release) printf "%s" "$base" ;;
    next)
      local last="${label##*.}"
      if [[ "$last" =~ ^[0-9]+$ ]]; then
        if [[ "$label" == *.* ]]; then
          printf "%s-%s.%d" "$base" "${label%.*}" "$((10#$last+1))"
        else
          printf "%s-%d" "$base" "$((10#$last+1))"
        fi
      else
        printf "%s-%s.1" "$base" "$label"
      fi
      ;;
  esac
}

tag_exists() { git rev-parse -q --verify "refs/tags/$1" >/dev/null; }

# --- Pre-flight -------------------------------------------------------------
ensure_clean_git() {
  if [[ -n "$(git status --porcelain)" ]]; then
    c_red "working tree is not clean — commit or stash first"; echo
    git status --short
    exit 1
  fi
}

BRANCH=$(git rev-parse --abbrev-ref HEAD)
ensure_clean_git

if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
  printf "%s not on main/master (on %s). Continue? [y/N]: " "$(c_yellow warning:)" "$BRANCH"
  read -r ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || die "aborted"
fi

# --- 1. List packages, prompt selection ------------------------------------
PKG_NAMES=(); PKG_PATHS=(); PKG_TAGS=(); PKG_PUBS=(); PKG_FILES=(); PKG_VERS=()
for entry in "${PACKAGES[@]}"; do
  IFS='|' read -r name path tag pub file <<<"$entry"
  ver=$(read_version "$file")
  PKG_NAMES+=("$name"); PKG_PATHS+=("$path"); PKG_TAGS+=("$tag")
  PKG_PUBS+=("$pub"); PKG_FILES+=("$file"); PKG_VERS+=("$ver")
done

echo
c_bold "Packages in this monorepo:"; echo
for i in "${!PKG_NAMES[@]}"; do
  printf "  %d) %-10s %-14s (%s)\n" \
    "$((i+1))" "${PKG_NAMES[$i]}" "${PKG_VERS[$i]}" "${PKG_PUBS[$i]}"
done

echo
printf "Which to bump? (comma-separated, e.g. '1,3' or 'all'): "
read -r SELECTION
[[ -n "$SELECTION" ]] || die "no selection"

SELECTED=()
if [[ "$SELECTION" == "all" ]]; then
  for j in "${!PKG_NAMES[@]}"; do SELECTED+=("$j"); done
else
  IFS=',' read -ra parts <<<"$SELECTION"
  for p in "${parts[@]}"; do
    p="${p// /}"
    [[ "$p" =~ ^[0-9]+$ ]] || die "invalid index: '$p'"
    idx=$((p-1))
    [[ $idx -ge 0 && $idx -lt ${#PKG_NAMES[@]} ]] || die "index out of range: $p"
    SELECTED+=("$idx")
  done
fi

# --- 1b. Logins, before anything is bumped or pushed -----------------------
# Step 7 pushes the release commit to origin before it publishes, so a publish
# that fails on auth leaves the bump on main and nothing on the registry. That
# happened with engine 0.3.3 on 2026-11-06: an expired npm login makes
# `npm publish` answer 404 for a scoped package. Check every login the
# selected packages need here, and what their validation needs to run, while
# nothing has changed yet.

trim_slash() { local s=$1; printf "%s" "${s%/}"; }

# The registry `npm publish` will use for the package at $1. A
# `@scope:registry` mapping in npm config beats publishConfig.registry; that
# once sent engine releases to GitHub Packages, so a mapping that disagrees
# with publishConfig stops the release.
npm_target_registry() {
  local path=$1 name scope mapped configured
  name=$(cd "$path" && node -p "require('./package.json').name")
  configured=$(cd "$path" && node -p \
    "const p = require('./package.json'); (p.publishConfig && p.publishConfig.registry) || ''")
  mapped=""
  if [[ "$name" == @*/* ]]; then
    scope="${name%%/*}"
    mapped=$(cd "$path" && npm config get "$scope:registry" 2>/dev/null || true)
    [[ "$mapped" == "undefined" || "$mapped" == "null" ]] && mapped=""
  fi
  if [[ -n "$mapped" && -n "$configured" \
        && "$(trim_slash "$mapped")" != "$(trim_slash "$configured")" ]]; then
    die "npm config maps $scope to $mapped, which beats publishConfig ($configured) in $path/package.json. Remove the '$scope:registry=' line from ~/.npmrc."
  fi
  if [[ -n "$mapped" ]]; then printf "%s" "$mapped"
  elif [[ -n "$configured" ]]; then printf "%s" "$configured"
  else (cd "$path" && npm config get registry)
  fi
}

check_npm_login() {
  local name=$1 path=$2 registry user pkg
  command -v npm >/dev/null 2>&1 || die "npm is required to publish $name"
  registry=$(npm_target_registry "$path") || exit 1
  user=$(npm whoami --registry "$registry" 2>/dev/null) \
    || die "$name: not logged in to $registry (an expired login makes npm publish answer 404). Run: npm login --registry $registry"
  printf "  %s npm, %s as %s\n" "$(c_green ok)" "$registry" "$user"
  pkg=$(cd "$path" && node -p "require('./package.json').name")
  if npm view "$pkg" maintainers --json --registry "$registry" >/dev/null 2>&1 \
     && ! npm view "$pkg" maintainers --json --registry "$registry" 2>/dev/null \
          | grep -q "\"${user}[ \"]"; then
    printf "  %s %s is not among the maintainers of %s; the publish may be refused\n" \
      "$(c_yellow warning:)" "$user" "$pkg"
  fi
}

# `flutter pub publish` reads OAuth credentials that `dart pub login` stores
# here; with a refresh token they renew on their own.
check_pub_login() {
  local f found=""
  for f in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/dart/pub-credentials.json" \
    "$HOME/Library/Application Support/dart/pub-credentials.json" \
    "${PUB_CACHE:-$HOME/.pub-cache}/credentials.json"; do
    if [[ -s "$f" ]] && grep -q '"refreshToken"[[:space:]]*:[[:space:]]*"[^"]' "$f"; then
      found=$f; break
    fi
  done
  [[ -n "$found" ]] || die "not logged in to pub.dev. Run: dart pub login"
  printf "  %s pub.dev, credentials in %s\n" "$(c_green ok)" "$found"
}

# The mirror workflow pushes to SWIFT_MIRROR_URL with a deploy key; if the
# repository is missing, the tag would start a job that cannot succeed.
check_swift_mirror() {
  command -v swift >/dev/null 2>&1 || die "swift is required to validate sdk-swift"
  GIT_TERMINAL_PROMPT=0 git ls-remote --quiet "$SWIFT_MIRROR_URL" >/dev/null 2>&1 \
    || die "the mirror $SWIFT_MIRROR_URL is not reachable. Create it first (docs/User_Actions.md, Epic 23b, the iOS SDK mirror)."
  printf "  %s mirror %s (the deploy key secret is checked by CI)\n" \
    "$(c_green ok)" "$SWIFT_MIRROR_URL"
}

# Step 5 builds sdk-kotlin with the Gradle wrapper, which runs on JAVA_HOME's
# java (else the one on PATH); Gradle 9 and AGP need 17 or newer. AGP finds the
# Android SDK in local.properties' sdk.dir, else ANDROID_HOME or
# ANDROID_SDK_ROOT. The Central token and signing key are not checked here:
# they are GitHub secrets, read by the publish workflow.
check_maven_build() {
  local name=$1 path=$2 java out ver="" major sdk_dir=""
  local re='version "([0-9][^"]*)"'
  if [[ -n "${JAVA_HOME:-}" ]]; then java="$JAVA_HOME/bin/java"
  else java=$(command -v java || true)
  fi
  [[ -n "$java" && -x "$java" ]] \
    || die "$name: no JDK found (JAVA_HOME, or java on PATH). Install a JDK 17 or newer."
  out=$("$java" -version 2>&1 || true)
  [[ "$out" =~ $re ]] && ver=${BASH_REMATCH[1]}
  # 1.8.0_292 is Java 8; 11.0.29, 17 and 25 carry the major first.
  major=${ver#1.}; major=${major%%[!0-9]*}
  [[ -n "$major" && "$major" -ge 17 ]] \
    || die "$name: Gradle needs a JDK 17 or newer, but $java is ${ver:-not a JDK}. Point JAVA_HOME at a JDK 17+."
  if [[ -f "$path/local.properties" ]]; then
    sdk_dir=$(awk '/^sdk\.dir=/ { sub(/^sdk\.dir=/, ""); print; exit }' "$path/local.properties")
  fi
  [[ -n "$sdk_dir" ]] || sdk_dir=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
  [[ -n "$sdk_dir" && -d "$sdk_dir" ]] \
    || die "$name: no Android SDK found${sdk_dir:+ at $sdk_dir}. Set ANDROID_HOME to it, or add sdk.dir=<path> to $path/local.properties."
  printf "  %s JDK %s, Android SDK %s (the Central secrets are checked by CI)\n" \
    "$(c_green ok)" "$ver" "$sdk_dir"
}

# Step 7 pushes the commit and every tag; a dry run checks the same auth.
check_git_push() {
  git push --dry-run --quiet origin "$BRANCH" >/dev/null 2>&1 \
    || die "cannot push to origin/$BRANCH (auth, or the branch is behind). Run: git push --dry-run origin $BRANCH"
  printf "  %s git push to origin/%s\n" "$(c_green ok)" "$BRANCH"
}

echo
c_bold "Checking logins..."; echo
NEED_PUB=0
for idx in "${SELECTED[@]}"; do
  case "${PKG_PUBS[$idx]}" in
    npm) check_npm_login "${PKG_NAMES[$idx]}" "${PKG_PATHS[$idx]}" ;;
    pub) NEED_PUB=1 ;;
    mirror) check_swift_mirror ;;
    maven) check_maven_build "${PKG_NAMES[$idx]}" "${PKG_PATHS[$idx]}" ;;
  esac
done
if [[ $NEED_PUB -eq 1 ]]; then check_pub_login; fi
check_git_push

# --- 2. Per-package bump level ---------------------------------------------
# An engine tag makes a GitHub release whose notes are the "## X.Y.Z" section
# of engine/CHANGELOG.md (.github/workflows/engine-release.yml). Without that
# section the release would ship empty notes, so stop here, before any change.
# "( |$)" keeps "## 0.3.50" from passing for 0.3.5.
check_engine_notes() {
  local name=$1 ver=$2
  [[ "$name" == "engine" ]] || return 0
  if grep -qE "^## ${ver//./[.]}( |\$)" engine/CHANGELOG.md 2>/dev/null; then
    printf "  %s notes, engine/CHANGELOG.md \"## %s\"\n" "$(c_green ok)" "$ver"
  else
    printf "  %s engine/CHANGELOG.md has no \"## %s\"\n" "$(c_red stop:)" "$ver" >&2
    printf "        section. Write it, merge it, run again.\n" >&2
    printf "        Nothing was changed.\n" >&2
    exit 1
  fi
}

echo
NEW_VERS=()
for idx in "${SELECTED[@]}"; do
  cur="${PKG_VERS[$idx]}"
  if has_pre "$cur"; then
    # A pre-release: publish it as it is (only while its tag does not exist),
    # move to the next pre-release, drop the label, or bump the core.
    untagged=0; tag_exists "${PKG_TAGS[$idx]}$cur" || untagged=1
    if [[ $untagged -eq 1 ]]; then def="k"; keep_hint="[k]eep $cur / "
    else def="n"; keep_hint=""
    fi
    while true; do
      printf "[%s] %s -> %s[n]ext %s / [r]elease %s / [M]ajor / [m]inor / [P]atch (default: %s): " \
        "$(c_bold "${PKG_NAMES[$idx]}")" "$cur" "$keep_hint" "$(bump_pre "$cur" next)" \
        "$(bump_pre "$cur" release)" "$def"
      read -r ans
      ans="${ans:-$def}"
      case "$ans" in
        k|keep)
          if [[ $untagged -eq 1 ]]; then new="$cur"; break; fi
          echo "  ${PKG_TAGS[$idx]}$cur is already tagged; pick n, r, M, m or P" ;;
        n|next)       new=$(bump_pre "$cur" next); break ;;
        r|release)    new=$(bump_pre "$cur" release); break ;;
        M|major)      new=$(bump_version "$cur" major); break ;;
        m|minor)      new=$(bump_version "$cur" minor); break ;;
        P|p|patch)    new=$(bump_version "$cur" patch); break ;;
        *) echo "  please answer ${keep_hint:+k, }n, r, M, m, or P (default: $def)" ;;
      esac
    done
    NEW_VERS+=("$new")
    check_engine_notes "${PKG_NAMES[$idx]}" "$new"
    continue
  fi
  while true; do
    printf "[%s] %s -> [M]ajor / [m]inor / [P]atch: " \
      "$(c_bold "${PKG_NAMES[$idx]}")" "$cur"
    read -r ans
    case "${ans:-P}" in
      M|major)        lvl="major"; break ;;
      m|minor)        lvl="minor"; break ;;
      P|p|patch|"")   lvl="patch"; break ;;
      *) echo "  please answer M, m, or P (default: P)" ;;
    esac
  done
  new=$(bump_version "$cur" "$lvl")
  NEW_VERS+=("$new")
  check_engine_notes "${PKG_NAMES[$idx]}" "$new"
done

# A tag that already exists would make `git tag -a` fail after the commit.
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  if tag_exists "${PKG_TAGS[$idx]}${NEW_VERS[$k]}"; then
    die "tag ${PKG_TAGS[$idx]}${NEW_VERS[$k]} already exists"
  fi
done

# --- 3. Summary + confirm --------------------------------------------------
echo
c_bold "Summary:"; echo
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  printf "  %-10s %-12s -> %s\n" \
    "${PKG_NAMES[$idx]}" "${PKG_VERS[$idx]}" "${NEW_VERS[$k]}"
  if [[ "${PKG_NAMES[$idx]}" == "engine" ]]; then
    printf "  %-10s then a GitHub release: notes, demo image, 3 downloads\n" ""
  fi
done
echo
printf "Proceed? [y/N]: "
read -r CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || die "aborted"

# Each SDK's capability vector embeds its version and ships in the package,
# so a bump must regenerate it; Schema CI fails on a stale copy.
#   sdk:        kSdkSemver from sdk/pubspec.yaml
#   sdk-swift:  sdkSemver from sdk-swift/VERSION
#   sdk-kotlin: sdkSemver from sdk-kotlin/VERSION
# One run of gen-native-capabilities.ts writes both native files, so it runs
# once whichever of the two is selected and both are listed: a failure reverts
# both, and the one whose VERSION did not move comes out unchanged.
GENERATED_FILES=()
GENERATORS=()
NEED_NATIVE_GEN=0
for idx in "${SELECTED[@]}"; do
  case "${PKG_NAMES[$idx]}" in
    sdk)
      GENERATED_FILES+=("sdk/lib/src/capabilities/generated.dart")
      GENERATORS+=("schema/gen-sdk-capabilities.ts") ;;
    sdk-swift|sdk-kotlin) NEED_NATIVE_GEN=1 ;;
  esac
done
if [[ $NEED_NATIVE_GEN -eq 1 ]]; then
  GENERATED_FILES+=(
    "sdk-swift/Sources/OrcaGatewayCore/Capabilities/Generated.swift"
    "sdk-kotlin/core/src/main/kotlin/com/orcagateway/core/capabilities/Generated.kt"
  )
  GENERATORS+=("schema/gen-native-capabilities.ts")
fi
if [[ ${#GENERATORS[@]} -gt 0 ]]; then
  command -v bun >/dev/null 2>&1 \
    || die "bun is required to regenerate ${GENERATED_FILES[*]}"
fi

# --- 4. Apply bumps --------------------------------------------------------
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  write_version "${PKG_FILES[$idx]}" "${NEW_VERS[$k]}"
done

for g in ${GENERATORS[@]+"${GENERATORS[@]}"}; do
  echo; c_bold "Regenerating with $g..."; echo
  if ! bun run "$g"; then
    git checkout -- "${PKG_FILES[@]}" "${GENERATED_FILES[@]}"
    die "capability codegen failed — file changes reverted"
  fi
done

# --- 5. Validate -----------------------------------------------------------
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

# Returns: 0 = clean, 1 = real failure, 2 = ok but with non-fatal warnings.
validate_pkg() {
  local name=$1 path=$2 publisher=$3
  case "$publisher" in
    npm)
      ( cd "$path" && npm pack --dry-run ) >"$LOG" 2>&1 || return 1
      ;;
    pub)
      # `flutter pub publish --dry-run` exits non-zero on *any* issue, including
      # the always-present "modified pubspec.yaml" warning we trigger by bumping
      # the version moments earlier, and the "dependency_overrides" hint that
      # plugins emit by design. The deterministic blocker line is the one below;
      # everything else is a non-fatal warning we want to surface but not abort on.
      ( cd "$path" && flutter pub publish --dry-run ) >"$LOG" 2>&1 || true
      if grep -q "Sorry, your package is missing a requirement" "$LOG"; then
        return 1
      fi
      if grep -qE "Package has [1-9]" "$LOG"; then
        return 2
      fi
      ;;
    github-release)
      : # No registry validation; CI handles the build on tag push.
      ;;
    mirror)
      # What a consumer resolves: the manifest, then a build of every target.
      ( swift package --package-path "$path" describe >/dev/null \
        && swift build --package-path "$path" ) >"$LOG" 2>&1 || return 1
      ;;
    maven)
      # Tests, lint and both artifacts with their POMs, published to the local
      # build/staging-repo; Central itself is the workflow's, on the tag push.
      ( cd "$path" && ./gradlew build publishAllPublicationsToStagingRepository \
        --console=plain ) >"$LOG" 2>&1 || return 1
      ;;
  esac
}

echo; c_bold "Validating..."; echo
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  printf "  [%s] dry-run... " "${PKG_NAMES[$idx]}"
  set +e
  validate_pkg "${PKG_NAMES[$idx]}" "${PKG_PATHS[$idx]}" "${PKG_PUBS[$idx]}"
  rc=$?
  set -e
  case "$rc" in
    0) echo "$(c_green ok)" ;;
    2)
      echo "$(c_yellow "ok (warnings)")"
      grep -E "^\* " "$LOG" | sed 's/^/    /'
      ;;
    *)
      echo "$(c_red failed)"
      cat "$LOG"
      # ${arr[@]+...} keeps an empty array safe under `set -u` on bash 3.2.
      git checkout -- "${PKG_FILES[@]}" ${GENERATED_FILES[@]+"${GENERATED_FILES[@]}"}
      die "validation failed for ${PKG_NAMES[$idx]} — file changes reverted"
      ;;
  esac
done

# --- 6. Commit + tag (local only) ------------------------------------------
COMMIT_BODY=""
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  COMMIT_BODY+="- ${PKG_NAMES[$idx]} ${PKG_VERS[$idx]} -> ${NEW_VERS[$k]}"$'\n'
done

for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  git add "${PKG_FILES[$idx]}"
done
if [[ ${#GENERATED_FILES[@]} -gt 0 ]]; then
  git add "${GENERATED_FILES[@]}"
fi

# A pre-release published as it is changes no file; it is tagged at HEAD.
if git diff --cached --quiet; then
  printf "%s nothing to commit (versions kept as they are); tagging HEAD\n" \
    "$(c_yellow note:)"
else
  git commit -m "chore(release): version bump" -m "$COMMIT_BODY"
fi

for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  tag="${PKG_TAGS[$idx]}${NEW_VERS[$k]}"
  git tag -a "$tag" -m "${PKG_NAMES[$idx]} ${NEW_VERS[$k]}"
done

# --- 7. Push commit, publish each, push its tag ----------------------------
echo; c_bold "Pushing commit to origin/$BRANCH..."; echo
git push origin "$BRANCH"

publish_pkg() {
  local name=$1 path=$2 publisher=$3
  case "$publisher" in
    npm)
      ( cd "$path" && npm publish )
      ;;
    pub)
      ( cd "$path" && flutter pub publish --force )
      ;;
    github-release)
      printf "  %s tag push triggers .github/workflows/devtools-release.yml\n" \
        "$(c_yellow "[$name]")"
      ;;
    mirror)
      printf "  %s tag push triggers .github/workflows/sdk-swift-mirror.yml (split, push to %s, tag %s there)\n" \
        "$(c_yellow "[$name]")" "$SWIFT_MIRROR_URL" "$4"
      ;;
    maven)
      printf "  %s tag push triggers .github/workflows/sdk-kotlin-publish.yml (signs and releases com.orcagateway:sdk-core and com.orcagateway:sdk %s to Maven Central)\n" \
        "$(c_yellow "[$name]")" "$4"
      ;;
  esac
}

# Publish registry packages first, then push the tags CI picks up: the
# mirror, Maven Central, and devtools last since its tag starts a long CI build.
ORDER=()
for pass in registry mirror maven github-release; do
  for k in "${!SELECTED[@]}"; do
    pub="${PKG_PUBS[${SELECTED[$k]}]}"
    case "$pass:$pub" in
      registry:mirror|registry:maven|registry:github-release) ;;
      registry:*|mirror:mirror|maven:maven|github-release:github-release) ORDER+=("$k") ;;
    esac
  done
done

for k in "${ORDER[@]}"; do
  idx=${SELECTED[$k]}
  echo
  c_bold "Publishing ${PKG_NAMES[$idx]} ${NEW_VERS[$k]}..."; echo
  publish_pkg "${PKG_NAMES[$idx]}" "${PKG_PATHS[$idx]}" "${PKG_PUBS[$idx]}" "${NEW_VERS[$k]}"
  tag="${PKG_TAGS[$idx]}${NEW_VERS[$k]}"
  git push origin "$tag"
done

echo
c_green "All done."; echo
