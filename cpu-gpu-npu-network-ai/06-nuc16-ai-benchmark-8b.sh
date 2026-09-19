#!/usr/bin/env bash

set -uo pipefail

echo "===================================================="
echo " ARCHRUUD - ASUS NUC 16 PRO - 8B AI BENCHMARK"
echo " Intel Core Ultra 7 356H / Panther Lake"
echo " Qwen3-8B Q4_K_M"
echo " CPU / Xe3 GPU / NPU / Vulkan"
echo "===================================================="

if [[ $EUID -eq 0 ]]; then
    echo
    echo "[FEIL] Kjør som vanlig bruker."
    echo "IKKE bruk sudo."
    exit 1
fi

MODEL_DIR="$HOME/AI/models"
RESULT_DIR="$HOME/AI/tests"
CACHE_DIR="$HOME/AI/openvino/cache"

MODEL="$MODEL_DIR/Qwen3-8B-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen3-8B-GGUF/resolve/main/Qwen3-8B-Q4_K_M.gguf"

mkdir -p "$MODEL_DIR" "$RESULT_DIR" "$CACHE_DIR"

echo
echo "===================================================="
echo " HARDWARE"
echo "===================================================="

echo
echo "--- CPU ---"
lscpu | grep -E "Model name|CPU\(s\)|Core|Thread" || true

echo
echo "--- GPU ---"
lspci | grep -Ei "VGA|Display|Graphics" || true

echo
echo "--- NPU ---"
lspci | grep -Ei "Processing accelerators|NPU|VPU" || true

echo
echo "===================================================="
echo " DEVICE CHECK"
echo "===================================================="

[[ -e /dev/dri/renderD128 ]] \
    && echo "[OK] GPU /dev/dri/renderD128" \
    || echo "[WARN] GPU render device mangler"

[[ -e /dev/accel/accel0 ]] \
    && echo "[OK] NPU /dev/accel/accel0" \
    || echo "[WARN] NPU device mangler"

if grep -q '^intel_vpu ' /proc/modules; then
    echo "[OK] intel_vpu"
else
    echo "[WARN] intel_vpu ikke lastet"
fi

echo
echo "===================================================="
echo " OPENVINO"
echo "===================================================="

python -c '
import openvino as ov
c = ov.Core()
print("OpenVINO:", ov.__version__)
print("Devices:", c.available_devices)
'

echo
echo "===================================================="
echo " QWEN3 8B MODEL"
echo "===================================================="

if [[ -f "$MODEL" ]]; then

    echo "[OK] Modellen finnes allerede."

else

    echo
    echo "Laster ned Qwen3-8B Q4_K_M..."
    echo "Størrelse: ca. 5.03 GB"
    echo

    TEMP_MODEL="${MODEL}.part"

    rm -f "$TEMP_MODEL"

    if curl -L \
        --fail \
        --retry 3 \
        --retry-delay 3 \
        --progress-bar \
        "$MODEL_URL" \
        -o "$TEMP_MODEL"; then

        mv "$TEMP_MODEL" "$MODEL"

    else
        echo
        echo "[FEIL] Nedlasting feilet."
        rm -f "$TEMP_MODEL"
        exit 1
    fi
fi

echo
ls -lh "$MODEL"

echo
echo "===================================================="
echo " LLAMA-BENCH"
echo "===================================================="

if command -v llama-bench >/dev/null 2>&1; then
    LLAMA_BENCH="$(command -v llama-bench)"
    echo "[OK] $LLAMA_BENCH"
else
    echo "[FEIL] llama-bench finnes ikke."
    exit 1
fi

echo
echo "Tilgjengelige devices:"
"$LLAMA_BENCH" --list-devices || true

RESULT_FILE="$RESULT_DIR/nuc16-qwen3-8b-$(date +%Y%m%d-%H%M%S).txt"

echo
echo "Resultatfil:"
echo "$RESULT_FILE"

# --------------------------------------------------
# OPENVINO BENCHMARK
# --------------------------------------------------

run_openvino() {

    DEVICE="$1"
    STATEFUL="$2"

    echo
    echo "===================================================="
    echo " QWEN3-8B - OPENVINO $DEVICE"
    echo "===================================================="

    export GGML_OPENVINO_DEVICE="$DEVICE"

    if [[ "$STATEFUL" == "1" ]]; then
        export GGML_OPENVINO_STATEFUL_EXECUTION=1
    else
        export GGML_OPENVINO_STATEFUL_EXECUTION=0
    fi

    if [[ "$DEVICE" == "NPU" ]]; then
        unset GGML_OPENVINO_CACHE_DIR 2>/dev/null || true
    else
        export GGML_OPENVINO_CACHE_DIR="$CACHE_DIR"
    fi

    {
        echo
        echo "===================================================="
        echo "OPENVINO DEVICE: $DEVICE"
        echo "MODEL: Qwen3-8B Q4_K_M"
        echo "DATE: $(date)"
        echo "===================================================="
        echo

        "$LLAMA_BENCH" \
            -m "$MODEL" \
            -fa on \
            -p 256 \
            -n 128 \
            -r 3

    } 2>&1 | tee -a "$RESULT_FILE"

    STATUS=${PIPESTATUS[0]}

    echo

    if [[ "$STATUS" -eq 0 ]]; then
        echo "[OK] OpenVINO $DEVICE ferdig"
    else
        echo "[WARN] OpenVINO $DEVICE feilet"
        echo "[WARN] Fortsetter..."
    fi
}

# CPU stateless
run_openvino "CPU" "0"

# GPU stateful
run_openvino "GPU" "1"

# NPU stateless
run_openvino "NPU" "0"

# Rydd OpenVINO environment før Vulkan-testen
unset GGML_OPENVINO_DEVICE 2>/dev/null || true
unset GGML_OPENVINO_STATEFUL_EXECUTION 2>/dev/null || true
unset GGML_OPENVINO_CACHE_DIR 2>/dev/null || true

# --------------------------------------------------
# PURE VULKAN GPU TEST
# --------------------------------------------------

echo
echo "===================================================="
echo " QWEN3-8B - XE3 PURE VULKAN"
echo "===================================================="

{
    echo
    echo "===================================================="
    echo "DEVICE: Vulkan0"
    echo "MODEL: Qwen3-8B Q4_K_M"
    echo "DATE: $(date)"
    echo "===================================================="
    echo

    "$LLAMA_BENCH" \
        -m "$MODEL" \
        -dev Vulkan0 \
        -ngl 999 \
        -fa on \
        -p 256 \
        -n 128 \
        -r 3

} 2>&1 | tee -a "$RESULT_FILE"

VULKAN_STATUS=${PIPESTATUS[0]}

echo

if [[ "$VULKAN_STATUS" -eq 0 ]]; then
    echo "[OK] Vulkan Xe3 benchmark ferdig"
else
    echo "[WARN] Vulkan Xe3 benchmark feilet"
fi

echo
echo "===================================================="
echo " 8B BENCHMARK FERDIG"
echo "===================================================="

echo
echo "Modell:"
echo "$MODEL"

echo
echo "Resultater:"
echo "$RESULT_FILE"

echo
echo "Vi har testet:"
echo
echo "  1. OpenVINO CPU"
echo "  2. OpenVINO Xe3 GPU"
echo "  3. OpenVINO NPU"
echo "  4. Xe3 Vulkan"

echo
echo "Sammenlign:"
echo
echo "  pp256 = prompt processing"
echo "  tg128 = token generation"

echo
echo "===================================================="
