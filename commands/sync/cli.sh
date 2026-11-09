#!/usr/bin/env bash
# tldt sync — bring current branch up to date with base
set -euo pipefail

# shellcheck source=../../lib/common.sh
source "${TLDT_ROOT}/lib/common.sh"

usage() {
  cat <<EOF
Usage:
  tldt sync [base-branch] [--rebase|--merge] [--remote|--local] [--no-install]
  tldt sync --help

Fetch the latest base branch and rebase (default) or merge it into the
branch you are on.

Arguments:
  base-branch     Branch to sync from (default: main, or .tldt.json sync.defaultBase)

Flags:
  --rebase        Rebase onto base (default, or .tldt.json sync.strategy)
  --merge         Merge base into the current branch
  --remote        Use origin/<base> after fetch (default)
  --local         Use local <base> as-is (no fetch)
  --no-install    Skip reinstall even if the lockfile changed
  -h, --help      Show this help

Examples:
  tldt sync
  tldt sync develop --merge
  tldt sync main --local --no-install

Environment / config:
  Per-repo: <repo>/.tldt.json  →  sync.defaultBase, sync.strategy, sync.reinstall
EOF
}

lockfile_fingerprint() {
  local dir="$1"
  local files=()
  local f
  for f in package-lock.json pnpm-lock.yaml yarn.lock bun.lockb Gemfile.lock Cargo.lock poetry.lock go.sum; do
    if [[ -f "${dir}/${f}" ]]; then
      files+=("${dir}/${f}")
    fi
  done
  if [[ ${#files[@]} -eq 0 ]]; then
    echo ""
    return
  fi
  # Content hash so install runs only when deps actually changed.
  if command -v shasum >/dev/null 2>&1; then
    cat "${files[@]}" | shasum -a 256 | awk '{print $1}'
  else
    cat "${files[@]}" | cksum | awk '{print $1}'
  fi
}

STRATEGY=""
SOURCE="remote"
DO_INSTALL=""
BASE_BRANCH=""
ARGS=("$@")
i=0
while [[ ${i} -lt ${#ARGS[@]} ]]; do
  arg="${ARGS[$i]}"
  case "${arg}" in
    -h|--help) usage; exit 0 ;;
    --rebase) STRATEGY="rebase" ;;
    --merge) STRATEGY="merge" ;;
    --remote) SOURCE="remote" ;;
    --local) SOURCE="local" ;;
    --no-install) DO_INSTALL=0 ;;
    -*)
      echo "Error: unknown flag '${arg}'" >&2
      usage
      exit 1
      ;;
    *)
      if [[ -n "${BASE_BRANCH}" ]]; then
        echo "Error: unexpected argument '${arg}'" >&2
        usage
        exit 1
      fi
      BASE_BRANCH="${arg}"
      ;;
  esac
  i=$((i + 1))
done

require_git_repo
load_repo_config

BRANCH="$(current_branch)"
BASE_BRANCH="${BASE_BRANCH:-${TLDT_SYNC_BASE:-${TLDT_DEFAULT_BASE:-main}}}"
STRATEGY="${STRATEGY:-${TLDT_SYNC_STRATEGY:-rebase}}"
if [[ -z "${DO_INSTALL}" ]]; then
  DO_INSTALL="${TLDT_SYNC_REINSTALL:-1}"
fi

if [[ "${STRATEGY}" != "rebase" && "${STRATEGY}" != "merge" ]]; then
  echo "Error: strategy must be rebase or merge (got '${STRATEGY}')" >&2
  exit 1
fi

if git_is_dirty; then
  echo "Error: working tree is dirty — commit, stash, or tldt undo first" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
BEFORE_LOCK="$(lockfile_fingerprint "${ROOT}")"

START_POINT=""
if [[ "${SOURCE}" == "remote" ]]; then
  echo "→ Fetching origin/${BASE_BRANCH}…"
  if ! git fetch origin "${BASE_BRANCH}"; then
    echo "Error: could not fetch origin/${BASE_BRANCH}" >&2
    exit 1
  fi
  if ! git show-ref --verify --quiet "refs/remotes/origin/${BASE_BRANCH}"; then
    echo "Error: origin/${BASE_BRANCH} not found after fetch" >&2
    exit 1
  fi
  START_POINT="origin/${BASE_BRANCH}"
else
  if ! git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
    echo "Error: local branch '${BASE_BRANCH}' not found" >&2
    exit 1
  fi
  START_POINT="${BASE_BRANCH}"
fi

if [[ "${BRANCH}" == "${BASE_BRANCH}" && "${SOURCE}" == "local" ]]; then
  echo "→ Already on local ${BASE_BRANCH}; nothing to sync"
  exit 0
fi

echo "→ Syncing ${BRANCH} with ${START_POINT} via ${STRATEGY}…"
if [[ "${STRATEGY}" == "rebase" ]]; then
  git rebase "${START_POINT}"
else
  git merge --no-edit "${START_POINT}"
fi

AFTER_LOCK="$(lockfile_fingerprint "${ROOT}")"
if [[ "${DO_INSTALL}" -eq 1 && -n "${AFTER_LOCK}" && "${BEFORE_LOCK}" != "${AFTER_LOCK}" ]]; then
  INSTALL_CMD="$(detect_install_command "${ROOT}")"
  if [[ -n "${INSTALL_CMD}" ]]; then
    echo "→ Lockfile changed — ${INSTALL_CMD}…"
    (cd "${ROOT}" && bash -lc "${INSTALL_CMD}")
  else
    echo "→ Lockfile changed, but no install command detected (skipped)"
  fi
elif [[ "${DO_INSTALL}" -eq 0 ]]; then
  echo "→ Skipping install (--no-install)"
else
  echo "→ Lockfile unchanged (skipped install)"
fi

echo
echo "Done."
echo "  Branch:  ${BRANCH}"
echo "  Synced:  ${START_POINT} (${STRATEGY})"
