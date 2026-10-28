# Dotfiles

fc-agents, a Debian trixie arm64 VPS where agents run through Paseo and pi, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where. The `main` branch is the Omarchy laptop, laid out the same way, and this branch keeps only what the server needs: the global mise tools and Tailscale.

Nothing here is secret, so the server needs neither Bitwarden nor fnox.

## Apply

vps-ansible provisions the host first: the francois user with sudo, the base and dev packages, and mise from its apt repository. Then, over SSH as francois:

```bash
gh repo clone fcatuhe/dotfiles ~/.dotfiles -- -b fc-agents
cd ~/.dotfiles
mise trust
mise bootstrap
tailscale up
```

It refuses to replace a file already in `$HOME`, such as a `~/.config/mise/config.toml` written by hand. Back it up, then rerun with `--force-dotfiles`.

### What the bootstrap does

1. Adds Tailscale's apt repository in `/etc/apt/sources.list.d/mise-tailscale.sources`, then installs `tailscale`, whose package enables `tailscaled`.
2. Applies `[dotfiles]`.
3. Writes the `dev.mise.mise-upgrade` user service and its timer, at 04:00 Paris time. It runs `mise upgrade` from the home directory, so it upgrades the global tools and leaves the versions that projects pin alone. Then it restarts the Paseo daemon when the daemon runs an older version than the one installed, which interrupts the agents running at that time. mise removes the replaced versions 24 hours later. francois lingers, so the timer runs without a login session.
4. Installs the mise tools.
5. Runs `setup:tailscale-operator`, so francois runs `tailscale serve` without sudo, as patoumatic's `bin/dev --tailscale` does.

vps-ansible must not declare the Tailscale repository in `apt_repositories` for this host: apt refuses two sources for the same URL signed by different keyrings. It lists `origin=Tailscale` in `security_autoupdate_origins` instead, so unattended-upgrades installs new Tailscale releases daily with the Debian packages.

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
mise bootstrap plan              # what an apply would change
systemctl --user list-timers     # when the next mise upgrade runs
journalctl --user -u dev.mise.mise-upgrade   # what the last ones upgraded
```
