#!/usr/bin/env bash

set -euo pipefail

echo "===================================================="
echo " ARCHRUUD - ASUS NUC 16 PRO AI SETUP"
echo " Intel Core Ultra Series 3 / Panther Lake"
echo " CPU + Intel GPU + Intel NPU"
echo "===================================================="

# --------------------------------------------------
# Sikkerhet
# --------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    echo
    echo "[FEIL] Kjør scriptet som vanlig bruker, IKKE med sudo."
    exit 1
fi

CURRENT_USER="$USER"

echo
echo "Bruker: $CURRENT_USER"
echo "Kernel: $(uname -r)"

# --------------------------------------------------
# System update
# --------------------------------------------------

echo
echo ">>> Oppdaterer Arch Linux..."

sudo pacman -Syu --noconfirm

# --------------------------------------------------
# Development tools
# --------------------------------------------------

echo
echo ">>> Installerer utviklingsverktøy..."

sudo pacman -S --needed --noconfirm \
    base-devel \
    cmake \
    ninja \
    git \
    git-lfs \
    python \
    python-pip \
    python-virtualenv \
    python-numpy \
    python-pillow \
    python-opencv

# --------------------------------------------------
# Intel GPU
# --------------------------------------------------

echo
echo ">>> Installerer Intel GPU compute..."

sudo pacman -S --needed --noconfirm \
    intel-compute-runtime \
    intel-gmmlib \
    intel-graphics-compiler \
    level-zero-loader \
    level-zero-headers \
    ocl-icd \
    clinfo \
    vulkan-intel \
    vulkan-tools

# --------------------------------------------------
# Intel NPU
# --------------------------------------------------

echo
echo ">>> Installerer Intel NPU runtime/compiler..."

sudo pacman -S --needed --noconfirm \
    intel-npu-driver \
    intel-npu-compiler

# --------------------------------------------------
# OpenVINO
# --------------------------------------------------

echo
echo ">>> Installerer OpenVINO..."

sudo pacman -S --needed --noconfirm \
    openvino \
    openvino-intel-gpu-plugin \
    openvino-intel-npu-plugin \
    python-openvino

# --------------------------------------------------
# Permissions
# --------------------------------------------------

echo
echo ">>> Kontrollerer GPU/NPU brukerrettigheter..."

NEED_REBOOT=0

if ! id -nG "$CURRENT_USER" | grep -qw render; then
    echo "Legger $CURRENT_USER til gruppen render..."
    sudo usermod -aG render "$CURRENT_USER"
    NEED_REBOOT=1
else
    echo "[OK] $CURRENT_USER er medlem av render."
fi

if ! id -nG "$CURRENT_USER" | grep -qw video; then
    echo "Legger $CURRENT_USER til gruppen video..."
    sudo usermod -aG video "$CURRENT_USER"
    NEED_REBOOT=1
else
    echo "[OK] $CURRENT_USER er medlem av video."
fi

# --------------------------------------------------
# NPU kernel driver
# Panther Lake / Core Ultra Series 3 uses intel_vpu
# --------------------------------------------------

echo
echo ">>> Kontrollerer Intel NPU kernel driver..."

if lsmod | grep -q '^intel_vpu'; then
    echo "[OK] intel_vpu er lastet."
else
    echo "Forsøker å laste intel_vpu..."

    if sudo modprobe intel_vpu; then
        echo "[OK] intel_vpu ble lastet."
    else
        echo "[WARN] intel_vpu kunne ikke lastes."
    fi
fi

# --------------------------------------------------
# NPU PCI device
# --------------------------------------------------

echo
echo ">>> Kontrollerer NPU hardware..."

NPU_PCI="$(lspci -nn | grep -Ei 'Processing accelerators|NPU|VPU' || true)"

if [[ -n "$NPU_PCI" ]]; then
    echo "[OK] NPU funnet:"
    echo "$NPU_PCI"
else
    echo "[WARN] Fant ingen NPU med lspci."
fi

# --------------------------------------------------
# /dev/accel
# --------------------------------------------------

echo
echo ">>> Kontrollerer NPU device..."

if [[ -e /dev/accel/accel0 ]]; then
    echo "[OK] /dev/accel/accel0 finnes."
    ls -l /dev/accel/accel0
else
    echo "[WARN] /dev/accel/accel0 finnes ikke."
fi

# --------------------------------------------------
# Intel GPU DRM
# --------------------------------------------------

echo
echo ">>> Kontrollerer Intel GPU devices..."

if [[ -d /dev/dri ]]; then
    ls -la /dev/dri
else
    echo "[WARN] /dev/dri finnes ikke."
fi

# --------------------------------------------------
# OpenCL
# --------------------------------------------------

echo
echo ">>> OpenCL devices..."

clinfo 2>/dev/null | grep -E \
    "Platform Name|Device Name|Device Type|Device Vendor" \
    | head -40 || true

# --------------------------------------------------
# Vulkan
# --------------------------------------------------

echo
echo ">>> Vulkan GPU..."

vulkaninfo --summary 2>/dev/null | grep -E \
    "deviceName|deviceType|driverName|driverInfo|apiVersion" \
    | head -30 || true

# --------------------------------------------------
# Hardware information
# --------------------------------------------------

echo
echo "===================================================="
echo " HARDWARE"
echo "===================================================="

echo
echo "--- CPU ---"

lscpu | grep -E \
    "Model name|CPU\(s\)|Core|Thread|Socket" || true

echo
echo "--- GPU ---"

lspci | grep -Ei \
    "VGA|Display|Graphics" || true

echo
echo "--- NPU ---"

lspci -nnk | grep -A4 -Ei \
    "Processing accelerators|NPU|VPU" || true

echo
echo "--- Kernel ---"

uname -a

echo
echo "--- Intel NPU driver ---"

if lsmod | grep -q '^intel_vpu'; then
    echo "[OK] intel_vpu loaded"
else
    echo "[WARN] intel_vpu not loaded"
fi

# --------------------------------------------------
# OpenVINO test
# --------------------------------------------------

echo
echo "===================================================="
echo " OPENVINO AI TEST"
echo "===================================================="

# Nye gruppemedlemskap gjelder ikke før ny login/reboot.
# Derfor hopper vi over endelig NPU-test dersom grupper ble endret.

if [[ "$NEED_REBOOT" -eq 1 ]]; then

    echo
    echo "[INFO] Brukerrettigheter ble endret."
    echo
    echo "OpenVINO-testen kjøres etter reboot."
    echo

else

    python -c '
import openvino as ov

core = ov.Core()

print()
print("OpenVINO version:")
print(ov.__version__)

print()
print("Available devices:")

devices = core.available_devices

for device in devices:
    print("  ->", device)

print()

print("[OK] CPU" if "CPU" in devices else "[WARN] CPU mangler")

gpu = any(d.startswith("GPU") for d in devices)
print("[OK] GPU" if gpu else "[WARN] GPU mangler")

npu = any(d.startswith("NPU") for d in devices)
print("[OK] NPU" if npu else "[WARN] NPU mangler")
'

fi

# --------------------------------------------------
# Final status
# --------------------------------------------------

echo
echo "===================================================="
echo " ARCHRUUD NUC 16 PRO AI SETUP FERDIG"
echo "===================================================="

if [[ "$NEED_REBOOT" -eq 1 ]]; then

    echo
    echo "VIKTIG:"
    echo
    echo "$CURRENT_USER ble lagt til i render/video."
    echo "Ny gruppetilgang gjelder først etter ny innlogging."
    echo
    echo "Kjør:"
    echo
    echo "    sudo reboot"
    echo
    echo "Etter reboot:"
    echo
    echo "    groups"
    echo
    echo "og:"
    echo
    echo "    python -c 'import openvino as ov; c=ov.Core(); print(c.available_devices)'"
    echo

else

    echo
    echo "Ingen reboot nødvendig på grunn av gruppeendringer."
    echo
    echo "Målet er:"
    echo
    echo "    CPU  [OK]"
    echo "    GPU  [OK]"
    echo "    NPU  [OK]"
    echo

fi

echo "===================================================="
