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
# publisher ∈ { npm, pub, github-release }
PACKAGES=(
  "engine|engine|engine-v|npm|engine/package.json"
  "sdk|sdk|sdk-v|pub|sdk/pubspec.yaml"
  "cli|cli|cli-v|pub|cli/pubspec.yaml"
  "devtools|devtools|devtools-v|github-release|devtools/pubspec.yaml"
  "orca_google_map|plugins/orca_google_map|orca_google_map-v|pub|plugins/orca_google_map/pubspec.yaml"
  "orca_push_notification|plugins/orca_push_notification|orca_push_notification-v|pub|plugins/orca_push_notification/pubspec.yaml"
  "orca_video_player|plugins/orca_video_player|orca_video_player-v|pub|plugins/orca_video_player/pubspec.yaml"
  "orca_voice_recorder|plugins/orca_voice_recorder|orca_voice_recorder-v|pub|plugins/orca_voice_recorder/pubspec.yaml"
)

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
  esac
}

bump_core() {
  local cur=$1 level=$2
  local core="${cur%%+*}"
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
  printf "  %d) %-10s %-12s (%s)\n" \
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

# --- 2. Per-package bump level ---------------------------------------------
echo
NEW_VERS=()
for idx in "${SELECTED[@]}"; do
  cur="${PKG_VERS[$idx]}"
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
done

# --- 3. Summary + confirm --------------------------------------------------
echo
c_bold "Summary:"; echo
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  printf "  %-10s %-12s -> %s\n" \
    "${PKG_NAMES[$idx]}" "${PKG_VERS[$idx]}" "${NEW_VERS[$k]}"
done
echo
printf "Proceed? [y/N]: "
read -r CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || die "aborted"

# --- 4. Apply bumps --------------------------------------------------------
for k in "${!SELECTED[@]}"; do
  idx=${SELECTED[$k]}
  write_version "${PKG_FILES[$idx]}" "${NEW_VERS[$k]}"
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
      git checkout -- "${PKG_FILES[@]}"
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

git commit -m "chore(release): version bump" -m "$COMMIT_BODY"

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
  esac
}

# Publish non-CI packages first; push their tags last.
# devtools is left for the end since pushing its tag triggers a long CI build.
ORDER=()
for k in "${!SELECTED[@]}"; do
  if [[ "${PKG_PUBS[${SELECTED[$k]}]}" != "github-release" ]]; then
    ORDER+=("$k")
  fi
done
for k in "${!SELECTED[@]}"; do
  if [[ "${PKG_PUBS[${SELECTED[$k]}]}" == "github-release" ]]; then
    ORDER+=("$k")
  fi
done

for k in "${ORDER[@]}"; do
  idx=${SELECTED[$k]}
  echo
  c_bold "Publishing ${PKG_NAMES[$idx]} ${NEW_VERS[$k]}..."; echo
  publish_pkg "${PKG_NAMES[$idx]}" "${PKG_PATHS[$idx]}" "${PKG_PUBS[$idx]}"
  tag="${PKG_TAGS[$idx]}${NEW_VERS[$k]}"
  git push origin "$tag"
done

echo
c_green "All done."; echo
