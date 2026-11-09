# `tldt sync`

**TL;DR:** Bring your current branch up to date with the latest base branch.

**Main features:**
- Fetch `origin/<base>` (or use local base) and rebase or merge
- Refuses to run on a dirty tree (commit, stash, or `tldt undo` first)
- Reinstalls dependencies when a lockfile changes (configurable)

## Usage

```bash
tldt sync
tldt sync develop --merge
tldt sync main --local --no-install
```

## Optional repo config (`.tldt.json`)

```json
{
  "sync": {
    "defaultBase": "main",
    "strategy": "rebase",
    "reinstall": true
  }
}
```
