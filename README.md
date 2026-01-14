# Dotfiles

Managed with [chezmoi](https://www.chezmoi.io/).

## Setup on a New Machine

```bash
# Install chezmoi
brew install chezmoi

# Get the age key from Bitwarden and save it
mkdir -p ~/.config/chezmoi
# Copy key from Bitwarden note "~/.config/chezmoi/key.txt" item to ~/.config/chezmoi/key.txt

# Initialize and apply
chezmoi init --apply fcatuhe
```

## Workflow

| Task | Command |
|------|---------|
| Edit a dotfile | `chezmoi edit ~/.zshrc` |
| See pending changes | `chezmoi diff` |
| Apply chezmoi → home | `chezmoi apply` |
| Pull external changes into chezmoi | `chezmoi re-add ~/.zshrc` |
| Sync from remote | `chezmoi update` |
| Add new file | `chezmoi add ~/.newfile` |

### Making Changes

**Option 1: Edit via chezmoi (recommended)**
```bash
chezmoi edit ~/.zshrc      # Opens in $EDITOR, applies on save
```

**Option 2: Edit source directly**
```bash
vim ~/fcode/dotfiles/dot_zshrc
chezmoi apply
```

**Option 3: External program modified a file**
```bash
chezmoi diff                 # See what changed
chezmoi re-add ~/.zshrc      # Pull changes INTO chezmoi
```

### Syncing

```bash
# Push changes
cd ~/fcode/dotfiles
git add -A && git commit -m "Update" && git push

# Pull on another machine
chezmoi update              # git pull + apply
```

## Encryption

Private configuration (IPs, account IDs) is stored encrypted in `.private.yaml.age` using [age](https://age-encryption.org/) encryption.

Templates reference these values:
```
{{- $private := include ".private.yaml.age" | decrypt | fromYaml -}}
{{ $private.ssh.azade_ip }}
```

### Key Management

The age private key is stored in Bitwarden under **"chezmoi age key"**.

On a new machine:
1. Retrieve the key from Bitwarden
2. Save to `~/.config/chezmoi/key.txt`
3. Run `chezmoi init --apply fcatuhe`

The public key (recipient) is in `.chezmoi.toml.tmpl` - safe to commit.

### Editing Encrypted Values

```bash
# Decrypt, edit, re-encrypt
age -d -i ~/.config/chezmoi/key.txt .private.yaml.age > /tmp/private.yaml
vim /tmp/private.yaml
age -r age1e2qkevjus09dfzmr82xppyuedlcya5283kf0u4ydsk7qgyhqgumspm36nl /tmp/private.yaml > .private.yaml.age
rm /tmp/private.yaml
```

## Structure

```
.chezmoi.toml.tmpl          # Config with age recipient
.chezmoiignore              # OS-conditional ignores
.private.yaml.age           # Encrypted private config
dot_zshrc                   # → ~/.zshrc
dot_zprofile                # → ~/.zprofile
dot_aliases                 # → ~/.aliases
dot_gitconfig               # → ~/.gitconfig
dot_aws/
  private_config.tmpl       # → ~/.aws/config
dot_config/
  git/ignore                # → ~/.config/git/ignore
  Code/User/settings.json   # → ~/.config/Code/User/settings.json (Linux)
private_Library/...         # → ~/Library/.../settings.json (macOS)
private_dot_ssh/
  private_config.tmpl       # → ~/.ssh/config (macOS only)
private_dot_claude/
  settings.json             # → ~/.claude/settings.json
  executable_statusline-command.sh
```
