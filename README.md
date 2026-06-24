# Dotfiles

Managed with [dotbot](https://github.com/anishathalye/dotbot) + [age](https://age-encryption.org/) encryption.

## Setup on a New Machine

```bash
# Clone with submodules
git clone --recurse-submodules git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles

# Get the age key from Bitwarden ("dotfiles/encrypted/age.key") and save it
cd ~/fcode/dotfiles
# Paste key into encrypted/age.key
./install
```

## How It Works

- **Plain dotfiles** (aliases, zshrc, gitconfig…) are symlinked to `$HOME` by dotbot
- **Private config** (SSH hosts, AWS account IDs, API keys) lives in `encrypted/`, encrypted with age
- **On install**, `dotbot-age/tools/decrypt` renders source files into `private/` (gitignored, chmod 700), then dotbot symlinks everything — both plain and private files
- **Platform-specific links** use dotbot's `if` guards (e.g. VS Code settings path differs on macOS vs Linux)

## Workflow

| Task | Command |
|------|---------|
| Apply all dotfiles | `./install` |
| Edit private values | `./edit-secrets` then `./install` |

### Making Changes

**Plain files:** edit directly in the repo, then `./install` to re-link.

**Private values:** run `./edit-secrets`, then `./install` to decrypt and re-link.

### Syncing

```bash
# Push
git add -A && git commit -m "Update" && git push

# Pull on another machine
git pull && ./install
```

## Encryption

Private values are stored in `encrypted/secrets.env.age`. Source files with `{{PLACEHOLDER}}` variables live in `encrypted/` mirroring the folder structure of `private/`. On install, placeholders are replaced with decrypted values and written to `private/`.

Decryption and template rendering are handled by the `dotbot-age` submodule (`dotbot-age/tools/decrypt`). The `edit-secrets` script at the repo root is used to edit and re-encrypt secrets.

### Key Management

The age private key is stored in Bitwarden under **"dotfiles/encrypted/age.key"**.

On a new machine:
1. Retrieve the key from Bitwarden
2. Save to `encrypted/age.key` (gitignored)
3. Run `./install`

### Editing Private Values

```bash
./edit-secrets    # decrypt → $EDITOR → re-encrypt
./install         # decrypt into private/ and re-link
```

## Structure

```
install                                     # Dotbot entry point (stock script)
install.conf.yaml                           # Dotbot config (symlinks, if guards, shell hooks)
edit-secrets                                # Decrypt → $EDITOR → re-encrypt secrets
encrypted/                                  # Encrypted private values + source templates
  age.key                                   # Age identity (gitignored)
  secrets.env.age                           # Encrypted private values (committed)
  ssh/config                                # Source: {{SSH_*}} placeholders
  aws/config                                # Source: {{AWS_*}} placeholders
  zsh/zshenv                                # Source: {{BRAVE_API_KEY}} placeholder
private/                                    # Decrypted output (gitignored, chmod 700)
  ssh/config                                # → ~/.ssh/config
  aws/config                                # → ~/.aws/config
  zsh/zshenv                                # → ~/.zshenv.private
git/
  config                                    # → ~/.gitconfig
  ignore                                    # → ~/.config/git/ignore
zsh/
  aliases                                   # → ~/.aliases
  zshrc                                     # → ~/.zshrc
  zprofile                                  # → ~/.zprofile
  zshenv                                    # → ~/.zshenv
vscode/
  settings.json                             # → ~/.config/Code/User/settings.json (Linux)
                                            #   ~/Library/.../settings.json (macOS)
pi/
  settings.json                             # → ~/.pi/agent/settings.json
  extensions/                               # → ~/.pi/agent/extensions
openlogi/
  config.toml                               # → ~/.config/openlogi/config.toml (macOS only)
hypr/                                       # → ~/.config/hypr (Linux only)
waybar/                                     # → ~/.config/waybar (Linux only)
environment.d/                              # → ~/.config/environment.d (Linux only)
gh/
  config.yml                                # → ~/.config/gh/config.yml
  hosts.yml                                 # → ~/.config/gh/hosts.yml
npm/
  npmrc                                     # → ~/.npmrc
dotbot/                                     # Dotbot submodule
dotbot-age/                                 # dotbot-age submodule (decrypt + render templates)
```
