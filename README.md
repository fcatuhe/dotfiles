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
- **On install**, `decrypt-private` renders `.private` files into a `private/` folder (gitignored, chmod 700), then dotbot symlinks everything — both plain and private files
- **Platform-specific links** use dotbot's `if` guards (e.g. VS Code settings path differs on macOS vs Linux)
- **Encryption settings** (recipient, identity) are in `install.private.yaml`

## Workflow

| Task | Command |
|------|---------|
| Apply all dotfiles | `./install` |
| Edit private values | `./scripts/edit-private` then `./install` |

### Making Changes

**Plain files:** edit directly in the repo, then `./install` to re-link.

**Private values:** run `./scripts/edit-private`, then `./install` to decrypt and re-link.

### Syncing

```bash
# Push
git add -A && git commit -m "Update" && git push

# Pull on another machine
git pull && ./install
```

## Encryption

Private values (IPs, account IDs, API keys) are stored in `private.env.age` — an age-encrypted key=value file. Encryption settings are in `install.private.yaml`.

Only the `.age` file is committed. The `private/` folder and `age.key` are gitignored.

### Key Management

The age private key is stored in Bitwarden under **"dotfiles age key"**.

On a new machine:
1. Retrieve the key from Bitwarden
2. Save to `age.key` in the dotfiles repo (gitignored)
3. Run `./install`

### Editing Private Values

```bash
./scripts/edit-private    # decrypt → $EDITOR → re-encrypt
./install                 # decrypt into private/ and re-link
```

## Structure

```
install                                     # Dotbot entry point (stock script)
install.conf.yaml                           # Dotbot config (symlinks, if guards, shell hooks)
install.private.yaml                        # Age encryption settings
age.key                                     # Age identity (gitignored)
private.env.age                             # Encrypted private values (committed)
private/                                    # Decrypted private files (gitignored, chmod 700)
scripts/
  decrypt-private                           # Decrypt + render .private files into private/
  edit-private                              # Decrypt → edit → re-encrypt
git/
  config                                    # → ~/.gitconfig
  ignore                                    # → ~/.config/git/ignore
zsh/
  aliases                                   # → ~/.aliases
  zshrc                                     # → ~/.zshrc
  zprofile                                  # → ~/.zprofile
  zshenv                                    # → ~/.zshenv
  zshenv.private                            # → private/zsh/zshenv → ~/.zshenv.private
ssh/
  config.private                            # → private/ssh/config → ~/.ssh/config
aws/
  config.private                            # → private/aws/config → ~/.aws/config
vscode/
  settings.json                             # → ~/.config/Code/User/settings.json (Linux)
                                            #   ~/Library/.../settings.json (macOS)
claude/
  settings.json                             # → ~/.claude/settings.json
  statusline-command.sh                     # → ~/.claude/statusline-command.sh
dotbot/                                     # Dotbot submodule
```
