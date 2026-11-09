#!/usr/bin/env bash
# tldt redo — restore the last tldt undo --safe snapshot
set -euo pipefail

# shellcheck source=../../lib/common.sh
source "${TLDT_ROOT}/lib/common.sh"

usage() {
  cat <<EOF
Usage:
  tldt redo [--force]
  tldt redo --help

Restore the most recent snapshot created by \`tldt undo --safe\`.

Flags:
  --force     Allow redo even if HEAD moved or the tree is dirty
  -h, --help  Show this help

Examples:
  tldt redo
EOF
}

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    -h|--help) usage; exit 0 ;;
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

ENTRY_JSON=""
if ! ENTRY_JSON="$(undo_stack_pop)"; then
  echo "Error: nothing to redo — run tldt undo --safe first" >&2
  exit 1
fi

KIND="$(node -e 'const e=JSON.parse(process.argv[1]); process.stdout.write(e.kind||"")' "${ENTRY_JSON}")"
HEAD_BEFORE="$(node -e 'const e=JSON.parse(process.argv[1]); process.stdout.write(e.headBefore||"")' "${ENTRY_JSON}")"
HEAD_AFTER="$(node -e 'const e=JSON.parse(process.argv[1]); process.stdout.write(e.headAfter||"")' "${ENTRY_JSON}")"
STASH_SHA="$(node -e 'const e=JSON.parse(process.argv[1]); process.stdout.write(e.stashSha||"")' "${ENTRY_JSON}")"
MESSAGE="$(node -e 'const e=JSON.parse(process.argv[1]); process.stdout.write(e.message||"")' "${ENTRY_JSON}")"

CURRENT="$(git rev-parse HEAD)"
HEAD_BEFORE_SHORT=""
HEAD_AFTER_SHORT=""
[[ -n "${HEAD_BEFORE}" ]] && HEAD_BEFORE_SHORT="$(git rev-parse --short "${HEAD_BEFORE}" 2>/dev/null || echo "${HEAD_BEFORE}")"
[[ -n "${HEAD_AFTER}" ]] && HEAD_AFTER_SHORT="$(git rev-parse --short "${HEAD_AFTER}" 2>/dev/null || echo "${HEAD_AFTER}")"

if [[ "${FORCE}" -ne 1 ]]; then
  if git_is_dirty; then
    echo "Error: working tree is dirty — commit/stash, or re-run with --force" >&2
    undo_stack_push "${ENTRY_JSON}"
    exit 1
  fi
  if [[ -n "${HEAD_AFTER}" && "${CURRENT}" != "${HEAD_AFTER}" ]]; then
    echo "Error: HEAD moved since undo (expected ${HEAD_AFTER_SHORT}, got $(git rev-parse --short HEAD))" >&2
    echo "  Re-run with --force to restore anyway" >&2
    undo_stack_push "${ENTRY_JSON}"
    exit 1
  fi
fi

echo "→ Redoing: ${MESSAGE:-${KIND}}"

case "${KIND}" in
  working-tree)
    if [[ -z "${STASH_SHA}" ]]; then
      echo "Error: snapshot missing stash sha" >&2
      undo_stack_push "${ENTRY_JSON}"
      exit 1
    fi
    if ! git cat-file -e "${STASH_SHA}^{commit}" 2>/dev/null; then
      echo "Error: stash snapshot ${STASH_SHA} no longer exists" >&2
      exit 1
    fi
    git stash apply --index "${STASH_SHA}" >/dev/null
    if git rev-parse --verify --quiet refs/stash >/dev/null; then
      if [[ "$(git rev-parse refs/stash)" == "${STASH_SHA}" ]]; then
        git stash drop -q
      fi
    fi
    echo "→ Working tree restored"

    echo
    echo "Done."
    echo "Changed:"
    echo "  Restored working tree from safe undo"
    echo "  HEAD $(git rev-parse --short HEAD) — $(git log -1 --pretty=%s HEAD)"
    describe_working_tree
    ;;
  commit)
    if [[ -z "${HEAD_BEFORE}" ]]; then
      echo "Error: snapshot missing commit sha" >&2
      undo_stack_push "${ENTRY_JSON}"
      exit 1
    fi
    if ! git cat-file -e "${HEAD_BEFORE}^{commit}" 2>/dev/null; then
      echo "Error: commit ${HEAD_BEFORE} no longer exists" >&2
      exit 1
    fi
    FROM_SHORT="$(git rev-parse --short HEAD)"
    FROM_SUBJECT="$(git log -1 --pretty=%s HEAD)"
    git reset --hard "${HEAD_BEFORE}"
    TO_SHORT="$(git rev-parse --short HEAD)"
    TO_SUBJECT="$(git log -1 --pretty=%s HEAD)"
    echo "→ Restored commit ${TO_SHORT}"

    echo
    echo "Done."
    echo "Changed:"
    echo "  Restored commit ${TO_SHORT} — ${TO_SUBJECT}"
    echo "  HEAD ${FROM_SHORT} → ${TO_SHORT}"
    describe_commit HEAD
    ;;
  *)
    echo "Error: unknown snapshot kind '${KIND}'" >&2
    undo_stack_push "${ENTRY_JSON}"
    exit 1
    ;;
esac
