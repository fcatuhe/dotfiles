# Dotfiles

Symlinked and templated by [mise](https://mise.jdx.dev/) `[dotfiles]`, secrets [age](https://age-encryption.org/)-encrypted inline in `mise.toml`. See `mise.toml` for what maps where.

## Setup on a New Machine

The age private key lives in Bitwarden under **"dotfiles/age-key"**. Unlock the desktop app (Touch ID), copy the note, then:

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles
mkdir -p ~/.config/mise && (umask 077; pbpaste > ~/.config/mise/age.txt) && pbcopy < /dev/null
age-keygen -y ~/.config/mise/age.txt   # must print age1e2qkevjus09dfzmr82xppyuedlcya5283kf0u4ydsk7qgyhqgumspm36nl
cd ~/fcode/dotfiles && ./install
```

## Commands

```bash
./install                                    # apply everything
mise dotfiles status                         # what is out of sync
mise set --age-encrypt --prompt NAME         # add or change a private value, then ./install
```

Plain files are symlinked, so editing them in the repo is enough. Templates (`*.tmpl`) need `./install` to re-render.
