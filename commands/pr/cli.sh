#!/usr/bin/env bash
# tldt pr — push current branch and open a pull request
set -euo pipefail

# shellcheck source=../../lib/common.sh
source "${TLDT_ROOT}/lib/common.sh"

usage() {
  cat <<EOF
Usage:
  tldt pr [title...] [--base <branch>] [--draft|--ready] [--fill] [--no-push] [--no-open]
  tldt pr --help

Push the current branch and create a GitHub pull request (requires \`gh\`).

Arguments:
  title           Optional PR title (remaining words). If omitted, \`gh\` prompts
                  or uses --fill from commits.

Flags:
  --base BRANCH   PR base branch (default: main, or .tldt.json pr.defaultBase)
  --draft         Open as draft
  --ready         Open as ready for review (default unless config sets draft)
  --fill          Non-interactive title/body from commits
  --no-push       Skip \`git push\` (branch must already be on the remote)
  --no-open       Do not open the PR in a browser
  -h, --help      Show this help

Examples:
  tldt pr
  tldt pr "Add login flow"
  tldt pr --draft --fill
  tldt pr --base develop Fix the webhook handler

Environment / config:
  Per-repo: <repo>/.tldt.json  →  pr.defaultBase, pr.draft
EOF
}

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is required for tldt pr" >&2
    echo "  Install: https://cli.github.com/" >&2
    exit 1
  fi
}

DRAFT=""
FILL=0
DO_PUSH=1
DO_OPEN=1
BASE_BRANCH=""
TITLE_PARTS=()
ARGS=("$@")
i=0
while [[ ${i} -lt ${#ARGS[@]} ]]; do
  arg="${ARGS[$i]}"
  case "${arg}" in
    -h|--help) usage; exit 0 ;;
    --draft) DRAFT=1 ;;
    --ready) DRAFT=0 ;;
    --fill) FILL=1 ;;
    --no-push) DO_PUSH=0 ;;
    --no-open) DO_OPEN=0 ;;
    --base)
      i=$((i + 1))
      if [[ ${i} -ge ${#ARGS[@]} ]]; then
        echo "Error: --base requires a branch name" >&2
        exit 1
      fi
      BASE_BRANCH="${ARGS[$i]}"
      ;;
    --base=*)
      BASE_BRANCH="${arg#--base=}"
      ;;
    -*)
      echo "Error: unknown flag '${arg}'" >&2
      usage
      exit 1
      ;;
    *) TITLE_PARTS+=("${arg}") ;;
  esac
  i=$((i + 1))
done

require_git_repo
require_gh
load_repo_config

BRANCH="$(current_branch)"
BASE_BRANCH="${BASE_BRANCH:-${TLDT_PR_BASE:-${TLDT_DEFAULT_BASE:-main}}}"
if [[ -z "${DRAFT}" ]]; then
  DRAFT="${TLDT_PR_DRAFT:-0}"
fi

TITLE=""
if [[ ${#TITLE_PARTS[@]} -gt 0 ]]; then
  TITLE="${TITLE_PARTS[*]}"
fi

if [[ "${BRANCH}" == "${BASE_BRANCH}" ]]; then
  echo "Error: you are on '${BRANCH}', which is the PR base branch" >&2
  echo "  Create a feature branch first (e.g. tldt tree feature/thing)" >&2
  exit 1
fi

if [[ "${DO_PUSH}" -eq 1 ]]; then
  echo "→ Pushing ${BRANCH} to origin…"
  git push -u origin HEAD
else
  echo "→ Skipping push (--no-push)"
fi

EXISTING="$(gh pr view --json url -q .url 2>/dev/null || true)"
if [[ -n "${EXISTING}" ]]; then
  echo "→ PR already exists for ${BRANCH}"
  echo "  ${EXISTING}"
  if [[ "${DO_OPEN}" -eq 1 ]]; then
    gh pr view --web >/dev/null 2>&1 || true
  fi
  exit 0
fi

GH_ARGS=(pr create --base "${BASE_BRANCH}" --head "${BRANCH}")
if [[ "${DRAFT}" -eq 1 ]]; then
  GH_ARGS+=(--draft)
fi
if [[ -n "${TITLE}" ]]; then
  GH_ARGS+=(--title "${TITLE}" --body "")
elif [[ "${FILL}" -eq 1 ]]; then
  GH_ARGS+=(--fill)
fi

echo "→ Creating pull request against ${BASE_BRANCH}…"
if [[ "${DO_OPEN}" -eq 1 ]]; then
  gh "${GH_ARGS[@]}" --web
else
  URL="$(gh "${GH_ARGS[@]}")"
  echo "  ${URL}"
fi
