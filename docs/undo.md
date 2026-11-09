# `tldt undo` / `tldt redo`

**TL;DR:** Get back to a clean last-commit state — and optionally bring the undone work back.

## What `undo` does

One step at a time:

1. **Dirty tree** (staged, unstaged, or untracked) → discard it and match `HEAD` exactly
2. **Clean tree** → uncommit the latest local commit (`reset --hard HEAD~1`), landing clean on the previous commit

Published commits (already on a remote) need `--force` to uncommit.

## Safe undo + redo

```bash
tldt undo --safe    # snapshot first
tldt redo           # restore that snapshot
```

Without `--safe`, undo is destructive and cannot be redone via `tldt redo`.

Snapshots live in `.git/tldt/` (local only).

## Usage

```bash
tldt undo
tldt undo --safe
tldt undo --safe --force
tldt redo
tldt redo --force
```
