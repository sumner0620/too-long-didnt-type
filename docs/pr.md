# `tldt pr`

**TL;DR:** Push your branch and open a GitHub pull request in one command.

**Main features:**
- `git push -u` + `gh pr create` without retyping the flow
- Reuses an existing PR for the branch if one is already open
- Draft / ready, base branch, and fill-from-commits flags
- Optional per-repo defaults via `.tldt.json`

## Usage

```bash
tldt pr
tldt pr "Add login flow"
tldt pr --draft --fill
tldt pr --base develop Fix the webhook handler
tldt pr --no-push --no-open
```

Requires the [GitHub CLI](https://cli.github.com/) (`gh`) authenticated to your account.

## Optional repo config (`.tldt.json`)

```json
{
  "pr": {
    "defaultBase": "main",
    "draft": false
  }
}
```
