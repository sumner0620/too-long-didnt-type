#!/usr/bin/env bash
# tldt undo — restore clean last-commit state (optionally save for redo)
set -euo pipefail

# shellcheck source=../../lib/common.sh
source "${TLDT_ROOT}/lib/common.sh"

usage() {
  cat <<EOF
Usage:
  tldt undo [--safe] [--force]
  tldt undo --help

Undo the current repo state back toward a clean last commit:

  1. If you have staged / unstaged / untracked changes → discard them
     and match HEAD exactly.
  2. If the tree is already clean → uncommit the latest local commit
     (hard reset to HEAD~1), landing clean on the previous commit.

Flags:
  --safe      Snapshot first so \`tldt redo\` can restore this state
  --force     Allow undoing a commit that already exists on a remote
  -h, --help  Show this help

Examples:
  tldt undo              # destructive
  tldt undo --safe       # reversible via tldt redo
  tldt undo --safe --force

Notes:
  Default undo is destructive. Use --safe whenever you might want redo.
  Safe snapshots live in .git/tldt/ (local only, never committed).
EOF
}

SAFE=0
FORCE=0

for arg in "$@"; do
  case "${arg}" in
    -h|--help) usage; exit 0 ;;
    --safe) SAFE=1 ;;
    --force) FORCE=1 ;;
    -*)
      echo "Error: unknown flag '${arg}'" >&2
      usage
      exit 1
      ;;
    *)
      echo "Error: unexpected argument '${arg}'" >&2
      usage
      exit 1
      ;;
  esac
done

require_git_repo

BRANCH="$(git branch --show-current 2>/dev/null || true)"
HEAD_BEFORE="$(git rev-parse HEAD)"
HEAD_SHORT="$(git rev-parse --short HEAD)"
HEAD_SUBJECT="$(git log -1 --pretty=%s HEAD)"
KIND=""
STASH_SHA=""
MESSAGE=""
CHANGE_SUMMARY=""

save_safe_snapshot() {
  local kind="$1" stash_sha="${2:-}" message="$3"
  local entry head_after
  head_after="$(git rev-parse HEAD)"
  entry="$(node -e '
    const entry = {
      id: new Date().toISOString().replace(/[:.]/g, "-"),
      createdAt: new Date().toISOString(),
      branch: process.argv[1] || null,
      kind: process.argv[2],
      headBefore: process.argv[3],
      headAfter: process.argv[4],
      stashSha: process.argv[5] || null,
      message: process.argv[6] || ""
    };
    process.stdout.write(JSON.stringify(entry));
  ' "${BRANCH}" "${kind}" "${HEAD_BEFORE}" "${head_after}" "${stash_sha}" "${message}")"
  undo_stack_push "${entry}"
  echo "→ Saved snapshot for tldt redo (${kind})"
}

if git_is_dirty; then
  KIND="working-tree"
  MESSAGE="Discard working tree changes relative to ${HEAD_SHORT}"
  CHANGE_SUMMARY="$(describe_working_tree)"

  if [[ "${SAFE}" -eq 1 ]]; then
    echo "→ Saving working tree (including untracked)…"
    git stash push -u -m "tldt undo ${HEAD_SHORT}" >/dev/null
    STASH_SHA="$(git rev-parse refs/stash)"
    echo "→ Working tree restored to ${HEAD_SHORT}"
    save_safe_snapshot "${KIND}" "${STASH_SHA}" "${MESSAGE}"
  else
    echo "→ Discarding staged, unstaged, and untracked changes…"
    git reset --hard HEAD
    git clean -fd
    echo "→ Working tree restored to ${HEAD_SHORT}"
  fi

  echo
  echo "Done."
  echo "Changed:"
  echo "  Discarded working tree changes (HEAD unchanged)"
  echo "  HEAD ${HEAD_SHORT} — ${HEAD_SUBJECT}"
  echo "${CHANGE_SUMMARY}"
else
  KIND="commit"
  if ! git rev-parse --verify --quiet HEAD~1 >/dev/null; then
    echo "Error: nothing to undo — clean tree and no parent commit" >&2
    exit 1
  fi

  if commit_is_on_remote "${HEAD_BEFORE}" && [[ "${FORCE}" -ne 1 ]]; then
    echo "Error: commit ${HEAD_SHORT} exists on a remote" >&2
    echo "  Re-run with --force if you really want to uncommit it" >&2
    exit 1
  fi

  PARENT="$(git rev-parse --short HEAD~1)"
  PARENT_SUBJECT="$(git log -1 --pretty=%s HEAD~1)"
  SUBJECT="$(git log -1 --pretty=%s HEAD)"
  MESSAGE="Uncommit ${HEAD_SHORT}: ${SUBJECT}"
  CHANGE_SUMMARY="$(describe_commit HEAD)"

  if [[ "${SAFE}" -eq 1 ]]; then
    echo "→ Uncommitting ${HEAD_SHORT} (safe)…"
    git reset --hard HEAD~1
    save_safe_snapshot "${KIND}" "" "${MESSAGE}"
  else
    echo "→ Uncommitting ${HEAD_SHORT}…"
    git reset --hard HEAD~1
  fi
  echo "→ Now at ${PARENT} (clean)"

  echo
  echo "Done."
  echo "Changed:"
  echo "  Uncommitted ${HEAD_SHORT} — ${SUBJECT}"
  echo "  HEAD ${HEAD_SHORT} → ${PARENT} — ${PARENT_SUBJECT}"
  echo "${CHANGE_SUMMARY}"
fi

if [[ "${SAFE}" -eq 1 ]]; then
  echo "  Redo with:  tldt redo"
else
  echo "  Tip: use tldt undo --safe next time if you might want redo"
fi
