# Dotfiles

fc-agents, a Debian trixie arm64 VPS where agents run through Paseo and pi, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where. The `main` branch is the Omarchy laptop, laid out the same way, and this branch keeps only what the server needs: the global mise tools, the Paseo daemon and its config, pi's settings, Tailscale, sysstat, zsh for Paseo terminals and git commit signing with the server's `~/.ssh/id_ed25519` key.

Nothing here is secret, so the server needs neither Bitwarden nor fnox. That is why `~/.pi/agent/mcp.json` stays out: it holds the Slack MCP OAuth client secret.

## Apply

vps-ansible provisions the host first: the francois user with sudo, the base and dev packages, and mise from its apt repository. Then, over SSH as francois:

```bash
gh repo clone fcatuhe/dotfiles ~/.dotfiles -- -b fc-agents
cd ~/.dotfiles
mise trust
mise bootstrap
tailscale up
mise run tailscale:serve-paseo
```

Then add fc-agents in the Paseo apps as [Paseo connections](#paseo-connections) describes, and type `/login` in pi. The Paseo plugins listed in `~/.paseo/config.json` keep their code in `~/.paseo/plugins`, which is not tracked, so install them again with `paseo plugin install paseo-cafe/cafe` and `paseo plugin install a31521424/host-monitor`.

It refuses to replace a file already in `$HOME`, such as a `~/.config/mise/config.toml` written by hand. Back it up, then rerun with `--force-dotfiles`.

### What the bootstrap does

1. Adds Tailscale's apt repository in `/etc/apt/sources.list.d/mise-tailscale.sources`, then installs `tailscale`, whose package enables `tailscaled`.
2. Installs `sysstat` and enables it. It samples CPU, RAM, load, memory and CPU stall, disk and network every minute, and keeps 28 days in `/var/log/sysstat/saDD`. Read that history with `sar` before resizing the server, for example from CAX31 to CAX41.
3. Installs zsh, zsh-autosuggestions and zsh-syntax-highlighting from apt, clones oh-my-zsh into `~/.oh-my-zsh`, then applies `[dotfiles]`.
4. Writes and starts the `dev.mise.paseo` user service, which runs `paseo daemon run` on `127.0.0.1:6767`. Its PATH starts with the mise shims, so each agent gets the Ruby or Node its repository pins.
5. Writes the `dev.mise.mise-upgrade` user service and its timer, at 04:00 Paris time. It runs `mise upgrade` from the home directory, so it upgrades the global tools and leaves the versions that projects pin alone. Then it restarts the Paseo daemon when the daemon runs an older version than the one installed, which interrupts the agents running at that time. mise removes the replaced versions 24 hours later. francois lingers, so the timer runs without a login session.
6. Installs the mise tools.
7. Runs `setup:tailscale-operator`, so francois runs `tailscale serve` without sudo, as patoumatic's `bin/dev --tailscale` does.
8. Runs `setup:gh-signoff`, which installs the `basecamp/gh-signoff` extension for gh. badger's `bin/ci` runs `gh signoff` once its checks pass, so a pull request can merge without waiting for the GitHub runners.

vps-ansible must not declare the Tailscale repository in `apt_repositories` for this host: apt refuses two sources for the same URL signed by different keyrings. It lists `origin=Tailscale` in `security_autoupdate_origins` instead, so unattended-upgrades installs new Tailscale releases daily with the Debian packages.

## Paseo

`~/.paseo/config.json` is a symlink into this repo. Paseo rewrites it whenever a setting changes in the app or through `paseo daemon config set`, and it writes to the file the link points at, so those changes show up here as a diff to commit. It also rewrites a plugin's `path` when the plugin updates. The rest of `~/.paseo` is state or secret and stays out: the daemon keypair, the local credential, agents, projects, schedules, worktrees and logs.

`~/.pi/agent/settings.json` is tracked the same way, since pi writes to it too, for example `lastChangelogVersion` after an upgrade.

## Paseo connections

The daemon listens on `127.0.0.1:6767` only. Ports 80, 443 and 6767 stay closed to the internet. The Paseo relay stays off, as `relay.enabled` in `~/.paseo/config.json` sets it, and the apps reach the daemon in two ways.

- The Android app connects directly to `fc-agents.airplane-catfish.ts.net` on port 6767 with SSL on. `tailscale serve` forwards that tailnet-only HTTPS endpoint, with a certificate Tailscale issues, to the daemon on the same port. It binds the tailnet address and the daemon binds loopback, so the two never clash. `tailscaled` keeps the mapping in its own state, so it survives restarts and reboots without a systemd unit. The daemon rejects a Host header it does not know, so `daemon.hostnames` in `~/.paseo/config.json` lists the tailnet name.
- The desktop app uses the same direct connection, and falls back to Remote SSH to `fc-agents`, which tunnels to `127.0.0.1:6767` and needs nothing on the server.

Tailscale peers connect directly over UDP 41641, which the Hetzner firewall rule `tailscale-direct` allows in. Without it, a device behind a strict NAT falls back to Tailscale's DERP relay. ufw needs no rule: tailscaled accepts its own port in its `ts-input` chain, which runs before ufw.

## Shell

zsh in Paseo terminals, bash everywhere else. Paseo starts every new terminal in the daemon's `$SHELL`, so the `dev.mise.paseo` unit sets `SHELL=/usr/bin/zsh` for the daemon only, and Paseo adds its own zsh integration on top. The login shell, SSH sessions and cron stay on bash. pi runs its bash tool with bash whatever `$SHELL` says, so the agents are unaffected. `~/.zshrc` follows the `main` branch's: oh-my-zsh with the `robbyrussell` theme and the `git`, `history-substring-search`, `kamal` and `mise` plugins, `LESS=-FR`, Ctrl+U deleting to the start of the line, then zsh-autosuggestions and zsh-syntax-highlighting last. It drops `vscode`, emscripten and the scw completion, which only the laptop has. `~/.config/shell/aliases` keeps the pi and utility aliases and drops `gs` and `wt`, since this git config has no `sweep` or `wt`. Only zsh sources it: bash keeps Debian's `~/.bashrc`.

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
mise bootstrap plan              # what an apply would change
mise bootstrap linux systemd-units status   # the Paseo and mise upgrade units
journalctl --user -u dev.mise.paseo -f      # the Paseo daemon log
systemctl --user list-timers     # when the next mise upgrade runs
journalctl --user -u dev.mise.mise-upgrade   # what the last ones upgraded
sar -r -f /var/log/sysstat/sa28  # RAM on the 28th, -u for CPU, -q MEM or -q CPU for stall
```
