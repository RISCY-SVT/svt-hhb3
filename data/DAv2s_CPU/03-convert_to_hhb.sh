#!/usr/bin/env bash
# HHB Conversion Script for Depth-Anything-V2 on TH1520 NPU
# Version: 1.0.0
# Requirements: Bash ≥ 4, HHB toolchain

set -Eeuo pipefail
IFS=$'\n\t'

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Color support detection
if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && command -v tput &>/dev/null; then
    readonly COLOR_RESET="$(tput sgr0)"
    readonly COLOR_RED="$(tput setaf 1)"
    readonly COLOR_GREEN="$(tput setaf 2)"
    readonly COLOR_YELLOW="$(tput setaf 3)"
    readonly COLOR_BLUE="$(tput setaf 4)"
    readonly COLOR_BOLD="$(tput bold)"
else
    readonly COLOR_RESET=""
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_YELLOW=""
    readonly COLOR_BLUE=""
    readonly COLOR_BOLD=""
fi

# Global flags
QUIET_MODE=0

# Default values (can be overridden by env.sh and CLI)
CPU_MODEL="${CPU_MODEL:-th1520}"
ONNX_MODEL_FILE="${ONNX_MODEL_FILE:-depth_anything_v2_vits.onnx}"
MODEL_INPUT="${MODEL_INPUT:-image}"
MODEL_OUTPUT="${MODEL_OUTPUT:-depth}"
MODEL_INPUT_SHAPE="${MODEL_INPUT_SHAPE:-1 3 392 644}"
CALIBRATION_DIR="${CALIBRATION_DIR:-./calibration_images}"
QUANTIZATION_SCHEME="${QUANTIZATION_SCHEME:-int8_asym}"
OUTPUT_DIR="${OUTPUT_DIR:-npu_model}"

PIXEL_FORMAT="${PIXEL_FORMAT:-BGR}"
DATA_MEAN="${DATA_MEAN:-0.5 0.5 0.5}"
DATA_SCALE="${DATA_SCALE:-0.5}"

# Source env.sh if it exists
if [[ -f "${SCRIPT_DIR}/env.sh" ]]; then
    # shellcheck source=/dev/null
    source "${SCRIPT_DIR}/env.sh"
fi

# Error handling with line numbers
trap 'die "Error occurred at ${BASH_SOURCE[0]}:${LINENO} in function ${FUNCNAME[0]:-main}"' ERR

# Logging functions
log() {
    [[ $QUIET_MODE -eq 1 ]] && return
    echo "$@"
}

info() {
    log "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

warn() {
    log "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

error() {
    echo "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

die() {
    error "$@"
    exit 1
}

success() {
    log "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

# Usage information
usage() {
    cat <<EOF
${COLOR_BOLD}Usage:${COLOR_RESET} ${SCRIPT_NAME} [OPTIONS]

${COLOR_BOLD}Description:${COLOR_RESET}
    Convert Depth-Anything-V2 ONNX model to HHB format for TH1520 NPU deployment.
    
    This script sources env.sh (if present) for default values, which can be
    overridden by command-line options.

${COLOR_BOLD}Options:${COLOR_RESET}
    -m, --model-file <path>      ONNX model file path (default: ${ONNX_MODEL_FILE})
    -b, --board <name>           Target board: th1520, c906, etc. (default: ${CPU_MODEL})
    -o, --output-dir <dir>       Output directory (default: ${OUTPUT_DIR})
    -c, --calib-dir <dir>        Calibration images directory (default: ${CALIBRATION_DIR})
    --input-shape <shape>        Input tensor shape (default: ${MODEL_INPUT_SHAPE})
    --quant <scheme>             Quantization: int8_asym, int8_sym (default: ${QUANTIZATION_SCHEME})
    --pixel-format <format>      Pixel format: BGR, RGB (default: ${PIXEL_FORMAT})
    --data-mean <values>         Mean values for normalization (default: ${DATA_MEAN})
    --data-scale <value>         Scale factor for normalization (default: ${DATA_SCALE})
    -q, --quiet                  Suppress non-error output
    -h, --help                   Show this help message

${COLOR_BOLD}Examples:${COLOR_RESET}
    # Use defaults from env.sh
    ${SCRIPT_NAME}
    
    # Override model and board
    ${SCRIPT_NAME} -m model.onnx -b c906
    
    # Custom quantization with RGB input
    ${SCRIPT_NAME} --quant int8_sym --pixel-format RGB

${COLOR_BOLD}Version:${COLOR_RESET} ${SCRIPT_VERSION}
EOF
}

# Parse command-line arguments
parse_args() {
    local args
    if ! args=$(getopt -o m:b:o:c:qh \
                      --long model-file:,board:,output-dir:,calib-dir:,input-shape:,quant:,pixel-format:,data-mean:,data-scale:,quiet,help \
                      -n "${SCRIPT_NAME}" -- "$@"); then
        die "Failed to parse arguments. Use -h for help."
    fi
    
    eval set -- "$args"
    
    while true; do
        case "$1" in
            -m|--model-file)
                ONNX_MODEL_FILE="$2"
                shift 2
                ;;
            -b|--board)
                CPU_MODEL="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -c|--calib-dir)
                CALIBRATION_DIR="$2"
                shift 2
                ;;
            --input-shape)
                MODEL_INPUT_SHAPE="$2"
                shift 2
                ;;
            --quant)
                QUANTIZATION_SCHEME="$2"
                shift 2
                ;;
            --pixel-format)
                PIXEL_FORMAT="$2"
                shift 2
                ;;
            --data-mean)
                DATA_MEAN="$2"
                shift 2
                ;;
            --data-scale)
                DATA_SCALE="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET_MODE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                die "Internal error in argument parsing"
                ;;
        esac
    done
    
    # Validate options
    if [[ ! "$QUANTIZATION_SCHEME" =~ ^(int8_asym|int8_sym|int16_sym|float16)$ ]]; then
        die "Invalid quantization scheme: ${QUANTIZATION_SCHEME}. Must be float16, int16_sym, int8_asym or int8_sym."
    fi
    
    if [[ ! "$PIXEL_FORMAT" =~ ^(BGR|RGB)$ ]]; then
        die "Invalid pixel format: ${PIXEL_FORMAT}. Must be BGR or RGB."
    fi
}

# Verify prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check HHB command
    if ! command -v hhb &>/dev/null; then
        die "HHB toolchain not found. Please install HHB and ensure it's in PATH."
    fi
    
    # Check model file
    if [[ ! -f "$ONNX_MODEL_FILE" ]]; then
        die "Model file not found: ${ONNX_MODEL_FILE}"
    fi
    
    if [[ ! -r "$ONNX_MODEL_FILE" ]]; then
        die "Model file not readable: ${ONNX_MODEL_FILE}"
    fi
    
    # Check calibration directory оr file
    if  [[ ! -d "$CALIBRATION_DIR" ]] && \
        [[ ! ( -f "$CALIBRATION_DIR" && "$CALIBRATION_DIR" == *.txt ) ]]; then
        die "Calibration directory not found: ${CALIBRATION_DIR}"
    fi
    
    success "All prerequisites satisfied"
}

# Get git commit info if available
get_git_info() {
    if command -v git &>/dev/null && [[ -d "${SCRIPT_DIR}/.git" ]]; then
        git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown"
    else
        echo "not-a-git-repo"
    fi
}

# Main conversion function
run_conversion() {
    info "Starting HHB conversion..."
    info "Model: ${ONNX_MODEL_FILE}"
    info "Board: ${CPU_MODEL}"
    info "Quantization: ${QUANTIZATION_SCHEME}"
    info "Output: ${OUTPUT_DIR}"
    
    # Clean output directory
    if [[ -d "$OUTPUT_DIR" ]]; then
        warn "Output directory exists. Cleaning..."
        rm -rf "$OUTPUT_DIR"
    fi
    
    # Build HHB command
    local hhb_cmd=(
        "hhb"
        "-v" "-v" "-v" "-v"
        "-D"
        "--trace" "csinn"
        "--simulate-data" "$CALIBRATION_DIR"
        "--model-file" "$ONNX_MODEL_FILE"
        "--model-format" "onnx"
        "--board" "$CPU_MODEL"
        "--input-name" "$MODEL_INPUT"
        "--output-name" "$MODEL_OUTPUT"
        "--input-shape" "$MODEL_INPUT_SHAPE"
        "--calibrate-dataset" "$CALIBRATION_DIR"
        "--cali-batch" 1                                # default value is 16
        "--quantization-scheme" "$QUANTIZATION_SCHEME"
        "--data-mean" $DATA_MEAN                        # Intentionally unquoted to split values
        "--data-scale" "$DATA_SCALE"
        "--pixel-format" "$PIXEL_FORMAT"
        "--fuse-conv-relu"
        "--output" "$OUTPUT_DIR"
    )
    
    # Log command
    if [[ $QUIET_MODE -eq 0 ]]; then
        info "Executing command:"
        echo "${COLOR_YELLOW}${hhb_cmd[*]}${COLOR_RESET}"
    fi
    
    # Run conversion
    local log_file="${OUTPUT_DIR}_conversion.log"
    if [[ $QUIET_MODE -eq 1 ]]; then
        "${hhb_cmd[@]}" &>"$log_file"
    else
        "${hhb_cmd[@]}" 2>&1 | tee "$log_file"
    fi
    
    local ret=${PIPESTATUS[0]}
    if [[ $ret -ne 0 ]]; then
        error "HHB conversion failed with exit code: $ret"
        error "Check log file: $log_file"
        exit $ret
    fi
    
    success "HHB conversion completed"
}

# Verify generated artifacts
verify_artifacts() {
    info "Verifying generated artifacts..."
    
    local required_files=(
        "model.c"
        "main.c"
        "io.c"
        "io.h"
        "process.h"
        "hhb.bm"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "${OUTPUT_DIR}/${file}" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        error "Missing required files:"
        printf '%s\n' "${missing_files[@]}" | sed 's/^/  - /'
        die "HHB conversion did not generate all expected artifacts"
    fi
    
    # Check file sizes
    local empty_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -s "${OUTPUT_DIR}/${file}" ]]; then
            empty_files+=("$file")
        fi
    done
    
    if [[ ${#empty_files[@]} -gt 0 ]]; then
        warn "Empty files detected:"
        printf '%s\n' "${empty_files[@]}" | sed 's/^/  - /'
    fi
    
    success "All required artifacts generated"
}

# Generate conversion summary
generate_summary() {
    info "Generating conversion summary..."
    
    local summary_file="${OUTPUT_DIR}/conversion_summary.txt"
    local git_commit
    git_commit=$(get_git_info)
    
    local calib_count
    calib_count=$(find "$CALIBRATION_DIR" -name "*.jpg" -o -name "*.png" 2>/dev/null | wc -l)
    
    {
        echo "Depth-Anything-V2 HHB Conversion Summary"
        echo "========================================"
        echo ""
        echo "Metadata:"
        echo "  Date: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "  Script Version: ${SCRIPT_VERSION}"
        echo "  Git Commit: ${git_commit}"
        echo "  Host: $(hostname)"
        echo ""
        echo "Configuration:"
        echo "  Model File: ${ONNX_MODEL_FILE}"
        echo "  Board: ${CPU_MODEL}"
        echo "  Quantization: ${QUANTIZATION_SCHEME}"
        echo "  Input Name: ${MODEL_INPUT}"
        echo "  Input Shape: ${MODEL_INPUT_SHAPE}"
        echo "  Output Name: ${MODEL_OUTPUT}"
        echo "  Pixel Format: ${PIXEL_FORMAT}"
        echo "  Data Mean: ${DATA_MEAN}"
        echo "  Data Scale: ${DATA_SCALE}"
        echo ""
        echo "Calibration:"
        echo "  Directory: ${CALIBRATION_DIR}"
        echo "  Image Count: ${calib_count}"
        echo ""
        echo "Output:"
        echo "  Directory: ${OUTPUT_DIR}"
        echo "  Generated Files:"
        find "$OUTPUT_DIR" -type f -name "*.c" -o -name "*.h" | sort | sed 's/^/    - /'
    } > "$summary_file"
    
    success "Summary written to: ${summary_file}"
}

# Main function
main() {
    parse_args "$@"
    
    info "${COLOR_BOLD}HHB Conversion Script v${SCRIPT_VERSION}${COLOR_RESET}"
    
    check_prerequisites
    run_conversion
    verify_artifacts
    generate_summary
    
    success "Conversion completed successfully!"
    info "Output directory: ${COLOR_GREEN}${OUTPUT_DIR}${COLOR_RESET}"
    
    if [[ $QUIET_MODE -eq 0 ]]; then
        echo ""
        info "Next steps:"
        echo "  1. Review generated code in ${OUTPUT_DIR}/"
        echo "  2. Compile with: ./04-compile_model.sh"
        echo "  3. Test inference with sample images"
    fi
}

# Execute main function
main "$@"
