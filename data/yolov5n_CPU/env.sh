#!/usr/bin/env bash

if ! command -v python3 &> /dev/null; then
    echo "Python3 is not installed. Please install Python3 to continue."
    exit 1
fi
export PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d '.' -f 1-2)

export CPU_MODEL="c920"
# export INSTALL_NN2_PREFIX="/usr/local/lib/python${PYTHON_VERSION}/dist-packages/hhb/install_nn2"
export INSTALL_NN2_PREFIX="/data/csi-nn2/install_nn2"
export ONNX_MODEL="yolov5n_out3.onnx"
export MODEL_INPUT="images"
export MODEL_OUTPUT="/model.24/m.0/Conv_output_0;/model.24/m.1/Conv_output_0;/model.24/m.2/Conv_output_0"
export MODEL_INPUT_SHAPE="1 3 384 640"
# export CALIBRATION_DIR="kite.jpg"
export CALIBRATION_DIR="./calibration_images"
export QUANTIZATION_SCHEME="float32"
export OUTPUT_DIR="cpu_model"
