# Adding a new shortcut

1. Copy `commands/_template` to `commands/<name>/`
2. Edit `command.json` (`name`, `summary`)
3. Implement `cli.sh` (sourced env includes `TLDT_ROOT`)
4. Reuse helpers from `lib/common.sh` when useful
5. Document it in `docs/<name>.md` and link from the root README
6. Run `tldt commands` — your shortcut should appear

## Conventions

- Prefer a **short verb or noun** users will remember (`tree`, later maybe `pr`, `ship`, `bisect`, …)
- Put the painful multi-step flow behind one obvious command
- Support `--help` on every command
- Keep repo-specific behavior in optional `.tldt.json`, not hard-coded
- Don’t shadow common system commands unless you fall through gracefully
