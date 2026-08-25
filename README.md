# Dotfiles

Omarchy laptop, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where.

Only files that diverge from Omarchy's install templates are tracked. Everything under `~/.config/hypr/` except `monitors.lua` is pristine, so tracking it would only cause conflicts on `omarchy update`.

## Apply

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles
cd ~/fcode/dotfiles
mise trust
mise bootstrap dotfiles apply
```

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
mise bootstrap dotfiles apply    # symlink everything into place
mise bootstrap dotfiles add ~/.config/omarchy/shell.json   # capture a copy-mode file after editing it live
```

Symlinked files are live: editing them in the repo or in `~` is the same file. `~/.config/omarchy/shell.json` is the exception, it is copied because the Omarchy shell rewrites it in place.

`~/.config/uwsm/env.d/bitwarden-ssh` points `SSH_AUTH_SOCK` at the Bitwarden desktop SSH agent. uwsm sources it once at session start, so it takes effect on next login.
