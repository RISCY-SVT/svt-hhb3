#!/bin/bash

echo "Checking linked libraries for yolov5n_example..."
echo "================================================"

# Check linked libraries
echo -e "\nLinked libraries:"
ldd yolov5n_example | grep -E "(shl|csinn|nn)"

# Check for SHL libraries in system
echo -e "\nSHL libraries in /usr/lib:"
ls -la /usr/lib/libshl* 2>/dev/null || echo "No SHL libraries found in /usr/lib"

echo -e "\nSHL libraries in /usr/local/lib:"
ls -la /usr/local/lib/libshl* 2>/dev/null || echo "No SHL libraries found in /usr/local/lib"

echo -e "\nSHL libraries in /lib:"
ls -la /lib/libshl* 2>/dev/null || echo "No SHL libraries found in /lib"

# Check symbols in the binary
echo -e "\nChecking symbols in yolov5n_example:"
nm yolov5n_example | grep -i "shl_c920_runtime_callback" || echo "Symbol not found"

# Check for undefined symbols
echo -e "\nUndefined symbols related to SHL/CSINN:"
nm -u yolov5n_example | grep -E "(shl|csinn)" | head -20

# Try to find where the callback is called
echo -e "\nSearching for callback references in binary:"
strings yolov5n_example | grep -i "callback"

# Check environment
echo -e "\nEnvironment variables:"
env | grep -E "(SHL|CSINN|LD_LIBRARY_PATH)"
echo -e "\nLD_LIBRARY_PATH:"
echo $LD_LIBRARY_PATH
