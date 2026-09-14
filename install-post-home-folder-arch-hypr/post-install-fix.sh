#!/bin/bash

# Post-install fix script for Arch Linux Hyprland
# Fikser: Dolphin terminal, XDG-dirs, og "open with" problem

set -e  # Stopp ved feil

echo "=== Arch Hyprland Post-Install Fixes ==="
echo ""

# Farger for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. Installer nødvendige pakker
echo -e "${BLUE}[1/4] Installerer pakker...${NC}"

# Sjekk om yay er installert
if ! command -v yay &> /dev/null; then
    echo "Installerer yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
else
    echo "yay er allerede installert"
fi

# Installer pakker
sudo pacman -S --needed --noconfirm \
    xournalpp \
    gwenview \
    xdg-user-dirs \
    archlinux-xdg-menu

echo -e "${GREEN}✓ Pakker installert${NC}"
echo ""

# 2. Fiks Dolphin Terminal (kitty som standard)
echo -e "${BLUE}[2/4] Fikser Dolphin Terminal...${NC}"

# Lag symlink
sudo ln -sf /usr/share/applications/kitty.desktop /usr/share/applications/org.kde.konsole.desktop

# Opprett/rediger kdeglobals
mkdir -p ~/.config
if [ ! -f ~/.config/kdeglobals ]; then
    echo "[General]" > ~/.config/kdeglobals
    echo "TerminalApplication=kitty" >> ~/.config/kdeglobals
else
    # Sjekk om TerminalApplication allerede finnes
    if grep -q "TerminalApplication=" ~/.config/kdeglobals; then
        sed -i 's/TerminalApplication=.*/TerminalApplication=kitty/' ~/.config/kdeglobals
    else
        # Legg til under [General] hvis det finnes
        if grep -q "\[General\]" ~/.config/kdeglobals; then
            sed -i '/\[General\]/a TerminalApplication=kitty' ~/.config/kdeglobals
        else
            echo "[General]" >> ~/.config/kdeglobals
            echo "TerminalApplication=kitty" >> ~/.config/kdeglobals
        fi
    fi
fi

echo -e "${GREEN}✓ Dolphin Terminal konfigurert${NC}"
echo ""

# 3. Opprett XDG-user-dirs
echo -e "${BLUE}[3/4] Oppretter XDG standardmapper...${NC}"
xdg-user-dirs-update
echo -e "${GREEN}✓ Standardmapper opprettet:${NC}"
xdg-user-dir DOCUMENTS
xdg-user-dir DOWNLOAD
xdg-user-dir MUSIC
xdg-user-dir PICTURES
xdg-user-dir VIDEOS
echo ""

# 4. Fiks "open with" i Dolphin
echo -e "${BLUE}[4/4] Fikser 'open with' i Dolphin...${NC}"

# Kjør kbuildsycoca6
XDG_MENU_PREFIX=arch- kbuildsycoca6 --noincremental

# Legg til env variabel i hyprland.conf
HYPR_CONF="$HOME/.config/hypr/hyprland.conf"

if [ -f "$HYPR_CONF" ]; then
    # Sjekk om env allerede finnes
    if ! grep -q "env = XDG_MENU_PREFIX,arch-" "$HYPR_CONF"; then
        echo "" >> "$HYPR_CONF"
        echo "# Fix for Dolphin 'open with'" >> "$HYPR_CONF"
        echo "env = XDG_MENU_PREFIX,arch-" >> "$HYPR_CONF"
        echo -e "${GREEN}✓ XDG_MENU_PREFIX lagt til i hyprland.conf${NC}"
    else
        echo -e "${GREEN}✓ XDG_MENU_PREFIX finnes allerede i hyprland.conf${NC}"
    fi
else
    echo -e "${GREEN}⚠ Advarsel: Fant ikke hyprland.conf på $HYPR_CONF${NC}"
    echo "Legg til manuelt: env = XDG_MENU_PREFIX,arch-"
fi

echo ""
echo -e "${GREEN}=== Alle fikser fullført! ===${NC}"
echo ""
echo "VIKTIG: Logg ut av Hyprland og logg inn igjen for at alle endringer skal tre i kraft."
echo ""
echo "Installerte programmer:"
echo "  - yay (AUR helper)"
echo "  - xournalpp (PDF annotator)"
echo "  - gwenview (bildeviser)"
