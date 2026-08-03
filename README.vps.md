# Agents on a VPS

Runs pi and herdr on a server with the same settings as the laptops. The `agents` env applies three config files and nothing templated, so the age identity never has to leave your machines.

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

## Credentials

None are provisioned, on purpose. Give pi one provider key by hand. `~/.zshenv.private` is untracked and `.zshenv` sources it when it exists:

```bash
echo 'export ANTHROPIC_API_KEY=sk-ant-...' >> ~/.zshenv.private
```

Add `export EDITOR=vim` there too. The tracked `.zshrc` sets `code --wait`, which hangs `git commit` on a headless box.

## Known: herdr keybindings collide when nested

The tracked herdr config targets the mac: `ctrl+space` prefix and `cmd+shift` chords. SSH in from a machine already running herdr and the outer session takes those chords first, so the remote one never sees them. Give the server its own prefix and modifier for now:

```bash
herdr config check          # after editing
```

Editing `~/.config/herdr/config.toml` on the server edits the repo, since it is a symlink. The real fix is a per-machine variant of that file, which is not built yet.

## Updating

```bash
cd ~/dotfiles && git pull && ./install
herdr update
```
