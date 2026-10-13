# Dotfiles

The Mac, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where. The `main` branch is the Omarchy laptop, laid out the same way.

The repo lives at mise's default `dotfiles.root` and mirrors `$HOME`, so `.config/git/config` here is `~/.config/git/config` there and an entry needs no `source`.

## Apply

On a new computer, do these steps in this sequence.

1. Install [Homebrew](https://brew.sh), then mise with `brew install mise`.

2. Install Bitwarden from the App Store. Log in to the `bitwarden.eu` region. In the settings, turn on the SSH agent and Touch ID unlock.

3. Log in to the Bitwarden CLI and unlock the vault. If Bitwarden blocks the new device, use `bw login --apikey` with the personal API key (web vault, Settings, Security, Keys).

   ```bash
   mise x bitwarden -- bw config server https://vault.bitwarden.eu
   mise x bitwarden -- bw login
   export BW_SESSION=$(mise x bitwarden -- bw unlock --raw)
   ```

4. Clone the dotfiles and apply them. Use the same shell as step 3.

   ```bash
   export SSH_AUTH_SOCK=~/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
   git clone -b macos git@github.com:fcatuhe/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   mise trust
   mise x fnox bitwarden -- fnox exec -- mise bootstrap
   ```

   It refuses to replace a file already in `$HOME`, such as the `~/.zprofile` the Homebrew installer suggests. Back those up, then rerun with `--force-dotfiles`.

5. Open a new terminal, then log in to the CLIs: `gh auth login`, `/login` in pi, and `stripe login`.

### What the bootstrap does

1. Installs `[bootstrap.packages]`: the VSCodium cask.
2. Clones `[bootstrap.repos]`: oh-my-zsh and its two plugins, the `~/fcode` repositories and the Ridecell ones in `~/rcode`. It does not move a checkout that exists.
3. Applies `[dotfiles]`. The templates get their secrets from Bitwarden through fnox, see [Secrets](#secrets).
4. Writes the macOS defaults: key repeat, hot corners, Spaces kept in order, and ctrl+space freed for the terminal. Dock reads them at launch, so `killall Dock` or log out once.
5. Installs the mise tools.
6. Runs the `setup:*` tasks. `setup:repos` does `mise trust` and `mise install` in each `~/fcode` and `~/rcode` repository, not in oh-my-zsh or its plugins. `setup:vscodium` installs the extensions.

### Again, later

```bash
fnox exec -- mise bootstrap --skip-dirty        # all, but not the repositories with local changes
fnox exec -- mise bootstrap dotfiles apply      # only the files
fnox exec -- mise bootstrap --dry-run           # show the changes, do not apply them
```

## Shell

zsh, the macOS login shell, with oh-my-zsh and the `robbyrussell` theme. The plugins are `git`, `history-substring-search`, `kamal`, `macos`, `mise` for activation and completions, `vscode`, then zsh-autosuggestions and zsh-syntax-highlighting, cloned into `~/.oh-my-zsh/custom/plugins` by the bootstrap, highlighting last since it wraps every widget defined before it.

`common-aliases`, `gitfast` and `last-working-dir` are gone, as on `main`. The first aliases `rm` to `rm -i` among 48 others, the second only swaps in git's own completion, and the third sends a shell started in `~` to the last directory used, which fights herdr and Ghostty opening new panes and tabs in the directory you were in.

`~/.config/shell/aliases` holds the aliases, at the same path as on `main`. `~/.zshenv` sets `SSH_AUTH_SOCK` to the Bitwarden agent and sources `~/.zshenv.private`, rendered from Bitwarden.

Claude Code is its own native install in `~/.local/bin`, updating itself, not a mise tool.

## Secrets

Secrets live in Bitwarden, and the repo holds only references to them, so nothing secret is published, not even as ciphertext. `fnox.toml` maps each one to a field of the `dotfiles-repository` secure note, shared with `main`, as `dotfiles-repository/NAME`, and `[bootstrap.secrets]` in `mise.toml` declares the names the templates read with `{{ secret(name="NAME") }}`. `fnox exec -- mise bootstrap` reads them through the `bw` CLI, which needs `BW_SESSION` from `bw unlock --raw`, and hands them to mise as environment variables for that run only.

Every rendered file sets `permissions = "0600"`, since it would otherwise take its source's mode, and git tracks only the exec bit. `~/fcode/<project>/config/master.key`, the development credentials key of patoumatic and crooz, renders from the `<project>-repository` note's `RAILS_DEVELOPMENT_KEY`.

Without fnox, a template reading a secret fails to render, and `mise bootstrap` stops before writing anything. `mise bootstrap secrets status` lists which ones the environment holds, without printing them.

Add one by creating a hidden custom field on the `dotfiles-repository` note named after it, then a line in `fnox.toml` and one in `[bootstrap.secrets]`.

## Commands

```bash
mise bootstrap dotfiles status                          # what is out of sync
fnox exec -- mise bootstrap dotfiles apply              # symlink everything into place
mise bootstrap dotfiles add -l ~/.config/foo/bar.toml   # track a new file, or capture a copy-mode one after editing it live
```

Run them from `~/.dotfiles`, and pass `-l` to `add` so the entry lands in `mise.toml` rather than the global config.

Symlinked files are live: editing them in the repo or in `~` is the same file. `~/.config/openlogi/config.toml` is the exception, in `mode = "copy"` because openlogi rewrites it in place, which would replace a symlink. Edit it live, then capture it back with `add -l`.

## VSCodium

`~/Library/Application Support/VSCodium/User/settings.json` is a dotfile, but the layout is not a setting: pinned activity bar icons, the Accounts icon, hidden status bar items and hidden sidebar views live in VSCodium's SQLite state, `globalStorage/state.vscdb` next to it, with machine IDs and caches that do not belong in the repo. `vscodium/layout.sql` holds only those keys. After changing the layout, `mise run vscodium:dump` rewrites it from the live state, so `git diff` shows what moved. `mise run vscodium:apply` writes it back, creating the database on a machine where VSCodium never ran, and refuses while VSCodium is open, since it saves its whole state again on exit and would undo the write.
