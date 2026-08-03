# Dotfiles

Symlinked and templated by [mise](https://mise.jdx.dev/) `[dotfiles]`, secrets [age](https://age-encryption.org/)-encrypted inline in `mise.toml`. See `mise.toml` for what maps where.

Three envs, picked per machine and remembered in `~/.config/dotfiles/envs`:

| env | machine |
|---|---|
| `darwin,agents` | mac |
| `omarchy,agents` | linux laptop |
| `agents` | on its own, pi and herdr only, see [README.agents.md](README.agents.md) |

`mise.toml` holds what every machine gets. `mise.agents.toml` holds pi and herdr and needs no secrets, which is what makes it safe to apply on a server.

## Setup on a New Machine

The age private key lives in Bitwarden under **"dotfiles/age-key"**. Unlock the desktop app (Touch ID), copy the note, then:

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles
mkdir -p ~/.config/mise && (umask 077; pbpaste > ~/.config/mise/age.txt) && pbcopy < /dev/null
age-keygen -y ~/.config/mise/age.txt   # must print age1e2qkevjus09dfzmr82xppyuedlcya5283kf0u4ydsk7qgyhqgumspm36nl
cd ~/fcode/dotfiles && ./install darwin,agents
```

## Commands

```bash
./install                                    # apply everything for this machine's envs
./install omarchy,agents                     # change this machine's envs, then apply
mise -E "$(cat ~/.config/dotfiles/envs)" dotfiles status   # what is out of sync
mise set --age-encrypt --prompt NAME         # add or change a private value, then ./install
```

Plain files are symlinked, so editing them in the repo is enough. Templates (`*.tmpl`) need `./install` to re-render.
