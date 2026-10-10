# TODO

A fresh machine should end up with every project cloned, its tools installed, its secrets in place and every CLI logged in, from one password manager unlock and a few commands.

## Secrets

The projects read their keys from Bitwarden through fnox, and CI from the GitHub `production` environment. What is left:

- Limit each `production` environment to `main`, so a workflow on another branch cannot declare it.
- Move each CI deploy key into Bitwarden as an SSH key item named `<project>-github-actions`, since a private key spans lines that a single-line custom field may lose, rotated on the server and set in GitHub as `DEPLOY_SSH_KEY` in place of `SSH_PRIVATE_KEY`.
- Unlock `bw` by fingerprint through the desktop app once that lands in a release, merged upstream but unreleased, then document it in the README.

## Auth

Log in again on each machine rather than copying tokens.

- Add an `auth` task that runs each CLI's login only when its status check fails.
- Tokens are per-device, revocable, and some rotate on refresh, so a copied one can log out the other machine.
- Static API keys are the exception: store them in Bitwarden and write them through a dotfiles template.

## Not doing

Mirroring whole folder trees into the password manager: git already holds everything but a handful of small secret files, and a mirror would need syncing both ways by hand.

## Fresh machine

After the README's Apply steps, which clone the repositories and read their secrets, the logins come with `mise run auth`.

Then document the result in the README and delete this file.
