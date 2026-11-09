# `tldt tree`

**TL;DR:** Spin up a second checkout on its own branch, with its own free-port `dev` server, so you can work on two things at once without stashing or switching branches.

**Main features:**
- Create a git worktree + free port with one command — no stash, no branch-switching, no port juggling
- Base new branches on latest `origin/main` (or any branch) — without leaving your current checkout
- Reuse an existing branch if it already exists — pick up mid-flight work in a second window
- List worktrees and live server URLs (`tldt tree --list`) — see what’s running without hunting terminals
- Open the new folder in Cursor/VS Code automatically — jump straight in
- Tear it down cleanly (`tldt tree rm`) — no leftover servers or orphaned folders

## Usage

```bash
tldt tree feature/login
tldt tree hotfix-auth main --local
tldt tree --list
tldt tree rm feature/login
tldt tree rm feature/login --force --delete-branch
```

## Optional repo config (`.tldt.json`)

```json
{
  "editor": "cursor",
  "tree": {
    "defaultBase": "main",
    "installCommand": "npm install",
    "devCommand": "PORT={{port}} npm run dev -- --port {{port}}",
    "copyEnv": true,
    "portStart": 3001,
    "portEnd": 3099
  }
}
```

## Layout

| Path | Role |
|---|---|
| `../<repo>-<name>` | Extra worktree (`/` in names → `--` in folder) |
| `.tldt/dev.sh` | Generated launcher |
| `.tldt/dev.pid` / `.tldt/dev.log` | Background server |
| `.tldt/tree.json` | Port/url metadata for `--list` |
