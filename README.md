# too-long-didnt-type (`tldt`)

**TL;DR:** Short, memorable commands for long developer workflows. Install once, then type less.

**Main features:**
- A tiny CLI (`tldt`) that grows with new shortcuts over time
- First shortcut: **`tldt tree`** — parallel git worktrees + free-port dev servers in one command
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

## First shortcut: `tree`

```bash
tldt tree feature/login          # new worktree + free port + npm install + dev
tldt tree --list                 # what’s running where
tldt tree rm feature/login       # tear down (stops the server too)
```

Full docs: [docs/tree.md](docs/tree.md)

## Adding more shortcuts

This package is meant to keep growing — PR flows, release checklists, env bootstrap, whatever you type too often.

See [docs/ADDING-COMMANDS.md](docs/ADDING-COMMANDS.md).

## Optional repo config

Drop a `.tldt.json` in a project root to override defaults (base branch, install/dev commands, ports, editor). Example in [docs/tree.md](docs/tree.md).

## Development

```bash
git clone <this-repo>
cd too-long-didnt-type
npm link          # puts `tldt` on your PATH from this checkout
tldt tree --help
```

## License

MIT
