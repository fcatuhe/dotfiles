# Dotfiles

Omarchy laptop, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where.

The repo lives at mise's default `dotfiles.root` and mirrors `$HOME`, so `.config/tmux/tmux.conf` here is `~/.config/tmux/tmux.conf` there and an entry needs no `source`.

Only files that diverge from Omarchy's install templates are tracked. The rest of `~/.config/hypr/` is pristine, so tracking it would only cause conflicts on `omarchy update`.

## Apply

```bash
git clone git@github.com:fcatuhe/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
mise trust
mise bootstrap
```

`bootstrap` applies the dotfiles, then runs the `bootstrap` task, which depends on every `setup:*` task: the highlighter gets compiled and the editor extensions installed without a second command. `mise bootstrap dotfiles apply` alone is the quicker path when only a file changed.

## Shell

bash, Omarchy's own, with `shopt -s autocd` so a directory name on its own is a `cd` as it is in zsh. `~/.bashrc` sources Omarchy's `default/bash/rc` for the aliases, functions and tool init.

zsh was tried through the [omarchy-zsh](https://github.com/omacom/omarchy-zsh) package and dropped: its shared config is a build-time snapshot of [omadots](https://github.com/omacom/omadots) that lagged 4.0.1 (no `a`, `h`, `mup`), and Omarchy is tested against bash only, so features like `omarchy-cmd-terminal-cwd` break on it ([#3994](https://github.com/omacom/omarchy/issues/3994)). What zsh had that bash lacks is highlighting, which `hl` below covers.

`~/.config/shell/aliases` is what the mac's oh-my-zsh setup left behind, ported and sourced by `~/.bashrc`: the omz git plugin names, `ggl` and `ggp` for the current branch, `vsc` on codium, and the pi and utility aliases. `ga` and `gd` are left to Omarchy, whose worktree helpers own those names, so `git add` and `git diff` keep theirs. `gcm` goes the other way and checks out the main branch as on the mac, which needs the `unalias` above it: a function cannot be declared over a live alias.

`~/.local/src/bash-highlight/hl.c` paints the first word of the command line green when bash can run it, red when it cannot. It is a loadable builtin, `enable -f`, so it runs inside bash and asks bash itself through `find_alias`, `find_function`, `find_shell_builtin`, `find_reserved_word` and `find_user_command`, rather than guessing from `PATH`. Aliases and functions defined a second ago come out green.

It repaints over what readline already drew and never touches `rl_line_buffer`, whose column arithmetic would break on an escape sequence, and it leaves wrapped lines alone because a horizontal cursor move cannot reach a word on an earlier row. Cost measured against the alternatives: 8 ms of startup and no measurable memory, where ble.sh wanted 733 ms and 13.7 MB per shell. `hl off` disables it in a session. A bash upgrade needs the object rebuilt, since the loadable ABI follows the running bash, so the build lives in `~/.config/omarchy/hooks/post-update.d/bash-highlight.hook` and `omarchy update` runs it. `setup:bash-highlight` calls that same file, which is why there is one gcc line rather than two.

## Keyboard

`frenchy-clavier`, a custom AZERTY layout living in `~/.config/xkb/`, which libxkbcommon reads before the system tree so nothing has to be installed into `/usr/share/X11/xkb/`. `symbols/frenchy` has the `ansi` layout, `iso` including it and remapping the extra key, and the `digitlock` and `shiftlock` option groups. `types/frenchy` defines `FRENCHY_DIGITS_LOCK`, which puts accented letters on the digit row unshifted and the digits on shift, and `rules/evdev` wires the option names up per layout slot, with `rules/evdev.xml` describing the layout to anything that lists layouts.

`~/.config/hypr/input.lua` selects it: `kb_layout = "frenchy,us"`, variant `ansi`, Omarchy's three default options plus `frenchy:digitlock`. It is the whole Omarchy template with the one `hl.config` block uncommented, so an `omarchy update` changing the commented documentation shows up as a conflict worth reading.

The bar widget is `~/.config/omarchy/plugins/francois.keyboard-layout/`, an `omarchy plugin clone` of `omarchy.keyboard-layout` that appends `#` to the label while the digit row is locked. Hyprland raises no event for that lock, so `~/.config/hypr/bindings.lua` binds the key that moves it, Shift + Caps Lock, to `hl.dsp.event("digitlock")`, and `KeyboardLayout.qml` refreshes on that custom event. The bind is non-consuming, or the key would no longer reach the lock it is there to move, and it fires on release with the modifiers ignored: Shift is usually let go first, and xkb only settles the lock once the key is up. Hyprland dispatches the bind before feeding the key to xkb, so the widget waits 60ms before asking `hyprctl` what the lock now is. `KeyboardLayoutModel.js` is untouched from the stock widget and tracked only because a clone needs every file present. `shell.json` names the plugin, which is why both have to be tracked together.

## Secrets

Encrypted values live inline in `mise.toml` as `{ age = "..." }`, decrypted by the age identity at `~/.config/mise/age.txt`. Its recipient is `age12egydh7ye67fnykrjnqv89tdjscv6xnnssykt4yvnck4trrpzu0qvsdlkj`, one identity per machine, so a second machine gets its own and values are encrypted to both recipients rather than the key being copied around.

The identity is backed up in Bitwarden as a note named `~/.config/mise/age.txt`. On a fresh machine, unlock the desktop app, copy the note, then:

```bash
mkdir -p ~/.config/mise
(umask 077; wl-paste > ~/.config/mise/age.txt)
wl-copy --clear
age-keygen -y ~/.config/mise/age.txt   # must print the recipient above
```

Add or change a secret with `mise set --age-encrypt --prompt NAME`. It writes to `[env]`, which reaches processes mise activates. A secret rendered into a config file has to be moved to `[vars]` by hand and referenced as `{{ vars.NAME }}`, because a template's `env` namespace is the process environment, not the `[env]` section.

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
mise bootstrap dotfiles apply    # symlink everything into place
mise bootstrap dotfiles add -l ~/.config/foo/bar.toml   # track a new file, or capture a copy-mode one after editing it live
```

Run them from `~/.dotfiles`, and pass `-l` to `add` so the entry lands in `mise.toml` rather than the global config.

Symlinked files are live: editing them in the repo or in `~` is the same file. The `mode = "copy"` entries are the exception, one per app that rewrites its own config file in place, which would replace a symlink with a regular file:

- `~/.config/mimeapps.list`, rewritten by xdg-mime when a default app is set.
- `~/.config/omarchy/shell.json`, rewritten by the shell.
- `~/.config/voxtype/config.toml`, rewritten by the `voxtype configure` TUI, which also rejects a partial config.

Edit those live, then capture them back with `add -l`. `~/.ssh/config` is the other exception, a template: the `pre-dotfiles` hook chmods its source to 600, because a rendered file inherits the source's mode and git tracks only the exec bit, so a fresh clone would otherwise render it world-readable.

`~/.config/uwsm/env.d/bitwarden-ssh` points `SSH_AUTH_SOCK` at the Bitwarden desktop SSH agent. uwsm sources it once at session start, so it takes effect on next login.
