#!/usr/bin/env bash
# Shared helpers for too-long-didnt-type command scripts.
# shellcheck disable=SC2034

set -euo pipefail

TLDT_ROOT="${TLDT_ROOT:-}"
if [[ -z "${TLDT_ROOT}" ]]; then
  TLDT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

resolve_primary() {
  local primary
  primary="$(git worktree list --porcelain 2>/dev/null | awk '/^worktree / { print $2; exit }')"
  if [[ -z "${primary}" ]]; then
    primary="$(git rev-parse --show-toplevel 2>/dev/null)" || {
      echo "Error: not inside a git repository" >&2
      exit 1
    }
  fi
  echo "${primary}"
}

repo_basename() {
  basename "$(resolve_primary)"
}

# ../<repo>-<name>
worktree_dir_for() {
  local name="$1"
  local primary parent base
  primary="$(resolve_primary)"
  parent="$(dirname "${primary}")"
  base="$(basename "${primary}")"
  echo "${parent}/${base}-${name}"
}

valid_branch_name() {
  local name="$1"
  [[ -n "${name}" ]] || return 1
  [[ "${name}" != .* ]] || return 1
  [[ "${name}" != *..* ]] || return 1
  [[ ! "${name}" =~ [[:space:]] ]] || return 1
  # Allow slashes in branch names for git, but not for our folder suffix path segment.
  # Folder uses the name with slashes replaced.
  return 0
}

# Safe directory suffix: replace / with --
worktree_slug() {
  local name="$1"
  echo "${name//\//--}"
}

worktree_dir_for_slug() {
  local name="$1"
  local primary parent base slug
  primary="$(resolve_primary)"
  parent="$(dirname "${primary}")"
  base="$(basename "${primary}")"
  slug="$(worktree_slug "${name}")"
  echo "${parent}/${base}-${slug}"
}

load_repo_config() {
  # Optional per-repo config: <primary>/.tldt.json
  local primary config
  primary="$(resolve_primary)"
  config="${primary}/.tldt.json"
  TLDT_DEFAULT_BASE="${TLDT_DEFAULT_BASE:-main}"
  TLDT_INSTALL_CMD="${TLDT_INSTALL_CMD:-}"
  TLDT_DEV_CMD="${TLDT_DEV_CMD:-}"
  TLDT_COPY_ENV="${TLDT_COPY_ENV:-1}"
  TLDT_EDITOR="${TLDT_EDITOR:-${TLDT_WORKTREE_EDITOR:-}}"
  TLDT_PORT_START="${TLDT_PORT_START:-3001}"
  TLDT_PORT_END="${TLDT_PORT_END:-3099}"

  if [[ -f "${config}" ]] && command -v node >/dev/null 2>&1; then
    eval "$(
      node -e '
        const fs = require("fs");
        const c = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        const t = c.tree || {};
        const esc = (v) => String(v ?? "").replace(/"/g, "\\\"");
        if (t.defaultBase) console.log(`TLDT_DEFAULT_BASE="${esc(t.defaultBase)}"`);
        if (t.installCommand) console.log(`TLDT_INSTALL_CMD="${esc(t.installCommand)}"`);
        if (t.devCommand) console.log(`TLDT_DEV_CMD="${esc(t.devCommand)}"`);
        if (t.copyEnv === false) console.log(`TLDT_COPY_ENV="0"`);
        if (t.portStart) console.log(`TLDT_PORT_START="${esc(t.portStart)}"`);
        if (t.portEnd) console.log(`TLDT_PORT_END="${esc(t.portEnd)}"`);
        if (c.editor) console.log(`TLDT_EDITOR="${esc(c.editor)}"`);
      ' "${config}"
    )"
  fi
}

detect_install_command() {
  local dir="$1"
  if [[ -n "${TLDT_INSTALL_CMD}" ]]; then
    echo "${TLDT_INSTALL_CMD}"
    return
  fi
  if [[ -f "${dir}/pnpm-lock.yaml" ]] && command -v pnpm >/dev/null 2>&1; then
    echo "pnpm install"
  elif [[ -f "${dir}/yarn.lock" ]] && command -v yarn >/dev/null 2>&1; then
    echo "yarn install"
  elif [[ -f "${dir}/bun.lockb" ]] && command -v bun >/dev/null 2>&1; then
    echo "bun install"
  elif [[ -f "${dir}/package.json" ]]; then
    echo "npm install"
  else
    echo ""
  fi
}

detect_dev_command() {
  local dir="$1" port="$2"
  if [[ -n "${TLDT_DEV_CMD}" ]]; then
    echo "${TLDT_DEV_CMD//\{\{port\}\}/${port}}"
    return
  fi
  if [[ -f "${dir}/package.json" ]]; then
    # Prefer npm run dev with PORT; works for many frameworks.
    if node -e 'const p=require(process.argv[1]); process.exit(p.scripts&&p.scripts.dev?0:1)' "${dir}/package.json" >/dev/null 2>&1; then
      echo "PORT=${port} npm run dev -- --port ${port}"
      return
    fi
  fi
  echo "PORT=${port} npm run dev"
}

find_free_port() {
  local port
  for port in $(seq "${TLDT_PORT_START}" "${TLDT_PORT_END}"); do
    if ! port_in_use "${port}"; then
      echo "${port}"
      return 0
    fi
  done
  echo "Error: no free port found between ${TLDT_PORT_START} and ${TLDT_PORT_END}" >&2
  return 1
}

detect_editor() {
  local forced="${TLDT_EDITOR:-}"
  case "${forced}" in
    cursor|code|none) echo "${forced}"; return ;;
    "") ;;
    *) echo "${forced}"; return ;;
  esac

  local term="${TERM_PROGRAM:-}"
  local vscode_hook="${VSCODE_IPC_HOOK:-}${VSCODE_GIT_IPC_HANDLE:-}${VSCODE_PID:-}"

  if command -v cursor >/dev/null 2>&1; then
    if [[ "${term}" == "vscode" ]] || [[ -n "${vscode_hook}" ]] || pgrep -xq "Cursor" 2>/dev/null; then
      echo "cursor"; return
    fi
  fi
  if command -v code >/dev/null 2>&1; then
    if [[ "${term}" == "vscode" ]] || [[ -n "${vscode_hook}" ]] || pgrep -xq "Code" 2>/dev/null; then
      echo "code"; return
    fi
  fi
  if command -v cursor >/dev/null 2>&1; then echo "cursor"; return; fi
  if command -v code >/dev/null 2>&1; then echo "code"; return; fi
  echo "none"
}

open_in_editor() {
  local dir="$1" open_flag="$2"
  local editor
  if [[ "${open_flag}" -ne 1 ]]; then
    echo "→ Skipping editor open (--no-open)"
    return
  fi
  editor="$(detect_editor)"
  case "${editor}" in
    cursor) echo "→ Opening new Cursor window…"; cursor -n "${dir}" >/dev/null 2>&1 & ;;
    code) echo "→ Opening new VS Code window…"; code -n "${dir}" >/dev/null 2>&1 & ;;
    none) echo "→ No editor CLI detected; open manually: ${dir}" ;;
    *)
      if command -v "${editor}" >/dev/null 2>&1; then
        echo "→ Opening with ${editor}…"
        "${editor}" "${dir}" >/dev/null 2>&1 &
      else
        echo "→ Editor '${editor}' not found; open manually: ${dir}"
      fi
      ;;
  esac
}

kill_process_tree() {
  local signal="$1" pid="$2" child
  [[ -n "${pid}" ]] || return 0
  while IFS= read -r child; do
    [[ -n "${child}" ]] || continue
    kill_process_tree "${signal}" "${child}"
  done < <(pgrep -P "${pid}" 2>/dev/null || true)
  kill "-${signal}" "${pid}" 2>/dev/null || true
}

kill_port_listeners() {
  local port="$1" pids
  [[ -n "${port}" ]] || return 0
  pids="$(lsof -nP -iTCP:"${port}" -sTCP:LISTEN -t 2>/dev/null || true)"
  [[ -n "${pids}" ]] || return 0
  # shellcheck disable=SC2086
  kill -TERM ${pids} 2>/dev/null || true
  sleep 0.2
  # shellcheck disable=SC2086
  kill -KILL ${pids} 2>/dev/null || true
}

start_detached() {
  local logfile="$1"
  shift
  if command -v setsid >/dev/null 2>&1; then
    setsid "$@" >"${logfile}" 2>&1 &
  else
    perl -e 'setpgrp(0,0); exec @ARGV' "$@" >"${logfile}" 2>&1 &
  fi
  echo $!
}
