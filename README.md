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

## Shell

zsh, through the [omarchy-zsh](https://github.com/omacom/omarchy-zsh) package: `~/.zshrc` loads the packaged `zoptions` (completion menu, keybindings, fzf widgets, syntax highlighting) and `shell/all` (the aliases, functions and tool init shared with bash), then `zsh-autosuggestions`, which upstream shipped for a month and dropped in `4f79a29`.

`~/.bashrc` hands the terminal over with `exec zsh`. `touch ~/.local/state/keep-bash` pins bash from the next terminal on, `rm` it to go back: the login shell in `/etc/passwd` stays bash either way, so scripts, `ssh <host> <cmd>` and systemd units are untouched. The bash side deliberately sources Omarchy's own `default/bash/rc` rather than the package's copy of the shared config, which is a build-time snapshot of [omadots](https://github.com/omacom/omadots) and currently lags 4.0.1 (no `a`, `h`, `mup`).

`omarchy-setup-zsh` is not part of `apply`: it `cp`s its templates over `~/.zshrc` and `~/.bashrc`, which here would write through the symlinks and into this repo. Both files are tracked instead, so a template change upstream has to be diffed in by hand, and `setup:zsh` only installs the packages and drops `~/.inputrc` in place for the bash fallback.

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

Symlinked files are live: editing them in the repo or in `~` is the same file. The `mode = "copy"` entries are the exception, one per app that rewrites its own config file in place, which would replace a symlink with a regular file:

- `~/.config/mimeapps.list`, rewritten by xdg-mime when a default app is set.
- `~/.config/omarchy/shell.json`, rewritten by the shell.
- `~/.config/voxtype/config.toml`, rewritten by the `voxtype configure` TUI, which also rejects a partial config.

Edit those live, then capture them back with `add -l`. `~/.ssh/config` is the other exception, a template: the `pre-dotfiles` hook chmods its source to 600, because a rendered file inherits the source's mode and git tracks only the exec bit, so a fresh clone would otherwise render it world-readable.

`~/.config/uwsm/env.d/bitwarden-ssh` points `SSH_AUTH_SOCK` at the Bitwarden desktop SSH agent. uwsm sources it once at session start, so it takes effect on next login.
