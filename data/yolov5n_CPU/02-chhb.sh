#!/usr/bin/env bash
# shellcheck disable=SC2086
set -eEo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}"/env.sh

echo "Using Python version: ${PYTHON_VERSION}"

COMMON_FLAGS="-O2 -g -mabi=lp64d -DDEBUG_CALLBACKS"

set -x

#==============================================================================
# Setup correct include paths for C920 target
RISCV_INCLUDES="-I ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/include/ \
-I  ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/include/shl_public/ \
-I  ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/include/csinn/ \
-I  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/dlpack/include/ \
-I  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/tvm/include/ \
-I  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/runtime/cmd_parse"

# Compile diagnostic tools with debug info
echo "Compiling diagnostic tools..."
riscv64-unknown-linux-gnu-gcc -O0 -g -mabi=lp64d \
${COMMON_FLAGS} \
${RISCV_INCLUDES} \
-I "${OUTPUT_DIR}" \
"${OUTPUT_DIR}"/runtime_hooks.c -c -o "${OUTPUT_DIR}"/runtime_hooks.o 
riscv64-unknown-linux-gnu-gcc -O0 -g -mabi=lp64d \
${COMMON_FLAGS} \
${RISCV_INCLUDES} \
-I "${OUTPUT_DIR}" \
"${OUTPUT_DIR}"/diagnose_callbacks.c -c -o "${OUTPUT_DIR}"/diagnose_callbacks.o 



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

#==============================================================================
# Link the compiled files for RISC-V
RISCV_LIBS="-fopenmp \
-L  ${INSTALL_NN2_PREFIX}/${CPU_MODEL}/lib/ \
-L  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/decode/install/lib/rv \
-L  /usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/prebuilt/runtime/riscv_linux \
-lprebuilt_runtime -ljpeg -lpng -lz -lstdc++ -lm -ldl \
-lshl_${CPU_MODEL}"

# Link with diagnostic runtime for debugging
echo -e "\n##########################\nLinking with diagnostic runtime..."
riscv64-unknown-linux-gnu-gcc "${OUTPUT_DIR}"/model.o "${OUTPUT_DIR}"/main.o "${OUTPUT_DIR}"/runtime_hooks.o \
-o "${OUTPUT_DIR}"/hhb_runtime_debug \
-Wl,--gc-sections  \
-O2 -g -mabi=lp64d  \
-Wl,-unresolved-symbols=ignore-in-shared-libs  \
${COMMON_FLAGS} \
${RISCV_LIBS}

# Link the standard runtime without diagnostics
echo -e "\n##########################\nLinking standard runtime..."
riscv64-unknown-linux-gnu-gcc "${OUTPUT_DIR}"/model.o  "${OUTPUT_DIR}"/main.o  "${OUTPUT_DIR}"/runtime_hooks.o \
-o  "${OUTPUT_DIR}"/hhb_runtime  \
-Wl,--gc-sections  \
-O2 -g -mabi=lp64d  \
-Wl,-unresolved-symbols=ignore-in-shared-libs  \
${COMMON_FLAGS} \
${RISCV_LIBS}

# Link the compiled files to hhb_jit for RISC-V
echo -e "\n##########################\nLinking model.o and jit.o to hhb_jit ..."
riscv64-unknown-linux-gnu-gcc "${OUTPUT_DIR}"/model.o  "${OUTPUT_DIR}"/jit.o  "${OUTPUT_DIR}"/runtime_hooks.o \
-o  "${OUTPUT_DIR}"/hhb_jit  \
-Wl,--gc-sections  \
-O2 -g -mabi=lp64d  \
-Wl,-unresolved-symbols=ignore-in-shared-libs  \
${COMMON_FLAGS} \
${RISCV_LIBS}

echo -e "\n########################## Compilation jits and runtime finished ##########################\n"

#==============================================================================
InputFile="yolov5n.c"
echo -e "\n##########################\nCompiling ${InputFile} to ${InputFile%.*} ...\n"
./compile.sh ${InputFile}
echo -e "\n########################## Compilation finished ##########################\n"