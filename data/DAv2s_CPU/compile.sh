#!/usr/bin/env bash
set -eEo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "${SCRIPT_DIR}"/env.sh

# Check in which python version the hhb package is installed
# Get python version
if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed. Please install Python3 to continue."
    exit 1
fi
PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d '.' -f 1-2)
echo "Using Python version: ${PYTHON_VERSION}"

InputFile=$1
OutputFile=${InputFile%.*}_example


echo -e "\nCompiling ${InputFile} to ${OutputFile}...\n"

set -x
# Compile the input file
riscv64-unknown-linux-gnu-gcc ${InputFile} -o ${OutputFile} "${OUTPUT_DIR}"/io.c "${OUTPUT_DIR}"/model.c \
-Wl,--gc-sections -O2 -g \
${RISCV_INCLUDES} \
-march=rv64gcv0p7_zfh_xtheadc \
-mabi=lp64d \
-fopenmp \
${RISCV_LIBS} \
-Wl,-unresolved-symbols=ignore-in-shared-libs
# Check if the compilation was successful
if [ $? -ne 0 ]; then
    echo "Compilation failed."
    exit 1
fi

exit 0
