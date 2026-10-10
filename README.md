# Dotfiles

Omarchy laptop, symlinked by [mise](https://mise.jdx.dev/) `[dotfiles]`. See `mise.toml` for what maps where.

The repo lives at mise's default `dotfiles.root` and mirrors `$HOME`, so `.config/tmux/tmux.conf` here is `~/.config/tmux/tmux.conf` there and an entry needs no `source`.

Only files that diverge from Omarchy's install templates are tracked. The rest of `~/.config/hypr/` is pristine, so tracking it would only cause conflicts on `omarchy update`.

## Apply

On a new computer, do these steps in this sequence.

1. Install Bitwarden.

   ```bash
   omarchy-pkg-add bitwarden bitwarden-cli
   ```

2. Open the Bitwarden app. Log in to the `bitwarden.eu` region. In the settings, turn on the SSH agent and "Unlock with system authentication".

3. Log in to the Bitwarden CLI and unlock the vault. If Bitwarden blocks the new device, use `bw login --apikey` with the personal API key (web vault, Settings, Security, Keys).

   ```bash
   bw config server https://vault.bitwarden.eu
   bw login
   export BW_SESSION=$(bw unlock --raw)
   ```

4. Clone the dotfiles and apply them. Use the same shell as step 3.

   ```bash
   export SSH_AUTH_SOCK=~/.bitwarden-ssh-agent.sock
   git clone git@github.com:fcatuhe/dotfiles.git ~/.dotfiles
   cd ~/.dotfiles
   mise trust
   mise x fnox -- fnox exec -- mise bootstrap
   ```

5. Log out. Log in again.

6. Log in to the CLIs.

   ```bash
   gh auth login
   hey auth login
   ol auth login
   ```

   In pi, type `/login`. To receive Stripe webhooks in patoumatic, do `stripe login --project-name development`. Log in to the sites in the agent-browser Chrome profile.

### What the bootstrap does

It does these steps in this sequence:

1. Installs `[bootstrap.packages]`, with sudo. The AUR packages use yay with `--noconfirm`, so read their PKGBUILD on aur.archlinux.org before the first install.
2. Enables `[bootstrap.services]`.
3. Clones `[bootstrap.repos]`: oh-my-zsh, and crooz, patoumatic, pi-wares and skyblip in `~/fcode`. It does not move a checkout that exists.
4. Applies `[dotfiles]`. The templates get their secrets from Bitwarden through fnox, see [Secrets](#secrets).
5. Installs the mise tools.
6. Runs the `setup:*` tasks. `setup:repos` does `mise trust` and `mise install` in each repository.

The repositories must exist before the dotfiles, because the dotfiles write `config/master.key` into crooz and patoumatic.

### Again, later

```bash
fnox exec -- mise bootstrap --skip-dirty        # all, but not the repositories with local changes
fnox exec -- mise bootstrap dotfiles apply      # only the files
fnox exec -- mise bootstrap --dry-run           # show the changes, do not apply them
```

## Shell

zsh inside herdr, bash everywhere else. `default_shell` in `~/.config/herdr/config.toml` starts zsh in every herdr pane, while the login shell, Alacritty outside herdr and Omarchy's scripts stay on bash: every `omarchy-*` command carries its own `#!/bin/bash` or Python shebang, so the shell typed in never runs them.

`~/.zshrc` is oh-my-zsh with its defaults, the `robbyrussell` theme and the `git` plugin, plus `mise` for activation and completions, `vscode`, whose `vsc` opens VSCodium when it is the only flavour installed, `kamal`, which prefers a project's `./bin/kamal`, and `history-substring-search`, which makes Up and Down match the typed text anywhere in a history entry rather than only at its start. The Mac setup also had `common-aliases`, `gitfast` and `last-working-dir`, dropped: the first aliases `rm` to `rm -i` among 48 others, the second only swaps in git's own completion, and the third would move a new pane that herdr opened in `~` to the last directory used. zsh-autosuggestions and zsh-syntax-highlighting come from pacman and are sourced after oh-my-zsh, highlighting last since it wraps every widget defined before it. The bootstrap installs the three packages and clones oh-my-zsh into `~/.oh-my-zsh`, where its own updater keeps it current. It asks for the sudo password.

None of Omarchy's bash config reaches zsh: no starship, no zoxide, and none of its aliases and functions, the herdr and worktree helpers included. zsh was tried before through the [omarchy-zsh](https://github.com/omacom/omarchy-zsh) package and dropped, because its shared config is a build-time snapshot of [omadots](https://github.com/omacom/omadots) that lagged 4.0.1 (no `a`, `h`, `mup`), and Omarchy is tested against bash only, so features like `omarchy-cmd-terminal-cwd` break on it ([#3994](https://github.com/omacom/omarchy/issues/3994)). Keeping zsh to herdr keeps those features on bash.

bash is Omarchy's own, with `shopt -s autocd` so a directory name on its own is a `cd` as it is in zsh. `~/.bashrc` sources Omarchy's `default/bash/rc` for the aliases, functions and tool init.

`~/.config/shell/aliases` is what the mac's oh-my-zsh setup added on top of the plugins, sourced by both shells: `gs` for `git sweep`, and the pi and utility aliases. Environment variables live in `~/.config/uwsm/env.d/` instead, see Commands. The omz git and vscode names exist in zsh only, so bash keeps Omarchy's own `g`, `gcm`, `ga` and `gd`.

## Keyboard

`frenchy-clavier`, a custom AZERTY layout living in `~/.config/xkb/`, which libxkbcommon reads before the system tree so nothing has to be installed into `/usr/share/X11/xkb/`. `symbols/frenchy` has the `ansi` layout, `iso` including it and remapping the extra key, and the `digitlock` and `shiftlock` option groups. `types/frenchy` defines `FRENCHY_DIGITS_LOCK`, which puts accented letters on the digit row unshifted and the digits on shift, and `rules/evdev` wires the option names up per layout slot, with `rules/evdev.xml` describing the layout to anything that lists layouts.

`~/.config/hypr/input.lua` selects it: `kb_layout = "frenchy,us"`, variant `ansi`, Omarchy's default options plus `frenchy:digitlock`, minus `shift:both_capslock_cancel`. That option puts `Caps_Lock` on both Shift keys, and Xwayland's xkbcomp then maps Left Shift to Lock instead of Shift (`Key <LFSH> added to map for multiple modifiers`), so X11 apps lose Left Shift on digits and punctuation. `frenchy(shiftlock)`, included by the layout, gives the same both-Shift Caps Lock with `VoidSymbol` and explicit actions, so nothing is lost. It is the whole Omarchy template with the one `hl.config` block uncommented, so an `omarchy update` changing the commented documentation shows up as a conflict worth reading.

The bar widget is `~/.config/omarchy/plugins/francois.keyboard-layout/`, an `omarchy plugin clone` of `omarchy.keyboard-layout` that appends `#` to the label while the digit row is locked. Hyprland raises no event for that lock, so `~/.config/hypr/bindings.lua` binds the key that moves it, Shift + Caps Lock, to `hl.dsp.event("digitlock")`, and `KeyboardLayout.qml` refreshes on that custom event. The bind is non-consuming, or the key would no longer reach the lock it is there to move, and it fires on release with the modifiers ignored: Shift is usually let go first, and xkb only settles the lock once the key is up. Hyprland dispatches the bind before feeding the key to xkb, but in the same handler, and answers `hyprctl` on that same thread afterwards, so the widget can ask straight away.

Hyprland keeps the layout and the locks per device, and lists the headphone jack and the ThinkPad hotkeys as keyboards too, so the widget has to pick which one to describe. The stock widget guesses from the last `activelayout` event and falls back to the first device listed, which froze the `#` whenever that landed on the jack: after a shell restart, on a new monitor's bar, or when a device was re-added. `follow` in `KeyboardLayoutModel.js` compares each reading with the previous one and describes the device whose layout or lock moved, which only a keyboard being typed on does, so no name list is needed and a Bluetooth or USB keyboard is picked up the first time it switches or locks. Every refresh comes from an event, nothing polls. A click sets every device to the next layout, so they agree whichever one is read. The tests run in the shell's own JavaScript engine, which lacks newer builtins node has such as `Object.fromEntries`, with `QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tst_KeyboardLayoutModel.qml` in the plugin directory, and are not linked into `~/.config`. `shell.json` names the plugin, which is why both have to be tracked together.

## Updates

`~/.config/omarchy/plugins/francois.updates/` is a bar widget for everything the stock `omarchy.system-update` icon ignores: pacman packages other than `omarchy`, AUR, mise tools and firmware. Every 6 hours `updates-pending` prints one count per source, and the widget shows their total, hidden at zero. The check runs once in the plugin's service and every screen's widget reads it, so the bars never run `checkupdates` against each other. A failed check shows `!` in the urgent color, with the error in the tooltip. Left click toggles the per-source counts, middle click checks again, right click opens the narrowest command that clears them: `omarchy update` for pacman or AUR, which upgrades mise too, `omarchy-update-mise` when only mise is behind, `omarchy update firmware` when only firmware is. The widget checks again once that command exits. mise is checked with its release-age cooldown off, matching how `omarchy update` runs `mise up`. Firmware is read from the local fwupd metadata without touching the network, so the bootstrap installs fwupd and enables `fwupd-refresh.timer`, which downloads it daily.

## VSCodium

`~/.config/VSCodium/User/settings.json` is a dotfile, but the layout is not a setting: pinned activity bar icons, the Accounts icon, hidden status bar items and hidden sidebar views live in VSCodium's SQLite state, `~/.config/VSCodium/User/globalStorage/state.vscdb`, next to machine IDs and caches that do not belong in the repo. `vscodium/layout.sql` holds only those keys. After changing the layout, `mise run vscodium:dump` rewrites it from the live state, so `git diff` shows what moved. `mise run vscodium:apply` writes it back, creating the database on a machine where VSCodium never ran, and refuses while VSCodium is open, since it saves its whole state again on exit and would undo the write. Per-project state, like which sidebar sections are collapsed, stays in each workspace's own database and is not tracked.

## Boot

`setup:limine` sets `timeout: 1` and `quiet: yes` in `/boot/limine.conf`. The menu stays hidden, and holding Down from power-on opens it with the snapper snapshots. Limine's countdown runs about twice as fast as the clock here, too short to aim at, and Space, Enter and Right would boot the highlighted entry where an arrow only moves the selection. `timeout: 0` would skip the menu for good, and a system too broken to run `systemctl reboot --boot-loader-menu=30` is when a snapshot is needed. The file sits on the root-only vfat ESP, so it cannot be a symlink, and `omarchy-refresh-limine` copies Omarchy's template back over it: rerun `mise run setup:limine` after that.

## Power

`setup:power-profile` keeps the balanced power profile on AC, where Omarchy defaults to performance. Battery already defaults to balanced. `omarchy-powerprofiles-set ac balanced` saves the choice to `~/.local/state/omarchy/powerprofiles/ac`, and the shell reapplies it whenever the power source changes. The file is state that the power menu rewrites, so it is set by the task rather than tracked. Plugged and unplugged still differ in two ways: power-profiles-daemon's battery-aware mode makes balanced write `balance_performance` as the CPU energy preference on AC and `balance_power` on battery, and the BIOS runs `AdaptiveThermalManagementAC=MaximizePerformance` against `Balanced` on battery.

## BIOS

`bios/thinkpad-x1-carbon-7th/` is a snapshot of the laptop's firmware state, rewritten by `mise run bios:dump` from `~/.dotfiles` after any change in F1 setup or from Linux, so `git diff` shows what moved. `settings.txt` holds every Lenovo setting the `thinklmi` driver exposes under `/sys/class/firmware-attributes/`, which needs root to read. `efibootmgr.txt` holds the UEFI boot entries without `BootCurrent` and `BootNext`, which change from boot to boot. `bios-version.txt` explains a setting appearing or vanishing after a firmware update. The folder is named after the slugged `product_version` rather than the serial, because the repo is public and the serial looks up the owner's warranty.

`settings.txt` is also the desired state. Edit a value, run `mise run bios:apply`, reboot, and `bios:dump` should leave no diff. The task writes only the values that differ from the firmware's, to `/sys/class/firmware-attributes/thinklmi/attributes/<name>/current_value`, and stops at the first one refused, so a wrong password cannot reach the three attempts that trigger POST error 0199. It asks for the supervisor password, hands it to the driver through the write-only `current_password`, and clears it on exit, as any root process could otherwise change settings until reboot. LUKS protects the disk, so the BIOS fingerprint logins are off too, leaving the fingerprint to sudo and the lock screen.

The changes from the factory state are for battery and for hardware this laptop lacks. `SleepState=Linux` gives S3 `deep` suspend instead of s2idle. `AlwaysOnUSB` and both Wake-on-LAN settings are off, so nothing draws power in sleep or power-off. Ethernet, the UEFI network stacks, Lenovo Cloud, AMT, NFC, the smart card slot and WWAN are off, since there is no dongle, no network boot and no such hardware. SGX is off, as the kernel created no `/dev/sgx_enclave` with it on, and libfprint does not use it despite F1 setup warning that the fingerprint reader might stop working. Absolute Persistence (Computrace) is permanently disabled, which only F1 setup can do. `AdaptiveThermalManagementAC` stays on `MaximizePerformance` and Thunderbolt security stays off, the IOMMU already blocking DMA from a device. `PreBootForThunderboltDevice=Disable` was accepted from Linux and reverted by the firmware at reboot, F1 setup offering only `Enable` and `Pre-BootACL`, and the security level cannot be changed there.

The boot order is `NVMe0:USBHDD`, the only devices this laptop can boot from. In UEFI, Limine is `Boot0000` and the fwupd updater `Boot0001`, last in `BootOrder`: `limine-install` finds its entry by partition and path, fwupd by its label, so both keep their numbers. `Boot0010` and above are the firmware's own, and it marks active only the ones in the Lenovo boot order.

## Secrets

Secrets live in Bitwarden, and the repo holds only references to them, so nothing secret is published, not even as ciphertext. `fnox.toml` maps each one to a field of the `dotfiles-repository` secure note, as `dotfiles-repository/NAME`, and `[bootstrap.secrets]` in `mise.toml` declares the names the templates read with `{{ secret(name="NAME") }}`. `fnox exec -- mise bootstrap` reads them through the `bw` CLI, which needs `BW_SESSION` from `bw unlock --raw`, and hands them to mise as environment variables for that run only.

A project file that must sit at a fixed path goes the same way: `~/fcode/<project>/config/master.key`, the development credentials key of patoumatic and crooz, renders from `fcode/<project>/config/master.key.tmpl` with the `<project>-repository` note's `RAILS_DEVELOPMENT_KEY`. Its entry sets `permissions = "0600"`, since a rendered file would otherwise take its source's mode, and git tracks only the exec bit. The project has to be cloned first, or the entry creates `~/fcode/<project>/config/` and the clone then refuses a non-empty directory.

Without fnox, a template reading a secret fails to render, and `mise bootstrap` stops before writing anything, so a missing secret never leaves a half-written file. `mise bootstrap secrets status` lists which ones the environment holds, without printing them.

Add one by creating a hidden custom field on the `dotfiles-repository` note named after it, then a line in `fnox.toml` and one in `[bootstrap.secrets]`. fnox splits a reference at its first `/` into item and field, so an item name cannot hold one, and `bw` finds an item by searching names, usernames and URLs, so the name must match a single item.

## Commands

```bash
mise bootstrap dotfiles status   # what is out of sync
fnox exec -- mise bootstrap dotfiles apply    # symlink everything into place
mise bootstrap dotfiles add -l ~/.config/foo/bar.toml   # track a new file, or capture a copy-mode one after editing it live
```

Run them from `~/.dotfiles`, and pass `-l` to `add` so the entry lands in `mise.toml` rather than the global config.

Symlinked files are live: editing them in the repo or in `~` is the same file. The `mode = "copy"` entries are the exception, one per app that rewrites its own config file in place, which would replace a symlink with a regular file:

- `~/.config/mimeapps.list`, rewritten by xdg-mime when a default app is set.
- `~/.config/omarchy/shell.json`, rewritten by the shell.
- `~/.config/voxtype/config.toml`, rewritten by the `voxtype configure` TUI, which also rejects a partial config.

Edit those live, then capture them back with `add -l`. `~/.ssh/config` is the other exception, a template with `permissions = "0600"`, because a rendered file otherwise inherits the source's mode and git tracks only the exec bit, so a fresh clone would render it world-readable.

`~/.config/uwsm/env.d/` holds the session environment, which every app and both shells inherit: uwsm sources these files once at session start, after Omarchy's own defaults, so a change takes effect on next login. `bitwarden-ssh` points `SSH_AUTH_SOCK` at the Bitwarden desktop SSH agent. `editor` sets `EDITOR` and `BUNDLER_EDITOR` to `codium --wait` when VSCodium is installed, and leaves Omarchy's `omarchy-launch-editor` in place otherwise, since an editor that is not there would break `git commit`. `console1984` sets `CONSOLE_USER`, which the console1984 gem asks for at a Rails console, and `npm` silences npm's funding notice.
