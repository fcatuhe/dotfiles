# Dotfiles

Managed with [dotbot](https://github.com/anishathalye/dotbot) + [age](https://age-encryption.org/) encryption.

## Setup on a New Machine

```bash
# Clone with submodules
git clone --recurse-submodules git@github.com:fcatuhe/dotfiles.git ~/fcode/dotfiles

# Get the age key from Bitwarden ("dotfiles age key") and save it
cd ~/fcode/dotfiles
# Paste key into age.key
./install
```

## How It Works

- **Plain dotfiles** (aliases, zshrc, gitconfig…) are symlinked to `$HOME` by dotbot
- **Private config** (SSH hosts, AWS account IDs, API keys) lives in `private.env.age`, encrypted with age
- **Private files** (`*.private`) contain `{{PLACEHOLDER}}` variables that get replaced at install time with decrypted values, then written (not symlinked) to their destinations
- **Platform-specific links** use dotbot's `if` guards (e.g. VS Code settings path differs on macOS vs Linux)
- **Encryption settings** (recipient, identity path, private file mappings) are centralized in `install.private.yaml`

## Workflow

| Task | Command |
|------|---------|
| Apply all dotfiles | `./install` |
| Edit private values | `./scripts/edit-private` |
| Install private config only | `./scripts/install-private` |

### Making Changes

**Plain files:** edit directly in the repo, then `./install` to re-link.

**Private values:** run `./scripts/edit-private`, then `./install` to re-render.

### Syncing

```bash
# Push
git add -A && git commit -m "Update" && git push

# Pull on another machine
git pull && ./install
```

## Encryption

Private values (IPs, account IDs, API keys) are stored in `private.env.age` — an age-encrypted key=value file. All encryption settings live in `install.private.yaml`.

Only the `.age` file is committed. The decrypted `private.env` is gitignored.

### Key Management

The age private key is stored in Bitwarden under **"dotfiles age key"**.

On a new machine:
1. Retrieve the key from Bitwarden
2. Save to `age.key` in the dotfiles repo (gitignored)
3. Run `./install`

### Editing Private Values

```bash
./scripts/edit-private    # decrypt → $EDITOR → re-encrypt
```

## Structure

```
install                                     # Dotbot entry point (stock script)
install.conf.yaml                           # Dotbot config (symlinks, if guards, shell hooks)
install.private.yaml                        # Private config: age settings + file mappings
age.key                                     # Age identity (gitignored)
private.env.age                             # Encrypted private values (committed)
scripts/
  install-private                           # Decrypt + install .private files
  edit-private                              # Decrypt → edit → re-encrypt
git/
  config                                    # → ~/.gitconfig
  ignore                                    # → ~/.config/git/ignore
zsh/
  aliases                                   # → ~/.aliases
  zshrc                                     # → ~/.zshrc
  zprofile                                  # → ~/.zprofile
  zshenv                                    # → ~/.zshenv
  zshenv.private                            # → ~/.zshenv.private (rendered)
ssh/
  config.private                            # → ~/.ssh/config (rendered)
aws/
  config.private                            # → ~/.aws/config (rendered)
vscode/
  settings.json                             # → ~/.config/Code/User/settings.json (Linux)
                                            #   ~/Library/.../settings.json (macOS)
claude/
  settings.json                             # → ~/.claude/settings.json
  statusline-command.sh                     # → ~/.claude/statusline-command.sh
dotbot/                                     # Dotbot submodule
```
