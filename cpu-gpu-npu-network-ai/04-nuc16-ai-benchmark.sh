#!/usr/bin/env bash

set -uo pipefail

echo "===================================================="
echo " ARCHRUUD - ASUS NUC 16 PRO AI BENCHMARK"
echo " Core Ultra 7 356H / Panther Lake"
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

MODEL="$MODEL_DIR/Qwen3-0.6B-Q4_0.gguf"

MODEL_URL="https://huggingface.co/ggml-org/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf"

mkdir -p "$MODEL_DIR"
mkdir -p "$RESULT_DIR"
mkdir -p "$CACHE_DIR"

echo
echo ">>> Maskin"
echo

echo "CPU:"
lscpu | grep "Model name" || true

echo
echo "GPU:"
lspci | grep -Ei "VGA|Display" || true

echo
echo "NPU:"
lspci | grep -Ei "Processing accelerators|NPU|VPU" || true


# --------------------------------------------------
# DEVICE CHECK
# --------------------------------------------------

echo
echo "===================================================="
echo " DEVICE CHECK"
echo "===================================================="

if [[ -e /dev/dri/renderD128 ]]; then
    echo "[OK] GPU render device"
else
    echo "[WARN] GPU render device mangler"
fi

if [[ -e /dev/accel/accel0 ]]; then
    echo "[OK] NPU /dev/accel/accel0"
else
    echo "[WARN] NPU device mangler"
fi

if grep -q '^intel_vpu ' /proc/modules; then
    echo "[OK] intel_vpu"
else
    echo "[WARN] intel_vpu ikke lastet"
fi


# --------------------------------------------------
# OPENVINO CHECK
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
# DOWNLOAD MODEL
# --------------------------------------------------

echo
echo "===================================================="
echo " TEST MODEL"
echo "===================================================="

if [[ -f "$MODEL" ]]; then

    echo "[OK] Modell finnes allerede:"
    echo "$MODEL"

else

    echo "Laster ned:"
    echo "Qwen3-0.6B Q4_0"
    echo
    echo "Ca. 429 MB"
    echo

    curl -L \
        --fail \
        --progress-bar \
        "$MODEL_URL" \
        -o "$MODEL"

    if [[ $? -ne 0 ]]; then
        echo
        echo "[FEIL] Kunne ikke laste ned modellen."
        rm -f "$MODEL"
        exit 1
    fi

fi

echo
ls -lh "$MODEL"


# --------------------------------------------------
# FIND LLAMA-BENCH
# --------------------------------------------------

echo
echo "===================================================="
echo " LLAMA BENCH"
echo "===================================================="

if command -v llama-bench >/dev/null 2>&1; then

    LLAMA_BENCH="$(command -v llama-bench)"

    echo "[OK] llama-bench:"
    echo "$LLAMA_BENCH"

else

    echo "[FEIL] llama-bench finnes ikke."
    echo
    echo "Kontroller med:"
    echo
    echo "    pacman -Ql llama-cpp | grep llama-bench"
    echo
    exit 1

fi

echo
"$LLAMA_BENCH" --version || true


# --------------------------------------------------
# RESULT FILE
# --------------------------------------------------

RESULT_FILE="$RESULT_DIR/nuc16-benchmark-$(date +%Y%m%d-%H%M%S).txt"

echo
echo "Resultater lagres i:"
echo "$RESULT_FILE"
echo


# --------------------------------------------------
# BENCHMARK FUNCTION
# --------------------------------------------------

run_benchmark() {

    DEVICE="$1"
    STATEFUL="$2"

    echo
    echo "===================================================="
    echo " TESTER OPENVINO $DEVICE"
    echo "===================================================="
    echo

    export GGML_OPENVINO_DEVICE="$DEVICE"

    if [[ "$STATEFUL" == "1" ]]; then
        export GGML_OPENVINO_STATEFUL_EXECUTION=1
    else
        unset GGML_OPENVINO_STATEFUL_EXECUTION 2>/dev/null || true
    fi

    if [[ "$DEVICE" != "NPU" ]]; then
        export GGML_OPENVINO_CACHE_DIR="$CACHE_DIR"
    else
        unset GGML_OPENVINO_CACHE_DIR 2>/dev/null || true
    fi

    echo "GGML_OPENVINO_DEVICE=$GGML_OPENVINO_DEVICE"

    if [[ "$STATEFUL" == "1" ]]; then
        echo "STATEFUL=ON"
    else
        echo "STATEFUL=OFF"
    fi

    echo
    echo "Starter benchmark..."
    echo

    {
        echo
        echo "===================================================="
        echo "DEVICE: $DEVICE"
        echo "DATE: $(date)"
        echo "===================================================="
        echo

        "$LLAMA_BENCH" \
            -m "$MODEL" \
            -fa 1 \
            -p 256 \
            -n 128 \
            -r 3

    } 2>&1 | tee -a "$RESULT_FILE"

    BENCH_STATUS=${PIPESTATUS[0]}

    echo

    if [[ "$BENCH_STATUS" -eq 0 ]]; then
        echo "[OK] $DEVICE benchmark ferdig"
    else
        echo "[WARN] $DEVICE benchmark feilet"
        echo "Fortsetter til neste device..."
    fi
}


# --------------------------------------------------
# CPU
# --------------------------------------------------

run_benchmark "CPU" "0"


# --------------------------------------------------
# GPU
# --------------------------------------------------

run_benchmark "GPU" "1"


# --------------------------------------------------
# NPU
# --------------------------------------------------

run_benchmark "NPU" "0"


# --------------------------------------------------
# FINISHED
# --------------------------------------------------

unset GGML_OPENVINO_DEVICE 2>/dev/null || true
unset GGML_OPENVINO_STATEFUL_EXECUTION 2>/dev/null || true
unset GGML_OPENVINO_CACHE_DIR 2>/dev/null || true

echo
echo "===================================================="
echo " BENCHMARK FERDIG"
echo "===================================================="
echo

echo "Resultatfil:"
echo
echo "$RESULT_FILE"

echo
echo "Modell:"
echo
echo "$MODEL"

echo
echo "Testet:"
echo
echo "  OpenVINO CPU"
echo "  OpenVINO GPU"
echo "  OpenVINO NPU"

echo
echo "===================================================="
