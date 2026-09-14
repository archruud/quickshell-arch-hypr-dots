#!/bin/bash
# Komplett Installasjonscript for Quickshell Overview
# For Arch Linux Hyprland
# Versjon: 1.0


# Farger for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funksjoner for pene meldinger
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Banner
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     Quickshell Overview - Installasjonscript v1.0         ║"
echo "║     For Arch Linux Hyprland                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Sjekk at vi kjører på Arch Linux
print_step "Sjekker system..."
if [ ! -f /etc/arch-release ]; then
    print_error "Dette scriptet er kun for Arch Linux!"
    exit 1
fi
print_success "Arch Linux detektert"

# Hyprland trenger ikke kjøre under installasjon
if command -v hyprctl &> /dev/null; then
    print_success "Hyprland er installert"
else
    print_warning "hyprctl ikke funnet — fortsetter likevel (Hyprland installeres av 01-base)"
fi

# Sjekk AUR helper
print_step "Sjekker AUR helper..."
AUR_HELPER=""
if command -v paru &> /dev/null; then
    AUR_HELPER="paru"
    print_success "Fant paru"
elif command -v yay &> /dev/null; then
    AUR_HELPER="yay"
    print_success "Fant yay"
else
    print_error "Ingen AUR helper funnet (paru eller yay kreves)!"
    echo ""
    echo "Installer paru:"
    echo "  sudo pacman -S --needed base-devel git"
    echo "  git clone https://aur.archlinux.org/paru.git"
    echo "  cd paru && makepkg -si"
    exit 1
fi

# Installer Qt6 dependencies
print_step "Installerer Qt6 dependencies..."
if sudo pacman -S --needed --noconfirm qt6-base qt6-declarative qt6-wayland qt6-svg qt6-5compat wayland-protocols; then
    print_success "Qt6 dependencies installert"
else
    print_error "Feil under installasjon av Qt6 dependencies"
    exit 1
fi

# Installer Quickshell fra offisielt extra repo
print_step "Installerer Quickshell (extra repo)..."
if sudo pacman -S --needed --noconfirm quickshell; then
    print_success "Quickshell installert fra extra"
else
    print_error "Feil under installasjon av Quickshell"
    exit 1
fi

# Verifiser at qs er installert
if ! command -v qs &> /dev/null; then
    print_error "qs kommando ikke funnet etter installasjon!"
    exit 1
fi
print_success "qs kommando verifisert"

# Backup eksisterende overview config hvis den finnes
print_step "Sjekker for eksisterende overview config..."
if [ -d ~/.config/quickshell/overview ]; then
    BACKUP_NAME="overview-backup-$(date +%Y%m%d-%H%M%S)"
    print_warning "Eksisterende overview funnet, lager backup..."
    mv ~/.config/quickshell/overview ~/.config/quickshell/"$BACKUP_NAME"
    print_success "Backup lagret til ~/.config/quickshell/$BACKUP_NAME"
fi

# Lag config-mappe
mkdir -p ~/.config/quickshell

# Clone quickshell-overview
print_step "Cloner quickshell-overview repository..."
if git clone https://github.com/Shanu-Kumawat/quickshell-overview ~/.config/quickshell/overview; then
    print_success "quickshell-overview clonet"
else
    print_error "Feil under cloning av repository"
    exit 1
fi

# Lag config.json med riktige innstillinger
print_step "Lager config.json for overview..."
cat > ~/.config/quickshell/overview/config.json << EOF
{
  "overview": {
    "rows": 2,
    "columns": 5,
    "scale": 0.16,
    "showSpecialWorkspaces": false,
    "emptyWorkspaceWallpaper": "$HOME/.config/hypr/wallpapers/ARCHRUUD_1920x1200.png"
  }
}
EOF
print_success "config.json opprettet — Special Workspaces av, wallpaper aktivert"

# Verifiser at config-filene er på plass
print_step "Verifiserer config-filer..."
REQUIRED_FILES=(
    "~/.config/quickshell/overview/shell.qml"
    "~/.config/quickshell/overview/common/Config.qml"
    "~/.config/quickshell/overview/common/Appearance.qml"
    "~/.config/quickshell/overview/services/HyprlandData.qml"
    "~/.config/quickshell/overview/modules/overview/Overview.qml"
)

MISSING_FILES=0
for file in "${REQUIRED_FILES[@]}"; do
    expanded_file="${file/#\~/$HOME}"
    if [ ! -f "$expanded_file" ]; then
        print_error "Mangler fil: $file"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
done

if [ $MISSING_FILES -gt 0 ]; then
    print_error "Noen config-filer mangler!"
    exit 1
fi
print_success "Alle config-filer på plass"

# Oppdater Hyprland config
print_step "Oppdaterer Hyprland config..."
HYPR_CONF=~/.config/hypr/hyprland.conf

if [ ! -f "$HYPR_CONF" ]; then
    print_error "Hyprland config ikke funnet på $HYPR_CONF"
    exit 1
fi

# Backup Hyprland config
cp "$HYPR_CONF" "$HYPR_CONF.backup-$(date +%Y%m%d-%H%M%S)"
print_success "Hyprland config backupet"

# Legg til exec-once hvis ikke allerede der
if ! grep -q "qs -c overview" "$HYPR_CONF"; then
    echo "" >> "$HYPR_CONF"
    echo "# Quickshell Overview - auto-start" >> "$HYPR_CONF"
    echo "exec-once = qs -c overview" >> "$HYPR_CONF"
    print_success "exec-once lagt til i hyprland.conf"
else
    print_warning "exec-once allerede i hyprland.conf"
fi

# Legg til keybind hvis ikke allerede der
if ! grep -q "overview toggle" "$HYPR_CONF"; then
    echo "bind = CTRL, TAB, exec, qs ipc -c overview call overview toggle" >> "$HYPR_CONF"
    print_success "Keybind (Ctrl+Tab) lagt til i hyprland.conf"
else
    print_warning "Keybind allerede i hyprland.conf"
fi

# Test at quickshell kan starte
print_step "Tester Quickshell overview..."
timeout 5 qs -c overview &
QS_PID=$!
sleep 2

if ps -p $QS_PID > /dev/null; then
    print_success "Quickshell overview starter uten feil"
    kill $QS_PID 2>/dev/null || true
else
    print_warning "Quickshell overview startet og stoppet raskt (dette kan være normalt)"
fi

# Konfigurer overview settings
print_step "Konfigurerer overview settings..."
CONFIG_FILE=~/.config/quickshell/overview/common/Config.qml

if [ -f "$CONFIG_FILE" ]; then
    # Sett hideEmptyRows til false for å alltid vise alle workspaces
    if grep -q "property bool hideEmptyRows:" "$CONFIG_FILE"; then
        # Hvis hideEmptyRows allerede eksisterer, endre verdien
        sed -i 's/property bool hideEmptyRows:.*/property bool hideEmptyRows: false  \/\/ Vis alle workspaces (også tomme)/' "$CONFIG_FILE"
        print_success "hideEmptyRows satt til false (viser alle workspaces)"
    else
        # Hvis hideEmptyRows ikke eksisterer, legg det til
        sed -i '/property bool enable:/a\    property bool hideEmptyRows: false  // Vis alle workspaces (også tomme)' "$CONFIG_FILE"
        print_success "hideEmptyRows lagt til og satt til false"
    fi
    
    # Les og vis workspace-konfigurasjon
    ROWS=$(grep "property int rows:" "$CONFIG_FILE" | grep -oP '\d+' | head -1)
    COLS=$(grep "property int columns:" "$CONFIG_FILE" | grep -oP '\d+' | head -1)
    SCALE=$(grep "property real scale:" "$CONFIG_FILE" | grep -oP '\d+\.\d+' | head -1)
    
    if [ ! -z "$ROWS" ] && [ ! -z "$COLS" ]; then
        TOTAL=$((ROWS * COLS))
        print_success "Workspace konfigurasjon: ${ROWS}x${COLS} = ${TOTAL} workspaces"
        echo "         Scale: ${SCALE:-0.16}"
        echo "         hideEmptyRows: false (viser alle workspaces)"
    fi
else
    print_error "Config fil ikke funnet: $CONFIG_FILE"
fi

# Ferdig!
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Installasjon Fullført! ✓                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Quickshell Overview er installert!"
echo ""
echo "Neste steg:"
echo "  1. Reload Hyprland:  hyprctl reload"
echo "  2. Eller logg ut og inn igjen"
echo "  3. Trykk ${GREEN}Ctrl+Tab${NC} for å toggle overview"
echo ""
echo "Tilpasning:"
echo "  • Antall workspaces: ${BLUE}~/.config/quickshell/overview/common/Config.qml${NC}"
echo "  • Farger og tema:    ${BLUE}~/.config/quickshell/overview/common/Appearance.qml${NC}"
echo ""
echo "Kommandoer:"
echo "  • Toggle overview:   ${BLUE}qs ipc -c overview call overview toggle${NC}"
echo "  • Åpne overview:     ${BLUE}qs ipc -c overview call overview open${NC}"
echo "  • Lukk overview:     ${BLUE}qs ipc -c overview call overview close${NC}"
echo ""
echo "Backup-filer:"
echo "  • Hyprland config:   ${BLUE}$HYPR_CONF.backup-*${NC}"
if [ ! -z "$BACKUP_NAME" ]; then
echo "  • Gammel overview:   ${BLUE}~/.config/quickshell/$BACKUP_NAME${NC}"
fi
echo ""
print_success "Alt er klart! God fornøyelse! 🚀"
