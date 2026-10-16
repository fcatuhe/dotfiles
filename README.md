# Dotfiles

azade, a Debian trixie arm64 VPS, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where. The `main` branch is the Omarchy laptop, laid out the same way, and this branch keeps only what the server needs: zsh in herdr, pi with pi-wares, and Brave Origin on a virtual display seen through noVNC over Tailscale.

Nothing here is secret, so the server needs neither Bitwarden nor fnox.

## Apply

Over SSH as francois, who has sudo and lingers, so the user units run without a login session. mise and herdr come from their own installers, in `~/.local/bin`.

```bash
git clone -b azade https://github.com/fcatuhe/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
mise trust
mise bootstrap
```

It refuses to replace a file already in `$HOME`, such as herdr's own `config.toml`. Back those up, then rerun with `--force-dotfiles`.

In pi, type `/login`. Then open noVNC and log in to the sites in the agent-browser profile.

### What the bootstrap does

1. Adds Brave's and Tailscale's apt repositories, then installs `[bootstrap.packages]` with sudo.
2. Clones oh-my-zsh into `~/.oh-my-zsh`.
3. Applies `[dotfiles]`.
4. Writes and starts the `dev.mise.xvfb`, `dev.mise.x11vnc` and `dev.mise.novnc` user units.
5. Installs the mise tools: node, pi and agent-browser.
6. Runs `setup:tailscale-serve`, which publishes noVNC on the tailnet.

## Shell

zsh inside herdr, bash everywhere else. `default_shell` in `~/.config/herdr/config.toml` starts zsh in every herdr pane, the login shell stays bash. `~/.zshrc` is the laptop's, minus the Arch paths and scw: Debian puts zsh-autosuggestions and zsh-syntax-highlighting in `/usr/share/<name>/`. It exports `DISPLAY=:99`, so pi and agent-browser started in herdr open their windows on the virtual display.

The herdr config is the one azade already had, with the Mac chords, plus `default_shell`. Reload it with `prefix+q`. Panes opened before keep bash.

## Browser

Brave Origin from Brave's apt repository, which builds it for arm64. agent-browser drives it headed on display `:99`, through the pi-wares `agent-browser` skill, whose `setup.sh` writes `~/.agent-browser/config.json` once.

The display is `https://azade.airplane-catfish.ts.net:6080/vnc.html`, reachable from the tailnet only. It has a port of its own because noVNC asks for its websocket at the root of the address, so under a path it needs `?path=` in every URL. Every hop is private to francois:

- `dev.mise.xvfb` runs Xvfb on `:99`, 1440x900, with an X cookie in `~/.Xauthority` written at each start. Without it, any local user could open the display, the `azade` user included.
- `dev.mise.x11vnc` serves that display on `/run/user/1001/x11vnc.sock` and on no TCP port.
- `dev.mise.novnc` runs websockify with the noVNC client on `/run/user/1001/novnc.sock`.
- `tailscale serve` proxies HTTPS port 6080 to that socket, with the Tailscale certificate. Serving a socket needs root even for the operator, so the task uses sudo. The setting lives in tailscaled, not in a file, and survives reboots.

The `azade` user has her own display `:100`, x11vnc and noVNC, for openclaw's Chromium. On 16oct26 her display moved from `:99` and her noVNC from 6080 to 6081, in her `xvfb`, `x11vnc` and `novnc-websockify` user units and `~/.openclaw/gateway.systemd.env`, which this repo does not manage.

## Commands

```bash
mise bootstrap dotfiles status            # what is out of sync
mise bootstrap linux systemd-units status # the display, VNC and noVNC units
mise bootstrap plan                       # what an apply would change
```
