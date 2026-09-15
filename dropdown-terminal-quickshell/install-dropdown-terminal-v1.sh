#!/bin/bash
# Komplett Installasjonsskript for Quickshell Dropdown Terminal
# For Arch Linux Hyprland
# Versjon: 1.3

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Quickshell Dropdown Terminal - Installasjon v1.3       ║"
echo "║     For Arch Linux Hyprland                                ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 1. Sjekk system
print_step "Sjekker system..."
if [ ! -f /etc/arch-release ]; then
    print_error "Dette scriptet er kun for Arch Linux!"
    exit 1
fi
print_success "Arch Linux detektert"

# 2. Installer nødvendige pakker med --needed
print_step "Installerer avhengigheter med --needed..."
sudo pacman -S --needed --noconfirm kitty jq

# Unngå pakkekollisjon hvis quickshell-git allerede er installert
if ! command -v qs &> /dev/null; then
    print_step "Quickshell mangler, installerer quickshell-git via yay/paru..."
    if command -v yay &> /dev/null; then
        yay -S --needed --noconfirm quickshell-git
    elif command -v paru &> /dev/null; then
        paru -S --needed --noconfirm quickshell-git
    else
        sudo pacman -S --needed --noconfirm quickshell
    fi
else
    print_success "Quickshell (qs) er allerede installert — hopper over for å unngå pakkekollisjon"
fi

# 3. Klargjør modul- og script-mappe under ~/.config/quickshell/dropdown-terminal
MODULE_DIR="$HOME/.config/quickshell/dropdown-terminal"
SCRIPTS_DIR="$MODULE_DIR/scripts"

print_step "Oppretter mappestruktur i ~/.config/quickshell/dropdown-terminal/..."
mkdir -p "$SCRIPTS_DIR"

# 4. Lag det verifiserte toggle-skriptet inni modulen
print_step "Oppretter toggle-skript i $SCRIPTS_DIR/toggle.sh..."
cat << 'EOF' > "$SCRIPTS_DIR/toggle.sh"
#!/usr/bin/env bash
CLASS="kitty-dropdown"

# 1. Start terminalen dersom den ikke kjører fra før
if ! hyprctl clients -j | jq -e ".[] | select(.class == \"$CLASS\")" > /dev/null 2>&1; then
    kitty --class "$CLASS" &
    sleep 0.15
fi

# 2. Hyprland Lua dispatch-kall for special workspace
hyprctl dispatch 'hl.dsp.workspace.toggle_special("dropdown")'
EOF

chmod +x "$SCRIPTS_DIR/toggle.sh"
print_success "Toggle-skript opprettet og gjort kjørbart"

# 5. Lag Quickshell shell.qml for modulen
print_step "Oppretter shell.qml for Quickshell..."
cat << 'EOF' > "$MODULE_DIR/shell.qml"
import Quickshell
import QtQuick

ShellRoot {
    id: root

    IpcHandler {
        target: "dropdown"

        function toggle() {
            Quickshell.process([Quickshell.env("HOME") + "/.config/quickshell/dropdown-terminal/scripts/toggle.sh"]).start()
        }
    }
}
EOF
print_success "shell.qml opprettet"

# 6. Konfigurer ~/.bashrc (Legg til alias dt)
print_step "Konfigurerer alias i ~/.bashrc..."
BASHRC="$HOME/.bashrc"
ALIAS_LINE="alias dt=\"$SCRIPTS_DIR/toggle.sh\""

if [ -f "$BASHRC" ]; then
    if ! grep -q "alias dt=" "$BASHRC"; then
        echo "" >> "$BASHRC"
        echo "# Dropdown terminal alias" >> "$BASHRC"
        echo "$ALIAS_LINE" >> "$BASHRC"
        print_success "Alias 'dt' lagt til i ~/.bashrc"
    else
        print_warning "Alias 'dt' finnes allerede i ~/.bashrc"
    fi
else
    echo "$ALIAS_LINE" > "$BASHRC"
    print_success "~/.bashrc opprettet med alias 'dt'"
fi

# 7. Sjekk Hyprland-konfigurasjon
print_step "Sjekker Hyprland-konfigurasjon..."
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

if [ -f "$HYPR_LUA" ]; then
    print_step "Fant hyprland.lua — husk å verifisere bind og windowrule (se dokumentasjon)"
elif [ -f "$HYPR_CONF" ]; then
    if ! grep -q "kitty-dropdown" "$HYPR_CONF"; then
        cp "$HYPR_CONF" "$HYPR_CONF.backup-$(date +%Y%m%d-%H%M%S)"
        cat << EOF >> "$HYPR_CONF"

# Dropdown Terminal (Kitty Quickshell-modul)
windowrulev2 = float, class:^(kitty-dropdown)$
windowrulev2 = size 768 288, class:^(kitty-dropdown)$
windowrulev2 = move 896 30, class:^(kitty-dropdown)$
windowrulev2 = workspace special:dropdown silent, class:^(kitty-dropdown)$

bind = SHIFT SUPER, RETURN, exec, $SCRIPTS_DIR/toggle.sh
EOF
        print_success "Vindusregler og bind lagt til i hyprland.conf"
    else
        print_warning "kitty-dropdown-regler finnes allerede i hyprland.conf"
    fi
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Installasjon Fullført! ✓                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Dropdown-terminal er installert i: $MODULE_DIR"
echo "Kommandoer tilgjengelig:"
echo "  • Tastesnarvei:      ${GREEN}SHIFT + SUPER + RETURN${NC}"
echo "  • Terminal-alias:    ${GREEN}dt${NC} (i nye bash-skall, eller kjør: source ~/.bashrc)"
echo "  • Direkte skript:    ${BLUE}$SCRIPTS_DIR/toggle.sh${NC}"
echo ""