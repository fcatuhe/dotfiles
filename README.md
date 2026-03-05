# Dotfiles

Managed with [dotbot](https://github.com/anishathalye/dotbot) + [age](https://age-encryption.org/) encryption.

## Setup on a New Machine

```bash
# Clone with submodules
git clone --recurse-submodules git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles

# Get the age key from Bitwarden ("dotfiles age key") and save it
cd ~/fcode/dotfiles
# Paste key into encrypted/age.key
./install
```

## How It Works

- **Plain dotfiles** (aliases, zshrc, gitconfig…) are symlinked to `$HOME` by dotbot
- **Private config** (SSH hosts, AWS account IDs, API keys) lives in `encrypted/`, encrypted with age
- **On install**, `encrypted/decrypt` renders source files into `private/` (gitignored, chmod 700), then dotbot symlinks everything — both plain and private files
- **Platform-specific links** use dotbot's `if` guards (e.g. VS Code settings path differs on macOS vs Linux)

## Workflow

| Task | Command |
|------|---------|
| Apply all dotfiles | `./install` |
| Edit private values | `./encrypted/edit` then `./install` |

### Making Changes

**Plain files:** edit directly in the repo, then `./install` to re-link.

**Private values:** run `./encrypted/edit`, then `./install` to decrypt and re-link.

### Syncing

```bash
# Push
git add -A && git commit -m "Update" && git push

# Pull on another machine
git pull && ./install
```

## Encryption

Private values are stored in `encrypted/private.env.age`. Source files with `{{PLACEHOLDER}}` variables live in `encrypted/` mirroring the folder structure of `private/`. On install, placeholders are replaced with decrypted values and written to `private/`.

The `encrypted/` folder is self-contained: age config, key, encrypted values, source files, and scripts.

### Key Management

The age private key is stored in Bitwarden under **"dotfiles/encrypted/age.key"**.

On a new machine:
1. Retrieve the key from Bitwarden
2. Save to `encrypted/age.key` (gitignored)
3. Run `./install`

### Editing Private Values

```bash
./encrypted/edit    # decrypt → $EDITOR → re-encrypt
./install           # decrypt into private/ and re-link
```

## Structure

```
install                                     # Dotbot entry point (stock script)
install.conf.yaml                           # Dotbot config (symlinks, if guards, shell hooks)
encrypted/                                  # Encryption module (self-contained)
  age.conf                                  # Age settings (recipient, identity, private file)
  age.key                                   # Age identity (gitignored)
  private.env.age                           # Encrypted private values (committed)
  decrypt                                   # Render source files into private/
  edit                                      # Decrypt → edit → re-encrypt
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
claude/
  settings.json                             # → ~/.claude/settings.json
  statusline-command.sh                     # → ~/.claude/statusline-command.sh
dotbot/                                     # Dotbot submodule
```
