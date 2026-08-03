# Dotfiles

Symlinked and templated by [mise](https://mise.jdx.dev/) `[dotfiles]`, secrets [age](https://age-encryption.org/)-encrypted inline in `mise.toml`. See `mise.toml` for what maps where.

Three envs, picked per machine and remembered in `~/.config/dotfiles/envs`:

| env | machine |
|---|---|
| `zsh,git,secrets,agents,darwin` | mac |
| `zsh,git,secrets,agents,omarchy` | linux laptop |
| `agents` | on its own, pi and herdr only, see [README.agents.md](README.agents.md) |

`mise.toml` carries settings and no files, so an env list gets exactly what it names. `zsh` is the shell, its aliases and `z`, and installs zsh, oh-my-zsh and the login shell on a box that lacks them. `git` is git and gh, minus the identity: user, signing and the credential helper live in `git/identity`, linked as `~/.gitconfig.local` by the two machine envs, so a server gets the aliases without a signing key it does not have. `secrets` is the age-encrypted `[vars]` and everything rendered from them, loaded only where the age identity exists: mise decrypts `[vars]` on every config load, so a keyless machine has to not load that file at all. `agents` is pi and herdr, references no secret, and stands alone on a server.

## Setup on a New Machine

The age private key lives in Bitwarden under **"dotfiles/age-key"**. Unlock the desktop app (Touch ID), copy the note, then:

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles
mkdir -p ~/.config/mise && (umask 077; pbpaste > ~/.config/mise/age.txt) && pbcopy < /dev/null
age-keygen -y ~/.config/mise/age.txt   # must print age1e2qkevjus09dfzmr82xppyuedlcya5283kf0u4ydsk7qgyhqgumspm36nl
cd ~/fcode/dotfiles && ./install zsh,git,secrets,agents,darwin
```

## Commands

```bash
./install                                    # apply everything for this machine's envs
./install zsh,git,secrets,agents,omarchy        # change this machine's envs, then apply
mise -E "$(cat ~/.config/dotfiles/envs)" dotfiles status   # what is out of sync
mise set --age-encrypt --prompt NAME         # add or change a private value, then ./install
```

Plain files are symlinked, so editing them in the repo is enough. Templates (`*.tmpl`) need `./install` to re-render.
