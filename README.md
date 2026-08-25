# Dotfiles

Omarchy laptop, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where.

The repo lives at mise's default `dotfiles.root` and mirrors `$HOME`, so `.config/tmux/tmux.conf` here is `~/.config/tmux/tmux.conf` there and an entry needs no `source`.

Only files that diverge from Omarchy's install templates are tracked. The rest of `~/.config/hypr/` is pristine, so tracking it would only cause conflicts on `omarchy update`.

## Apply

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
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
mise bootstrap dotfiles add -l ~/.config/foo/bar.toml   # track a new file, or capture a copy-mode one after editing it live
```

Run them from `~/.dotfiles`, and pass `-l` to `add` so the entry lands in `mise.toml` rather than the global config.

Symlinked files are live: editing them in the repo or in `~` is the same file. The `mode = "copy"` entries are the exception, one per app that rewrites its own config file.

`~/.config/uwsm/env.d/bitwarden-ssh` points `SSH_AUTH_SOCK` at the Bitwarden desktop SSH agent. uwsm sources it once at session start, so it takes effect on next login.
