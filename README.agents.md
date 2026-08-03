# Agents

Runs pi and herdr with the same settings as the laptops. The `agents` env applies three config files and nothing templated, so the age identity never has to leave your machines.

## Prerequisites on a VPS

`git` and `curl`. Most images ship both, a bare Debian or Ubuntu may not:

```bash
sudo apt-get update && sudo apt-get install -y git curl
```

git is not only for the clone below: pi shells out to it to fetch skills from `git:github.com/fcatuhe/pi-wares` on startup.

## Install

```bash
curl https://mise.run | sh
git clone https://github.com/fcatuhe/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install agents
```

This links pi's settings, its model-shortcuts extension, and the herdr config, then installs whatever is missing:

```bash
curl -fsSL https://pi.dev/install.sh | sh
curl -fsSL https://herdr.dev/install.sh | sh
```

Later runs are just `./install`, the env is remembered in `~/.config/dotfiles/envs`.

Use `./install zsh,cli,agents` to get the shell, git, gh and npm on the box as well. Neither env holds encrypted vars, so neither needs the age identity. `zsh` installs zsh and oh-my-zsh and makes zsh the login shell, which needs `sudo`.
