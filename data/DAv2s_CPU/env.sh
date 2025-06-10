#!/usr/bin/env bash

if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed. Please install Python3 to continue."
    exit 1
fi
export PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d '.' -f 1-2)

export CPU_MODEL="c920"
# export INSTALL_NN2_PREFIX="/usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/install_nn2"
export INSTALL_NN2_PREFIX="/data/csi-nn2/install_nn2"

export ONNX_MODEL_FILE="depth_anything_v2_vits.onnx"
export MODEL_INPUT="image"
export MODEL_OUTPUT="depth"
export MODEL_INPUT_SHAPE="1 3 392 644"
# export CALIBRATION_DIR="calib_100.txt"
export CALIBRATION_DIR="./calibration_images"
export QUANTIZATION_SCHEME="float16"
export OUTPUT_DIR="cpu_model"
export PIXEL_FORMAT="BGR"
export DATA_MEAN="0.5 0.5 0.5"
export DATA_SCALE="0.5"


#==============================================================================
# Setup correct include paths for C920 target
export RISCV_INCLUDES="-I ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/include/ \
-I  ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/include/shl_public/ \
-I  ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/include/csinn/ \
-I  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/dlpack/include/ \
-I  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/include/ \
-I  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/runtime/cmd_parse"

#==============================================================================
# Link the compiled files for RISC-V
export RISCV_LIBS="-fopenmp \
-L  ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/lib/ \
-L  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/decode/install/lib/rv \
-L  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/runtime/riscv_linux \
-lprebuilt_runtime -ljpeg -lpng -lz -lstdc++ -lm -ldl \
-lshl_${CPU_MODEL}"
