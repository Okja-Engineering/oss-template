# shellcheck shell=bash
# Hermetic git (AC10; decisions 90, 104, 112, 128, 132, 135, 137, 143, 154,
# 156, 167): the environment render, the fingerprint, and later verify and
# publish's mirror run git under, and the one version gate.
#
#   git_version_ok   exit 0 when `git --version` reports 2.36 or later,
#                    comparing major and minor numerically; else print why
#                    and exit 1
#   git_hermetic     build the environment, for every git the caller starts
#                    after it: unset every variable of the GIT_* namespace,
#                    each `git rev-parse --local-env-vars` names, the
#                    pathspec ones, GIT_TRACE*, GIT_ATTR_SOURCE,
#                    GIT_DEFAULT_HASH, GIT_AUTHOR_* and GIT_COMMITTER_*
#                    among them; then set GIT_CONFIG_GLOBAL=/dev/null,
#                    GIT_CONFIG_NOSYSTEM=1, GIT_ATTR_NOSYSTEM=1,
#                    GIT_NO_REPLACE_OBJECTS=1 and GIT_DEFAULT_REF_FORMAT=files,
#                    and, through GIT_CONFIG_COUNT, GIT_CONFIG_KEY_<n> and
#                    GIT_CONFIG_VALUE_<n>, so that every git process inherits
#                    them while it keeps the environment,
#                    core.attributesFile=/dev/null, core.excludesFile=/dev/null,
#                    core.fileMode=true, commit.gpgsign=false,
#                    core.hooksPath=/dev/null and core.fsmonitor=false.
#                    It runs no git, so the caller runs it before any git,
#                    the version gate's included, and no planted variable
#                    reaches one.
#
# A repository the caller makes is made with `git init --template=
# --object-format=sha1`. The caller exports LC_ALL=C.

git_version_ok() {
  local out version major minor
  if ! command -v git >/dev/null 2>&1; then
    printf 'git is missing; install git 2.36 or later\n'
    return 1
  fi
  if ! out=$(git --version 2>/dev/null); then
    printf 'git --version failed: %s\n' "$(git --version 2>&1)"
    return 1
  fi
  case "$out" in
    'git version '[0-9]*.[0-9]*) ;;
    *)
      printf 'git reports a version this workspace cannot read: %s\n' "$out"
      return 1
      ;;
  esac
  version=${out#git version }
  version=${version%% *}
  major=${version%%.*}
  minor=${version#*.}
  minor=${minor%%.*}
  # Each of major and minor is digits, neither empty: major starts with one,
  # by the pattern above, and minor is empty after `2..`.
  case "$major.$minor" in
    *. | *[!0-9.]*)
      printf 'git reports a version this workspace cannot read: %s\n' "$out"
      return 1
      ;;
  esac
  if [ "$major" -gt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -ge 36 ]; }; then
    return 0
  fi
  printf 'git %s is older than 2.36, the oldest this workspace runs on; install a newer git\n' "$version"
  return 1
}

# shellcheck disable=SC2163 # unset and export take the names held in v
git_hermetic() {
  local v
  for v in $(compgen -e); do
    case "$v" in
      GIT_*) unset "$v" ;;
    esac
  done
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_ATTR_NOSYSTEM=1
  export GIT_NO_REPLACE_OBJECTS=1 GIT_DEFAULT_REF_FORMAT=files
  export GIT_CONFIG_COUNT=6
  export GIT_CONFIG_KEY_0=core.attributesFile GIT_CONFIG_VALUE_0=/dev/null
  export GIT_CONFIG_KEY_1=core.excludesFile GIT_CONFIG_VALUE_1=/dev/null
  export GIT_CONFIG_KEY_2=core.fileMode GIT_CONFIG_VALUE_2=true
  export GIT_CONFIG_KEY_3=commit.gpgsign GIT_CONFIG_VALUE_3=false
  export GIT_CONFIG_KEY_4=core.hooksPath GIT_CONFIG_VALUE_4=/dev/null
  export GIT_CONFIG_KEY_5=core.fsmonitor GIT_CONFIG_VALUE_5=false
}
