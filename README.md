# Dotfiles

Managed with [mise](https://mise.jdx.dev/) `[dotfiles]`, secrets encrypted with [age](https://age-encryption.org/) inline in `mise.toml`.

## Setup on a New Machine

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles

# Restore the age key. Unlock Bitwarden desktop (Touch ID), copy the "dotfiles/age-key" note, then:
mkdir -p ~/.config/mise && (umask 077; pbpaste > ~/.config/mise/age.txt) && pbcopy < /dev/null

# Verify it is the right key before relying on it
age-keygen -y ~/.config/mise/age.txt   # must print age1e2qkevjus09dfzmr82xppyuedlcya5283kf0u4ydsk7qgyhqgumspm36nl

cd ~/fcode/dotfiles
./install
```

On a headless box with no clipboard, use the CLI instead. It needs a full `bw login` first (2FA), because a stale or absent refresh token makes `bw unlock` fail with `invalid_grant`:

```bash
bw login && bw sync
mkdir -p ~/.config/mise && (umask 077; BW_SESSION=$(bw unlock --raw) bw get notes "dotfiles/age-key" > ~/.config/mise/age.txt)
```

The `umask 077` matters: without it the redirect creates the key world-readable before any `chmod` could fix it. The verify step matters because a failed fetch still leaves an empty file, and mise would then fall through to SSH identities and fail with a misleading `No matching keys found`.

## How It Works

- **Plain dotfiles** (aliases, zshrc, gitconfig...) are symlinked to `$HOME`
- **Private values** (SSH hosts, AWS account IDs, API keys) live age-encrypted in `[vars]` in `mise.toml`, safe to commit
- **Files containing private values** are `.tmpl` sources rendered to `$HOME` with `{{ vars.NAME }}` substitution. Nothing is staged on disk in between
- **Platform-specific links** live in `mise.darwin.toml` / `mise.linux.toml`, selected by `install` via `-E $(uname)`
- **`openlogi/config.toml`** uses `mode = "copy"` because the app rewrites its config in place, which would break a symlink

## Workflow

| Task | Command |
|------|---------|
| Apply all dotfiles | `./install` |
| See what is out of sync | `mise dotfiles status` |
| Add or change a private value | `mise set --age-encrypt --prompt NAME` then `./install` |
| Read a private value | `mise set NAME` |
| Capture in-place edits back to the repo | `mise dotfiles add ~/.config/openlogi/config.toml` |
| Remove what mise linked | `mise dotfiles unapply` |

**Plain files:** edit directly in the repo. Symlinks mean no re-run needed.

**Templates:** edit the `.tmpl`, then `./install` to re-render.

### Syncing

```bash
git add -A && git commit -m "Update" && git push
git pull && ./install   # on another machine
```

## Encryption

Private values are stored per-key in `[vars]` as age ciphertext, encrypted to the public key of `~/.config/mise/age.txt`. mise has age built in, so no `age` or `sops` CLI is required to apply dotfiles.

Rendered targets inherit their `.tmpl` source's mode. Git cannot store file modes, so a fresh clone's sources are 644; the `pre-dotfiles` hook chmods the sources to 600 before rendering, which is what keeps secrets in `$HOME` private.

### Key Management

The age private key is stored in Bitwarden under **"dotfiles/age-key"** and belongs at `~/.config/mise/age.txt` (mise's default identity path, outside this repo).

To re-key, encrypt each value again with a new recipient:

```bash
mise set --age-encrypt --age-recipient <new-public-key> --prompt NAME
```

## Structure

```
install                                     # mise trust + mise bootstrap --only dotfiles
mise.toml                                   # settings, encrypted [vars], shared [dotfiles]
mise.darwin.toml                            # macOS-only links
mise.linux.toml                             # Linux-only links
ssh/config.tmpl                             # → ~/.ssh/config          (template, 600)
aws/config.tmpl                             # → ~/.aws/config          (template, 600)
zsh/
  zshenv.private.tmpl                       # → ~/.zshenv.private      (template, 600)
  zshenv                                    # → ~/.zshenv
  zshrc                                     # → ~/.zshrc
  zprofile                                  # → ~/.zprofile            (macOS only)
  aliases                                   # → ~/.aliases
git/
  config                                    # → ~/.gitconfig
  ignore                                    # → ~/.config/git/ignore
vscode/
  settings.json                             # → ~/.config/Code/User/settings.json (Linux)
                                            #   ~/Library/.../settings.json (macOS)
pi/
  settings.json                             # → ~/.pi/agent/settings.json
  extensions/                               # → ~/.pi/agent/extensions
  skills/                                   # → ~/.pi/agent/skills
agent-browser/
  auth/                                     # → ~/.agent-browser/auth
  encryption-key.tmpl                       # → ~/.agent-browser/.encryption-key (template, 600)
openlogi/config.toml                        # → ~/.config/openlogi/config.toml (macOS only, copy)
hypr/                                       # → ~/.config/hypr         (Linux only)
waybar/                                     # → ~/.config/waybar       (Linux only)
environment.d/                              # → ~/.config/environment.d (Linux only)
gh/
  config.yml                                # → ~/.config/gh/config.yml
  hosts.yml                                 # → ~/.config/gh/hosts.yml
npm/npmrc                                   # → ~/.npmrc
herdr/config.toml                           # → ~/.config/herdr/config.toml
ghostty/config                              # → ~/.config/ghostty/config
bin/z                                       # → ~/.local/bin/z
```
