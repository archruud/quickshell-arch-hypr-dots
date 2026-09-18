# 01 — Base System Setup

*English (primary) — [norsk versjon tilgjengelig](base-system-setup-no.md)*

## What it is

The very first script to run on a fresh Arch Linux + Hyprland install. Combines what used to be two separate steps (`01-base` + `02-post-install`) into one: package installation, then the fixes that make Dolphin/KDE apps behave correctly under Hyprland.

## What it does

**Part 1 — Packages**
- Installs `yay` (AUR helper) if missing
- Installs every package listed in `pacman-packages.txt` (system utilities, terminal, fonts, file manager, media, network, audio, browser, archiving)
- Installs every package listed in `aur-packages.txt` (zed, kate, libreoffice-fresh-nb, nmgui-bin, etc.)

**Part 2 — Post-install fixes**
1. **Dolphin terminal** — symlinks `kitty.desktop` to `org.kde.konsole.desktop` and sets `TerminalApplication=kitty` in `kdeglobals`, so Dolphin's built-in terminal opens kitty instead of konsole.
2. **XDG user folders** — regenerates `~/Desktop`, `~/Downloads` etc. under the `nb_NO.UTF-8` locale, and if a previous run already created English-named duplicates (`Downloads` alongside `Nedlastinger`), it moves the contents into the correctly-named folder and removes the empty duplicate. Never overwrites existing files. **Safety note:** explicitly guards against `xdg-user-dir` returning `$HOME` itself as a fallback when `user-dirs.dirs` doesn't exist yet (true on a completely fresh install) — without this guard, the whole home directory could be misidentified as a "duplicate" and its entire contents moved into one subfolder.
3. **"Open with" in Dolphin** — installs `archlinux-xdg-menu`, rebuilds the KDE service cache (`kbuildsycoca6 --noincremental`), and confirms `hl.env("XDG_MENU_PREFIX", "arch-")` is present in `hyprland.lua`.

If `auto-cpufreq` is among your AUR packages: its own installer explicitly states the daemon does **not** start itself. The script now runs `systemctl enable --now auto-cpufreq` automatically right after the AUR packages finish — no manual step needed.

## Settings it needs to work

- **Locale**: assumes `nb_NO.UTF-8` is generated on the system (`locale -a` must list it). If not, the script tells you to add it to `/etc/locale.gen` and run `locale-gen` first.
- **`hyprland.lua` must already exist** for step 3 to confirm the env var — if you're on a brand-new install, make sure your monitor/base config is in place first (or just ignore the warning and add the line yourself).

## Install

```bash
chmod +x install-base-system.sh
./install-base-system.sh
```

Optional interactive mode (asks before each package group):
```bash
INSTALL_MODE=interaktiv ./install-base-system.sh
```

**Important:** log completely out of Hyprland and back in afterwards (not just `hyprctl reload`) — `XDG_MENU_PREFIX` and the KDE service cache are only read at session start.

## Files in this folder

```
01-base-system/
├── install-base-system.sh
├── pacman-packages.txt
└── aur-packages.txt
```
