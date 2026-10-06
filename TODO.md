# TODO

A fresh machine should end up with every project cloned, its tools installed, its secrets in place and every CLI logged in, from one password manager unlock and a few commands.

## Projects

Clone the working repositories and install their tools on bootstrap.

- Trust the projects directory in the global mise settings, so a fresh clone does not stop at a trust prompt.
- Add a `setup:projects` task listing the repositories: clone each one that is missing, then run `mise install` inside it.
- Skip git worktrees: their branches live on the remote and are recreated on demand.

## Secrets

Keep secrets in three tiers, all unlocked from the password manager.

- Root: the age identity, backed up in Bitwarden. Unlocking the desktop app also brings up the SSH agent, so cloning works first.
- Project environment variables: age-encrypted inline in each project's own `mise.toml` with `mise set --age-encrypt`, replacing untracked env files. Public repositories keep high-value values out, encrypted or not.
- Secret files that must exist on disk: one Bitwarden secure note per file, named by its path, grouped in one folder. A `secrets:pull` task unlocks the CLI, writes each note to its path with owner-only permissions, and refuses to overwrite a local file that differs.
- Deploy-time secrets: fetch them from the password manager at deploy time rather than keeping them on disk.
- Never export a production decryption key as a global environment variable, since frameworks read it before per-environment key files and break the other environments.

## Auth

Log in again on each machine rather than copying tokens.

- Add an `auth` task that runs each CLI's login only when its status check fails.
- Tokens are per-device, revocable, and some rotate on refresh, so a copied one can log out the other machine.
- Static API keys are the exception: store them as secret files and restore them through `secrets:pull`.

## Not doing

Mirroring whole folder trees into the password manager: git already holds everything but a handful of small secret files, and a mirror would need syncing both ways by hand.

## Fresh machine

1. Unlock the password manager and restore the age identity.
2. `mise bootstrap`: dotfiles, tools, projects.
3. `mise run secrets:pull`
4. `mise run auth`

Then document the result in the README and delete this file.
