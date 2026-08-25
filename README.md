# Dotfiles

Omarchy laptop, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where.

Only files that diverge from Omarchy's install templates are tracked. The rest of `~/.config/hypr/` is pristine, so tracking it would only cause conflicts on `omarchy update`.

## Apply

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles
cd ~/fcode/dotfiles
mise trust
mise bootstrap dotfiles apply
```

## Secrets

Encrypted values live inline in `mise.toml` as `{ age = "..." }`, decrypted by the age identity at `~/.config/mise/age.txt`. Its recipient is `age12egydh7ye67fnykrjnqv89tdjscv6xnnssykt4yvnck4trrpzu0qvsdlkj`, one identity per machine, so a second machine gets its own and values are encrypted to both recipients rather than the key being copied around.

The identity is backed up in Bitwarden as a note named `~/.config/mise/age.txt`. On a fresh machine, unlock the desktop app, copy the note, then:

```bash
mkdir -p ~/.config/mise
(umask 077; wl-paste > ~/.config/mise/age.txt)
wl-copy --clear
age-keygen -y ~/.config/mise/age.txt   # must print the recipient above
```

Add or change a secret with `mise set --age-encrypt --prompt NAME`. It writes to `[env]`, which reaches processes mise activates. A secret rendered into a config file has to be moved to `[vars]` by hand and referenced as `{{ vars.NAME }}`, because a template's `env` namespace is the process environment, not the `[env]` section.

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
mise bootstrap dotfiles apply    # symlink everything into place
mise bootstrap dotfiles add ~/.config/omarchy/shell.json   # capture a copy-mode file after editing it live
```

Symlinked files are live: editing them in the repo or in `~` is the same file. `~/.config/omarchy/shell.json` is the exception, it is copied because the Omarchy shell rewrites it in place.

`~/.config/uwsm/env.d/bitwarden-ssh` points `SSH_AUTH_SOCK` at the Bitwarden desktop SSH agent. uwsm sources it once at session start, so it takes effect on next login.
