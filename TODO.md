# TODO

A fresh machine should end up with every project cloned, its tools installed, its secrets in place and every CLI logged in, from one password manager unlock and a few commands.

## Projects

Clone the working repositories and install their tools on bootstrap.

- Trust the projects directory in the global mise settings, so a fresh clone does not stop at a trust prompt.
- Add a `setup:projects` task listing the repositories: clone each one that is missing, then run `mise install` inside it.
- Skip git worktrees: their branches live on the remote and are recreated on demand.

## Secrets

Extend to the projects what the dotfiles already do: Bitwarden as the source, fnox reading it, git holding only references. The README's Secrets section has the naming rules.

- Each project gets a secure note named after it, with one hidden custom field per environment variable, and commits an `fnox.toml` of references such as `project/VARIABLE`.
- mise hands a secret only to the task listing it in `secrets = [...]`, redacted from its output, so the shell, `mise env`, shims and agents never see it. Needs mise 2026.10.4 or newer.
- A production decryption key goes only to the deploy task, never into a global environment, since frameworks read it before per-environment key files.
- Secret files that must sit at a fixed path go through a dotfiles template entry reading a `[bootstrap.secrets]` input, owner-only permissions to check.
- Unlock `bw` by fingerprint through the desktop app once that lands in a release, merged upstream but unreleased, then document it in the README.

## Auth

Log in again on each machine rather than copying tokens.

- Add an `auth` task that runs each CLI's login only when its status check fails.
- Tokens are per-device, revocable, and some rotate on refresh, so a copied one can log out the other machine.
- Static API keys are the exception: store them in Bitwarden and write them through a dotfiles template.

## Not doing

Mirroring whole folder trees into the password manager: git already holds everything but a handful of small secret files, and a mirror would need syncing both ways by hand.

## Fresh machine

After the README's Apply steps, which already read the dotfiles secrets through fnox, the projects come with `mise bootstrap` and the logins with `mise run auth`.

Then document the result in the README and delete this file.
