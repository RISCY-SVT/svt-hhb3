#!/usr/bin/env bash
# shellcheck disable=SC2086
set -eEo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}"/env.sh

echo "Using Python version: ${PYTHON_VERSION}"
echo "Using CPU model: ${CPU_MODEL}"
#==============================================================================

set -x

#==============================================================================
# Check in which python version the hhb package is installed
# Get python version
if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed. Please install Python3 to continue."
    exit 1
fi
PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d '.' -f 1-2)
# Chech install_nn2 installation path
if [ ! -d "/usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/install_nn2/${CPU_MODEL}" ]; then
    echo "HHB install_nn2 for ${CPU_MODEL} is not installed in /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/install_nn2/${CPU_MODEL}. Please check your installation."
    exit 1
fi
# Check hhb/prebuilt installation path
if [ ! -d "/usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/decode/install/lib/rv" ]; then
    echo "HHB prebuilt decode for RISC-V is not installed in /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/decode/install/lib/rv. Please check your installation."
    exit 1
fi
# Check tvm/dlpack and tvm/include installation path
if [ ! -d "/usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/dlpack/include" ]; then
    echo "TVM dlpack include is not installed in /usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/dlpack/include. Please check your installation."
    exit 1
fi
if [ ! -d "/usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/include" ]; then
    echo "TVM include is not installed in /usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/include. Please check your installation."
    exit 1
fi 


# # Compile diagnostic tools with debug info
# echo "Compiling diagnostic tools..."
# riscv64-unknown-linux-gnu-gcc -O0 -g -mabi=lp64d \
# ${RISCV_INCLUDES} \
# -I "${OUTPUT_DIR}" \
# "${OUTPUT_DIR}"/runtime_hooks.c -c -o "${OUTPUT_DIR}"/runtime_hooks.o 

# Compile the main.c with lp64d
echo -e "\n##########################\nCompiling main.c to main.o with lp64d ..."
riscv64-unknown-linux-gnu-gcc -O2 -g -mabi=lp64d  \
${RISCV_INCLUDES} \
-I "${OUTPUT_DIR}" \
"${OUTPUT_DIR}"/main.c  -c -o  "${OUTPUT_DIR}"/main.o 

# Compile model.c with diagnostics - use proper RISCV includes, not X86
echo -e "\n##########################\nCompiling model.c with diagnostics..."
riscv64-unknown-linux-gnu-gcc -g -O0 -DDEBUG_CALLBACKS -mabi=lp64d \
${RISCV_INCLUDES} \
-I "${OUTPUT_DIR}" \
"${OUTPUT_DIR}"/model.c -c -o "${OUTPUT_DIR}"/model.o 

# Compile the jit.c with lp64d
echo -e "\n##########################\nCompiling jit.c to jit.o with lp64d ..."
riscv64-unknown-linux-gnu-gcc -O2 -g -mabi=lp64d  \
${RISCV_INCLUDES} \
-I "${OUTPUT_DIR}" \
"${OUTPUT_DIR}"/jit.c  -c -o  "${OUTPUT_DIR}"/jit.o 


# Link with diagnostic runtime for debugging
echo -e "\n##########################\nLinking with diagnostic runtime..."
riscv64-unknown-linux-gnu-gcc "${OUTPUT_DIR}"/model.o "${OUTPUT_DIR}"/main.o \
-o "${OUTPUT_DIR}"/hhb_runtime_debug \
-Wl,--gc-sections  \
-O2 -g -mabi=lp64d  \
-Wl,-unresolved-symbols=ignore-in-shared-libs  \
${RISCV_LIBS}

# Link the standard runtime without diagnostics
echo -e "\n##########################\nLinking standard runtime..."
riscv64-unknown-linux-gnu-gcc "${OUTPUT_DIR}"/model.o  "${OUTPUT_DIR}"/main.o  -o  "${OUTPUT_DIR}"/hhb_runtime  \
-Wl,--gc-sections  \
-O2 -g -mabi=lp64d  \
-Wl,-unresolved-symbols=ignore-in-shared-libs  \
${RISCV_LIBS}

# Link the compiled files to hhb_jit for RISC-V
echo -e "\n##########################\nLinking model.o and jit.o to hhb_jit ..."
riscv64-unknown-linux-gnu-gcc "${OUTPUT_DIR}"/model.o  "${OUTPUT_DIR}"/jit.o  -o  "${OUTPUT_DIR}"/hhb_jit  \
-Wl,--gc-sections  \
-O2 -g -mabi=lp64d  \
-Wl,-unresolved-symbols=ignore-in-shared-libs  \
${RISCV_LIBS}

echo -e "\n########################## Compilation jits and runtime finished ##########################\n"


#==============================================================================
InputFile="depth_da2.c"
echo -e "\n##########################\nCompiling ${InputFile} to ${InputFile%.*} ...\n"
./compile.sh ${InputFile}
echo -e "\n########################## Compilation finished ##########################\n"


exit 0
