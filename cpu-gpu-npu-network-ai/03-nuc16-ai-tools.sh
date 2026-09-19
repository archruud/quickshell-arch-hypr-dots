#!/usr/bin/env bash

set -euo pipefail

echo "===================================================="
echo " ARCHRUUD - ASUS NUC 16 PRO AI TOOLS"
echo " Intel Core Ultra 7 356H / Panther Lake"
echo " CPU + Xe3 GPU + NPU"
echo "===================================================="

if [[ $EUID -eq 0 ]]; then
    echo
    echo "[FEIL] Kjør scriptet som vanlig bruker."
    echo "IKKE bruk sudo foran scriptet."
    exit 1
fi

CURRENT_USER="$USER"

echo
echo "Bruker : $CURRENT_USER"
echo "Kernel : $(uname -r)"

# --------------------------------------------------
# System update
# --------------------------------------------------

echo
echo ">>> Oppdaterer Arch Linux..."

sudo pacman -Syu --noconfirm

# --------------------------------------------------
# Development / build tools
# --------------------------------------------------

echo
echo ">>> Installerer utviklingsverktøy..."

sudo pacman -S --needed --noconfirm \
    base-devel \
    git \
    git-lfs \
    cmake \
    ninja \
    pkgconf \
    python \
    python-pip \
    python-virtualenv \
    python-numpy \
    jq \
    curl \
    wget \
    unzip \
    p7zip

# --------------------------------------------------
# Hugging Face
# --------------------------------------------------

echo
echo ">>> Installerer Hugging Face-verktøy..."

sudo pacman -S --needed --noconfirm \
    python-huggingface-hub

# --------------------------------------------------
# ONNX
# --------------------------------------------------

echo
echo ">>> Installerer ONNX..."

sudo pacman -S --needed --noconfirm \
    onnx \
    python-onnx

# --------------------------------------------------
# llama.cpp
# --------------------------------------------------

echo
echo ">>> Installerer llama.cpp..."

sudo pacman -S --needed --noconfirm \
    llama-cpp

# --------------------------------------------------
# GGML backends
# --------------------------------------------------

echo
echo ">>> Installerer GGML Intel backends..."

sudo pacman -S --needed --noconfirm \
    ggml-openvino \
    ggml-vulkan

# --------------------------------------------------
# Vulkan development support
# --------------------------------------------------

echo
echo ">>> Installerer Vulkan AI/build-verktøy..."

sudo pacman -S --needed --noconfirm \
    vulkan-headers \
    vulkan-validation-layers \
    shaderc \
    spirv-tools

# --------------------------------------------------
# AI directories
# --------------------------------------------------

echo
echo ">>> Oppretter AI-kataloger..."

mkdir -p "$HOME/AI"
mkdir -p "$HOME/AI/models"
mkdir -p "$HOME/AI/huggingface"
mkdir -p "$HOME/AI/llama"
mkdir -p "$HOME/AI/openvino"
mkdir -p "$HOME/AI/tests"

echo
echo "[OK] $HOME/AI"
echo "[OK] $HOME/AI/models"
echo "[OK] $HOME/AI/huggingface"
echo "[OK] $HOME/AI/llama"
echo "[OK] $HOME/AI/openvino"
echo "[OK] $HOME/AI/tests"

# --------------------------------------------------
# Hugging Face cache
# --------------------------------------------------

echo
echo ">>> Setter Hugging Face modellkatalog..."

mkdir -p "$HOME/AI/huggingface"

# Legg bare til dersom den ikke finnes fra før.

if ! grep -q 'HF_HOME=.*AI/huggingface' "$HOME/.bashrc" 2>/dev/null; then
    echo '' >> "$HOME/.bashrc"
    echo '# ARCHRUUD AI - Hugging Face model cache' >> "$HOME/.bashrc"
    echo 'export HF_HOME="$HOME/AI/huggingface"' >> "$HOME/.bashrc"
fi

export HF_HOME="$HOME/AI/huggingface"

echo "[OK] HF_HOME=$HF_HOME"

# --------------------------------------------------
# Permissions
# --------------------------------------------------

echo
echo ">>> Kontrollerer GPU/NPU-rettigheter..."

NEED_REBOOT=0

if id -nG "$CURRENT_USER" | grep -qw render; then
    echo "[OK] render"
else
    echo "[WARN] Legger $CURRENT_USER til render..."
    sudo usermod -aG render "$CURRENT_USER"
    NEED_REBOOT=1
fi

if id -nG "$CURRENT_USER" | grep -qw video; then
    echo "[OK] video"
else
    echo "[WARN] Legger $CURRENT_USER til video..."
    sudo usermod -aG video "$CURRENT_USER"
    NEED_REBOOT=1
fi

# --------------------------------------------------
# Hardware
# --------------------------------------------------

echo
echo "===================================================="
echo " HARDWARE CHECK"
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

# --------------------------------------------------
# NPU driver
# --------------------------------------------------

echo
echo "--- Intel NPU driver ---"

if grep -q '^intel_vpu ' /proc/modules; then
    echo "[OK] intel_vpu loaded"
else
    echo "[WARN] intel_vpu not loaded"
fi

# --------------------------------------------------
# Accelerator
# --------------------------------------------------

echo
echo "--- NPU device ---"

if [[ -e /dev/accel/accel0 ]]; then
    echo "[OK] /dev/accel/accel0"
    ls -l /dev/accel/accel0
else
    echo "[WARN] /dev/accel/accel0 mangler"
fi

# --------------------------------------------------
# Vulkan
# --------------------------------------------------

echo
echo "===================================================="
echo " VULKAN TEST"
echo "===================================================="

if command -v vulkaninfo >/dev/null 2>&1; then

    vulkaninfo --summary 2>/dev/null | grep -E \
        "deviceName|deviceType|driverName|driverInfo" \
        | head -20 || true

else

    echo "[WARN] vulkaninfo ikke funnet."

fi

# --------------------------------------------------
# OpenCL
# --------------------------------------------------

echo
echo "===================================================="
echo " OPENCL TEST"
echo "===================================================="

if command -v clinfo >/dev/null 2>&1; then

    clinfo 2>/dev/null | grep -E \
        "Platform Name|Device Name|Device Type" \
        | head -20 || true

else

    echo "[WARN] clinfo ikke funnet."
fi

# --------------------------------------------------
# OpenVINO
# --------------------------------------------------

echo
echo "===================================================="
echo " OPENVINO TEST"
echo "===================================================="

python -c '
import openvino as ov

core = ov.Core()
devices = core.available_devices

print("OpenVINO:", ov.__version__)
print()

for device in devices:
    print("Device:", device)

print()

print("[OK] CPU" if "CPU" in devices else "[WARN] CPU")

gpu = any(x.startswith("GPU") for x in devices)
print("[OK] GPU" if gpu else "[WARN] GPU")

npu = any(x.startswith("NPU") for x in devices)
print("[OK] NPU" if npu else "[WARN] NPU")
'

# --------------------------------------------------
# llama.cpp
# --------------------------------------------------

echo
echo "===================================================="
echo " LLAMA.CPP TEST"
echo "===================================================="

if command -v llama-cli >/dev/null 2>&1; then

    echo "[OK] llama-cli"
    llama-cli --version || true

else

    echo "[WARN] llama-cli ikke funnet."

fi

if command -v llama-server >/dev/null 2>&1; then

    echo "[OK] llama-server"

else

    echo "[WARN] llama-server ikke funnet."

fi

# --------------------------------------------------
# Check installed GGML backends
# --------------------------------------------------

echo
echo "===================================================="
echo " GGML BACKENDS"
echo "===================================================="

pacman -Q \
    ggml-openvino \
    ggml-vulkan \
    2>/dev/null || true

# --------------------------------------------------
# Hugging Face
# --------------------------------------------------

echo
echo "===================================================="
echo " HUGGING FACE"
echo "===================================================="

if command -v hf >/dev/null 2>&1; then

    echo "[OK] Hugging Face CLI"
    hf --version || true

elif command -v huggingface-cli >/dev/null 2>&1; then

    echo "[OK] Hugging Face CLI"
    huggingface-cli --version || true

else

    echo "[INFO] Hugging Face Python library installert."
fi

# --------------------------------------------------
# Final
# --------------------------------------------------

echo
echo "===================================================="
echo " ARCHRUUD AI TOOLS INSTALLASJON FERDIG"
echo "===================================================="

echo
echo "Installert:"
echo
echo "  llama.cpp"
echo "  GGML OpenVINO backend"
echo "  GGML Vulkan backend"
echo "  Hugging Face tools"
echo "  ONNX"
echo "  Vulkan development tools"
echo
echo "AI katalog:"
echo
echo "  $HOME/AI"
echo
echo "Modeller:"
echo
echo "  $HOME/AI/models"
echo
echo "Hugging Face cache:"
echo
echo "  $HOME/AI/huggingface"
echo

if [[ "$NEED_REBOOT" -eq 1 ]]; then

    echo "----------------------------------------------------"
    echo "REBOOT NØDVENDIG"
    echo
    echo "Kjør:"
    echo
    echo "    sudo reboot"
    echo "----------------------------------------------------"

else

    echo "CPU/GPU/NPU permissions: [OK]"

fi

echo
echo "===================================================="
