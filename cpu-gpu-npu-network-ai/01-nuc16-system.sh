#!/usr/bin/env bash

set -euo pipefail

echo "===================================================="
echo " ARCHRUUD - ASUS NUC 16 PRO SYSTEM SETUP"
echo " Arch Linux + Hyprland"
echo " Intel Core Ultra Series 3"
echo "===================================================="

if [[ $EUID -eq 0 ]]; then
    echo "Kjør scriptet som vanlig bruker, IKKE med sudo."
    exit 1
fi

echo
echo ">>> Oppdaterer Arch Linux..."
sudo pacman -Syu --noconfirm

echo
echo ">>> Installerer grunnleggende systemverktøy..."

sudo pacman -S --needed --noconfirm \
    base-devel \
    git \
    curl \
    wget \
    unzip \
    zip \
    p7zip \
    rsync \
    jq \
    nano \
    vim \
    bash-completion \
    man-db \
    man-pages \
    usbutils \
    pciutils \
    dmidecode \
    hwinfo \
    lm_sensors \
    smartmontools \
    nvme-cli \
    lsof \
    strace

echo
echo ">>> Installerer Intel CPU firmware..."

sudo pacman -S --needed --noconfirm \
    intel-ucode \
    linux-firmware \
    linux-firmware-intel

echo
echo ">>> Installerer nettverk..."

sudo pacman -S --needed --noconfirm \
    networkmanager \
    network-manager-applet \
    wireless_tools \
    iw \
    wpa_supplicant \
    iproute2 \
    inetutils \
    bind \
    traceroute \
    ethtool \
    nmap \
    openssh \
    wireguard-tools

echo
echo ">>> Aktiverer NetworkManager..."

sudo systemctl enable --now NetworkManager

echo
echo ">>> Installerer Bluetooth..."

sudo pacman -S --needed --noconfirm \
    bluez \
    bluez-utils \
    blueman

sudo systemctl enable --now bluetooth

echo
echo ">>> Installerer Intel grafikk..."

sudo pacman -S --needed --noconfirm \
    mesa \
    vulkan-intel \
    vulkan-tools \
    intel-media-driver \
    libva \
    libva-utils \
    libvpl \
    libvpl-tools \
    vpl-gpu-rt

echo
echo ">>> Installerer Intel compute/OpenCL/Level Zero..."

sudo pacman -S --needed --noconfirm \
    intel-compute-runtime \
    intel-gmmlib \
    intel-graphics-compiler \
    level-zero-loader \
    level-zero-headers \
    ocl-icd \
    clinfo

echo
echo ">>> Installerer Dolphin + KDE-integrasjon..."

sudo pacman -S --needed --noconfirm \
    dolphin \
    kio \
    kio-extras \
    ffmpegthumbs \
    kdegraphics-thumbnailers \
    qt6-imageformats \
    ark \
    filelight

echo
echo ">>> Installerer Google Drive-integrasjon for Dolphin..."

sudo pacman -S --needed --noconfirm \
    kio-gdrive \
    kaccounts-integration \
    kaccounts-providers

echo
echo ">>> Installerer XDG-integrasjon..."

sudo pacman -S --needed --noconfirm \
    xdg-utils \
    xdg-user-dirs \
    xdg-desktop-portal \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk

xdg-user-dirs-update

echo
echo ">>> Oppdaterer initramfs..."

sudo mkinitcpio -P

echo
echo "===================================================="
echo " SYSTEMINSTALLASJON FERDIG"
echo "===================================================="

echo
echo "CPU:"
lscpu | grep -E "Model name|Socket|Core|Thread|CPU\(s\)" || true

echo
echo "PCI Intel:"
lspci -nn | grep -Ei "Intel|VGA|Display|Network|Ethernet" || true

echo
echo "NetworkManager:"
nmcli general status || true

echo
echo "Wi-Fi:"
nmcli device status || true

echo
echo "Grafikk:"
lspci | grep -Ei "VGA|Display" || true

echo
echo "VA-API:"
vainfo 2>/dev/null | head -30 || true

echo
echo "Vulkan:"
vulkaninfo --summary 2>/dev/null | head -50 || true

echo
echo "OpenCL:"
clinfo 2>/dev/null | head -50 || true

echo
echo "===================================================="
echo " REBOOT ANBEFALES NÅ"
echo " sudo reboot"
echo "===================================================="
