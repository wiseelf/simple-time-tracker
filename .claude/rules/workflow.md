# Git Workflow & Commit Conventions

> Full contributing guide is in [README.md](../../README.md#contributing).

## Branch discipline

- **Never commit directly to `main`.**
- Branch names: `feature/<short-description>` or `fix/<short-description>`.
- Open a PR against `main` when done; merge only after review.

## Commit messages (Conventional Commits)

```
<type>[optional scope]: <short description>
```

| Type | Version bump |
|---|---|
| `fix:` | patch |
| `feat:` | minor |
| `feat!:` / `BREAKING CHANGE:` | major |
| `chore:`, `docs:`, `refactor:`, `test:`, `style:` | patch |

## Keeping README.md current

**README.md is the authoritative user-facing documentation for this project.**

Update `README.md` whenever you:
- Add, remove, or rename a source file (Project Structure section)
- Add or change a user-facing feature (Features section)
- Change a public API method on `TimerManager` or `SessionStore` (Architecture tables)
- Change the tab layout or any top-level UI structure (Architecture → ContentView section)
- Change menu bar icon states, keyboard shortcuts, or data-storage paths

Do not defer README updates to a separate commit — include them in the same commit as the feature or fix.
