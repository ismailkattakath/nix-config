# PR Consolidation — One Open PR Per Working Session

Don't fragment a working session's output across multiple small PRs. When a PR is
already open for the current session's work, push follow-up commits onto that
same branch instead of branching off `main` again for the next change.

## Why

This repo's CI builds are expensive (Nix closure builds pushed to Cachix, plus
installer/devcontainer image publishes), and the costliest workflow does **not**
supersede its own in-flight runs. `build-installers.yml` sets its `concurrency`
group to `cancel-in-progress: false`, so a new push does not cancel an already
running installer publish — the runs **queue** and each one completes in full.
(The cheaper workflows — `nix-ci.yml`, `build-devcontainer.yml`, `gitleaks.yml`,
`claude-config-lint.yml` — do set `cancel-in-progress: true` and self-supersede.)
Because of that non-cancellable release workflow, every extra PR or push spawns
another costly pipeline run that piles up rather than replacing the previous one.
Consolidating a session's work onto one open PR avoids triggering redundant
expensive, non-cancellable runs.

## Mandatory behavior

1. **Before opening a new PR**, check whether a PR from earlier in this session is
   still open (`gh pr list`, or recall the branch/PR you already created/pushed to).
2. **If an open PR from this session exists**, commit and push further changes to
   its branch (`git checkout <branch>`, commit, `git push`) rather than creating a
   new branch/PR — even for a change that touches unrelated files. Update the PR
   title/body to reflect the combined scope when the change set grows.
3. **Exception — the existing PR has already merged.** Once a session's PR lands
   on `main`, its branch is done. The next change starts a fresh branch and a new
   PR — do not try to reuse or reopen a merged branch.
4. **Exception — the user explicitly asks for a separate PR** (e.g. to keep an
   unrelated change reviewable on its own). Explicit instruction overrides the
   default.

## PR title

The PR title is a **comma-separated list of the components the change touches**,
not a prose sentence. As a consolidated PR grows, keep the title in sync with the
combined scope. Components are drawn from two sources:

1. **First-level `nix flake show` categories** — the flake output touched:
   `apps`, `checks`, `packages`, `nixosConfigurations`, `darwinConfigurations`,
   `formatter`, `devShells`.
2. **Top-level dot-folders / non-nix areas**, mapped to short names:
   - `.claude` → `claude`
   - `.github` → `github`
   - `.vscode` → `vscode`
   - `.devcontainer` → `devcontainer`
   - `docs` → `docs` (covers `docs/`, any `*.md`, and `CLAUDE.md`)

List every touched component, comma-separated. Example: a PR touching
`modules/darwin/*` + `.claude/rules/*` + `docs/` → title `darwinConfigurations, claude, docs`.

## Update comment trail

Every time an already-open PR is **updated** — i.e. each push of new commits onto
its branch — post a **new** PR comment summarizing that update's changes:

```bash
gh pr comment <n> --body "<what this push changed and why>"
```

The comment is posted at **push time** (that is when the PR actually updates). The
PR's comment thread thus becomes a chronological trail of every mutation batched
into the consolidated PR: reading the comments top-to-bottom tells you what changed
and when, keeping the one-PR-per-session model auditable.

Optional enhancement: also maintain a running `## Changelog` in the PR **body**,
edited each update (the body reflects the *current* combined state; the comments are
the *chronological* trail). The per-update comment is the required part; the body
changelog is a nicety.

## Quick check

```bash
gh pr list --author "@me" --state open   # any open PR from this session already?
git branch --show-current                 # confirm you're on that PR's branch before committing
```

If the only open PR is already merged (`gh pr view <n> --json state` shows
`MERGED`), start a new branch off latest `main` for the next change.
