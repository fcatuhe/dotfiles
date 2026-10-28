# Dotfiles

fc-agents, a Debian trixie arm64 VPS where agents run through Paseo and pi, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where. The `main` branch is the Omarchy laptop, laid out the same way, and this branch keeps only what the server needs: the global mise tools, Tailscale, sysstat and git commit signing with the server's `~/.ssh/id_ed25519` key.

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
2. Installs `sysstat` and enables it. It samples CPU, RAM, load, memory and CPU stall, disk and network every minute, and keeps 28 days in `/var/log/sysstat/saDD`. Read that history with `sar` before resizing the server, for example from CAX31 to CAX41.
3. Applies `[dotfiles]`.
4. Writes the `dev.mise.mise-upgrade` user service and its timer, at 04:00 Paris time. It runs `mise upgrade` from the home directory, so it upgrades the global tools and leaves the versions that projects pin alone. Then it restarts the Paseo daemon when the daemon runs an older version than the one installed, which interrupts the agents running at that time. mise removes the replaced versions 24 hours later. francois lingers, so the timer runs without a login session.
5. Installs the mise tools.
6. Runs `setup:tailscale-operator`, so francois runs `tailscale serve` without sudo, as patoumatic's `bin/dev --tailscale` does.

vps-ansible must not declare the Tailscale repository in `apt_repositories` for this host: apt refuses two sources for the same URL signed by different keyrings. It lists `origin=Tailscale` in `security_autoupdate_origins` instead, so unattended-upgrades installs new Tailscale releases daily with the Debian packages.

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
mise bootstrap plan              # what an apply would change
systemctl --user list-timers     # when the next mise upgrade runs
journalctl --user -u dev.mise.mise-upgrade   # what the last ones upgraded
sar -r -f /var/log/sysstat/sa28  # RAM on the 28th, -u for CPU, -q MEM or -q CPU for stall
```
