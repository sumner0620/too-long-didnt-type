# too-long-didnt-type (`tldt`)

**TL;DR:** Short, memorable commands for long developer workflows. Install once, then type less.

**Main features:**
- A tiny CLI (`tldt`) that grows with new shortcuts over time
- Works in **any** git repo (not tied to a specific company or stack)
- Optional per-repo config via `.tldt.json`
- Designed so new shortcuts are just a folder under `commands/`

## Install

```bash
npm install -g too-long-didnt-type
# or use without global install:
npx too-long-didnt-type tree --help
```

```bash
tldt help
tldt commands
```

## Shortcuts

### `tree` — parallel worktrees + free-port dev servers

```bash
tldt tree feature/login          # new worktree + free port + npm install + dev
tldt tree --list                 # what’s running where
tldt tree rm feature/login       # tear down (stops the server too)
```

Full docs: [docs/tree.md](docs/tree.md)

### `pr` — push + open a pull request

```bash
tldt pr                          # push branch, create PR (requires gh)
tldt pr "Add login flow"
tldt pr --draft --fill
```

Full docs: [docs/pr.md](docs/pr.md)

### `sync` — update from the latest base branch

```bash
tldt sync                        # fetch + rebase onto origin/main
tldt sync develop --merge
```

Full docs: [docs/sync.md](docs/sync.md)

### `undo` / `redo` — get back to a clean last commit

```bash
tldt undo                        # discard dirty work, or uncommit last local commit
tldt undo --safe                 # same, but snapshot for redo
tldt redo                        # restore last --safe undo
```

Full docs: [docs/undo.md](docs/undo.md)

## Adding more shortcuts

See [docs/ADDING-COMMANDS.md](docs/ADDING-COMMANDS.md).

## Optional repo config

Drop a `.tldt.json` in a project root to override defaults:

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
  },
  "pr": {
    "defaultBase": "main",
    "draft": false
  },
  "sync": {
    "defaultBase": "main",
    "strategy": "rebase",
    "reinstall": true
  }
}
```

## Development

```bash
git clone <this-repo>
cd too-long-didnt-type
npm link          # puts `tldt` on your PATH from this checkout
tldt commands
```

## License

MIT
