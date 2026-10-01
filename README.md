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

`setup:sunsetr` installs `sunsetr-bin` from the AUR through `omarchy-pkg-aur-add`, since `~/.config/hypr/autostart.lua` launches `sunsetr` and Omarchy does not ship it. The helper skips a package already present, so rerunning `bootstrap` is harmless. It asks for the sudo password.

## Shell

bash, Omarchy's own, with `shopt -s autocd` so a directory name on its own is a `cd` as it is in zsh. `~/.bashrc` sources Omarchy's `default/bash/rc` for the aliases, functions and tool init.

zsh was tried through the [omarchy-zsh](https://github.com/omacom/omarchy-zsh) package and dropped: its shared config is a build-time snapshot of [omadots](https://github.com/omacom/omadots) that lagged 4.0.1 (no `a`, `h`, `mup`), and Omarchy is tested against bash only, so features like `omarchy-cmd-terminal-cwd` break on it ([#3994](https://github.com/omacom/omarchy/issues/3994)). What zsh had that bash lacks is highlighting and history suggestions, which `line` below covers.

`~/.config/shell/aliases` is what the mac's oh-my-zsh setup left behind, ported and sourced by `~/.bashrc`: the omz git plugin names, `ggl` and `ggp` for the current branch, `vsc` on codium, and the pi and utility aliases. `ga` and `gd` are left to Omarchy, whose worktree helpers own those names, so `git add` and `git diff` keep theirs. `gcm` goes the other way and checks out the main branch as on the mac, which needs the `unalias` above it: a function cannot be declared over a live alias.

`~/.local/src/bash/line/` is a loadable builtin, `line`, that brings zsh-syntax-highlighting and zsh-autosuggestions to bash with their default looks. It is loaded with `enable -f`, so it runs inside bash and asks bash itself through `find_alias`, `find_function`, `find_shell_builtin`, `find_reserved_word` and `find_user_command`, rather than guessing from `PATH`. Aliases and functions defined a second ago come out green. `line.c` holds the builtin and the readline hooks, `highlight.c` and `suggest.c` the two features, `screen.c` the arithmetic from a byte of the line to a row and column on screen.

`highlight.c` tokenizes the line the way bash splits it, quotes, separators and redirections included, and colors every command position, not only the first word: after `|`, `&&`, `;`, `(`, reserved words like `then`, and precommands like `sudo -u root` or `env FOO=1`, whose options it skips. Commands are green, reserved words yellow, precommands and directories `autocd` would enter green underlined, anything bash cannot run bold red. Paths with a `/` are checked on disk, `~` is expanded, assignments are skipped, quoted text is yellow, existing file arguments underlined, redirections yellow and comments dark. A word holding `$`, a backtick or a glob stays uncolored, since only running it would tell what it names.

`suggest.c` shows the rest of the newest history entry starting with what is typed, in grey after the line, and keeps it there while the cursor moves back. Whatever key was bound to `forward-char` or `end-of-line` when `line on` ran takes all of it with the cursor at the end: Right, End, Ctrl-F and Ctrl-E, which move as before otherwise. Ctrl-Right, when bound to `forward-word`, takes the next word, and Alt-F stays a plain `forward-word`. As in zsh, nothing is suggested right after Up or Down. The grey is erased before readline acts on the next key, and again when the line is abandoned through Ctrl-C, because readline believes the row past the line is blank and would leave it on screen. It stops a column short of the edge rather than wrap onto a row readline does not know about, and stops at a newline in a multi-line entry, which is still taken whole.

Both rewrite over what readline already drew and never touch `rl_line_buffer`, whose column arithmetic would break on an escape sequence. A line holding a tab or another control character, which readline draws other than as typed, is left alone, as is horizontal-scroll mode. `line on` initializes readline before installing its redisplay function, since readline skips terminfo while a custom one is set and would fall back to horizontal scrolling. Cost measured against the alternatives, for the first-word highlighter this grew from: 8 ms of startup and no measurable memory, where ble.sh wanted 733 ms and 13.7 MB per shell. `line off` disables both in a session, `line highlight off` or `line suggest off` one of them. A bash upgrade needs the object rebuilt, since the loadable ABI follows the running bash, so the build lives in `~/.config/omarchy/hooks/post-update.d/bash-line.hook` and `omarchy update` runs it. `setup:bash-line` calls that same file, which is why there is one gcc line rather than two.

## Keyboard

`frenchy-clavier`, a custom AZERTY layout living in `~/.config/xkb/`, which libxkbcommon reads before the system tree so nothing has to be installed into `/usr/share/X11/xkb/`. `symbols/frenchy` has the `ansi` layout, `iso` including it and remapping the extra key, and the `digitlock` and `shiftlock` option groups. `types/frenchy` defines `FRENCHY_DIGITS_LOCK`, which puts accented letters on the digit row unshifted and the digits on shift, and `rules/evdev` wires the option names up per layout slot, with `rules/evdev.xml` describing the layout to anything that lists layouts.

`~/.config/hypr/input.lua` selects it: `kb_layout = "frenchy,us"`, variant `ansi`, Omarchy's default options plus `frenchy:digitlock`, minus `shift:both_capslock_cancel`. That option puts `Caps_Lock` on both Shift keys, and Xwayland's xkbcomp then maps Left Shift to Lock instead of Shift (`Key <LFSH> added to map for multiple modifiers`), so X11 apps lose Left Shift on digits and punctuation. `frenchy(shiftlock)`, included by the layout, gives the same both-Shift Caps Lock with `VoidSymbol` and explicit actions, so nothing is lost. It is the whole Omarchy template with the one `hl.config` block uncommented, so an `omarchy update` changing the commented documentation shows up as a conflict worth reading.

The bar widget is `~/.config/omarchy/plugins/francois.keyboard-layout/`, an `omarchy plugin clone` of `omarchy.keyboard-layout` that appends `#` to the label while the digit row is locked. Hyprland raises no event for that lock, so `~/.config/hypr/bindings.lua` binds the key that moves it, Shift + Caps Lock, to `hl.dsp.event("digitlock")`, and `KeyboardLayout.qml` refreshes on that custom event. The bind is non-consuming, or the key would no longer reach the lock it is there to move, and it fires on release with the modifiers ignored: Shift is usually let go first, and xkb only settles the lock once the key is up. Hyprland dispatches the bind before feeding the key to xkb, so the widget waits 60ms before asking `hyprctl` what the lock now is. `KeyboardLayoutModel.js` is untouched from the stock widget and tracked only because a clone needs every file present. `shell.json` names the plugin, which is why both have to be tracked together.

## Updates

`~/.config/omarchy/plugins/francois.updates/` is a bar widget for everything the stock `omarchy.system-update` icon ignores: pacman packages other than `omarchy`, AUR, mise tools and firmware. Every 6 hours `updates-pending` prints one count per source, and the widget shows their total, hidden at zero. Left click toggles the per-source counts, middle click checks again, right click opens the narrowest command that clears them: `omarchy update` for pacman or AUR, which upgrades mise too, `omarchy-update-mise` when only mise is behind, `omarchy update firmware` when only firmware is. The widget checks again once that command exits. mise is checked with its release-age cooldown off, matching how `omarchy update` runs `mise up`. Firmware is read from the local fwupd metadata without touching the network, so `setup:fwupd` installs fwupd and enables `fwupd-refresh.timer`, which downloads it daily.

## Boot

`setup:limine` sets `timeout: 1` and `quiet: yes` in `/boot/limine.conf`. The menu stays hidden, and a key pressed within that second opens it with the snapper snapshots. `timeout: 0` would skip the menu for good, and a system too broken to run `systemctl reboot --boot-loader-menu=30` is when a snapshot is needed. The file sits on the root-only vfat ESP, so it cannot be a symlink, and `omarchy-refresh-limine` copies Omarchy's template back over it: rerun `mise run setup:limine` after that.

## BIOS

`bios/thinkpad-x1-carbon-7th/` is a snapshot of the laptop's firmware state, rewritten by `mise run bios:dump` from `~/.dotfiles` after any change in F1 setup or from Linux, so `git diff` shows what moved. `settings.txt` holds every Lenovo setting the `thinklmi` driver exposes under `/sys/class/firmware-attributes/`, which needs root to read. `efibootmgr.txt` holds the UEFI boot entries without `BootCurrent` and `BootNext`, which change from boot to boot. `bios-version.txt` explains a setting appearing or vanishing after a firmware update. The folder is named after the slugged `product_version` rather than the serial, because the repo is public and the serial looks up the owner's warranty.

The snapshot records, it does not apply. A setting is changed by writing its value to `/sys/class/firmware-attributes/thinklmi/attributes/<name>/current_value` as root, and it takes effect at the next reboot. No supervisor password is set, so no password is needed for that. LUKS protects the disk, so the BIOS fingerprint logins are off too, leaving the fingerprint to sudo and the lock screen.

The changes from the factory state are for battery and for hardware this laptop lacks. `SleepState=Linux` gives S3 `deep` suspend instead of s2idle. `AlwaysOnUSB` and both Wake-on-LAN settings are off, so nothing draws power in sleep or power-off. Ethernet, the UEFI network stacks, Lenovo Cloud, AMT, NFC, the smart card slot and WWAN are off, since there is no dongle, no network boot and no such hardware. SGX is off, as the kernel created no `/dev/sgx_enclave` with it on, and libfprint does not use it despite F1 setup warning that the fingerprint reader might stop working. Absolute Persistence (Computrace) is permanently disabled, which only F1 setup can do. `AdaptiveThermalManagementAC` stays on `MaximizePerformance` and Thunderbolt security stays off, the IOMMU already blocking DMA from a device. `PreBootForThunderboltDevice=Disable` was accepted from Linux and reverted by the firmware at reboot.

The boot order is `NVMe0:USBHDD`, the only devices this laptop can boot from. In UEFI, Limine is `Boot0000` and the fwupd updater `Boot0001`, last in `BootOrder`: `limine-install` finds its entry by partition and path, fwupd by its label, so both keep their numbers. `Boot0010` and above are the firmware's own, and it marks active only the ones in the Lenovo boot order.

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
