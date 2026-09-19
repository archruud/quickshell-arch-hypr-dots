#!/usr/bin/env bash

set -uo pipefail

echo "===================================================="
echo " ARCHRUUD - ASUS NUC 16 PRO - 4B AI BENCHMARK"
echo " Intel Core Ultra 7 356H / Panther Lake"
echo " Qwen3-4B Q4_K_M"
echo " CPU vs Xe3 GPU vs NPU"
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

MODEL="$MODEL_DIR/Qwen3-4B-Q4_K_M.gguf"

MODEL_URL="https://huggingface.co/ggml-org/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf"

mkdir -p "$MODEL_DIR"
mkdir -p "$RESULT_DIR"
mkdir -p "$CACHE_DIR"

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


# --------------------------------------------------
# DEVICE CHECK
# --------------------------------------------------

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


# --------------------------------------------------
# OPENVINO
# --------------------------------------------------

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


# --------------------------------------------------
# MODEL
# --------------------------------------------------

echo
echo "===================================================="
echo " QWEN3 4B MODEL"
echo "===================================================="

if [[ -f "$MODEL" ]]; then

    echo "[OK] Modellen finnes allerede."

else

    echo
    echo "Laster ned Qwen3-4B Q4_K_M..."
    echo "Dette er rundt 2.5 GB."
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


# --------------------------------------------------
# LLAMA-BENCH
# --------------------------------------------------

echo
echo "===================================================="
echo " LLAMA.CPP"
echo "===================================================="

if command -v llama-bench >/dev/null 2>&1; then

    LLAMA_BENCH="$(command -v llama-bench)"
    echo "[OK] $LLAMA_BENCH"

else

    echo "[FEIL] llama-bench finnes ikke."
    exit 1

fi

echo
echo "Tilgjengelige llama.cpp devices:"
echo

"$LLAMA_BENCH" --list-devices || true


# --------------------------------------------------
# RESULT FILE
# --------------------------------------------------

RESULT_FILE="$RESULT_DIR/nuc16-qwen3-4b-$(date +%Y%m%d-%H%M%S).txt"

echo
echo "Resultatfil:"
echo "$RESULT_FILE"


# --------------------------------------------------
# BENCHMARK
# --------------------------------------------------

run_benchmark() {

    DEVICE="$1"
    STATEFUL="$2"

    echo
    echo "===================================================="
    echo " QWEN3-4B - OPENVINO $DEVICE"
    echo "===================================================="

    export GGML_OPENVINO_DEVICE="$DEVICE"

    if [[ "$STATEFUL" == "1" ]]; then
        export GGML_OPENVINO_STATEFUL_EXECUTION=1
    else
        export GGML_OPENVINO_STATEFUL_EXECUTION=0
    fi

    # OpenVINO runtime cache brukes for CPU/GPU.
    # NPU holdes separat.
    if [[ "$DEVICE" == "NPU" ]]; then
        unset GGML_OPENVINO_CACHE_DIR 2>/dev/null || true
    else
        export GGML_OPENVINO_CACHE_DIR="$CACHE_DIR"
    fi

    echo
    echo "Device:   $DEVICE"
    echo "Stateful: $STATEFUL"
    echo

    {
        echo
        echo "===================================================="
        echo "DEVICE: $DEVICE"
        echo "MODEL: Qwen3-4B Q4_K_M"
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
        echo "[OK] $DEVICE benchmark ferdig"
    else
        echo "[WARN] $DEVICE benchmark feilet"
        echo "[WARN] Fortsetter til neste device."
    fi
}


# CPU
run_benchmark "CPU" "0"

# GPU
# Stateful anbefales for OpenVINO GPU.
run_benchmark "GPU" "1"

# NPU
# NPU kjører stateless.
run_benchmark "NPU" "0"


# --------------------------------------------------
# CLEAN ENVIRONMENT
# --------------------------------------------------

unset GGML_OPENVINO_DEVICE 2>/dev/null || true
unset GGML_OPENVINO_STATEFUL_EXECUTION 2>/dev/null || true
unset GGML_OPENVINO_CACHE_DIR 2>/dev/null || true


# --------------------------------------------------
# RESULT SUMMARY
# --------------------------------------------------

echo
echo "===================================================="
echo " 4B BENCHMARK FERDIG"
echo "===================================================="

echo
echo "Modell:"
echo "$MODEL"

echo
echo "Resultater:"
echo "$RESULT_FILE"

echo
echo "Testet:"
echo "  CPU"
echo "  Xe3 GPU"
echo "  NPU"

echo
echo "Se etter:"
echo "  pp256 = prompt processing"
echo "  tg128 = token generation"

echo
echo "===================================================="
