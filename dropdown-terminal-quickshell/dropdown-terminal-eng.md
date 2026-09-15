# Quickshell: dropdown-terminal

*English (primary) — [norsk versjon tilgjengelig](dropdown-terminal-no.md)*

Standalone dropdown terminal (Kitty) integrated with Quickshell and Hyprland.
The terminal hangs centered approximately **30px down from the top of the monitor** (tailored for 2560x1440), never closes automatically when hidden, and must be exited manually using `exit`.

The module is completely self-contained with all files and scripts located in:
`~/.config/quickshell/dropdown-terminal/`

---

## Features
- **Screen Positioning:** Horizontally centered at $X = 896$ px and $Y = 30$ px.
- **Dimensions:** 30% screen width (768 px) and 1/5 screen height (288 px) for 2560x1440 resolution.
- **Persistent Session:** Toggles in and out of a special workspace (`special:dropdown silent`) without killing background tasks.
- **No Window Locking:** Configured without `pin = true` so the window slides smoothly and hides without darkening regular workspaces.
- **2 Ways to Trigger:**
  1. **Keybinding:** `SHIFT + SUPER + RETURN`
  2. **Bash Alias:** `dt`

---

## 1. Installation

Run the installation script from your scripts repository:
```bash
bash install-dropdown-terminal.sh