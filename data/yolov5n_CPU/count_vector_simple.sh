#!/usr/bin/env bash

# Simple script to count RISC-V Vector instructions
# Vector instructions typically start with 'v' or contain '.v'

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file>"
    exit 1
fi

INPUT_FILE="$1"
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File $INPUT_FILE not found"
    exit 1
fi

# Check objdump availability
if ! command -v riscv64-unknown-linux-gnu-objdump &> /dev/null; then
    echo "Error: riscv64-unknown-linux-gnu-objdump not found. Please install the RISC-V toolchain."
    exit 1
fi

if ! riscv64-unknown-linux-gnu-objdump -d "$INPUT_FILE" > "${INPUT_FILE%.S}.dis"; then
    echo "Error: Failed to disassemble $INPUT_FILE"
    exit 1
fi

INPUT_FILE="${INPUT_FILE%.S}.dis"

echo "Analyzing: $INPUT_FILE"
echo "========================"

# Count total instructions
TOTAL=$(grep -E '^\s*[0-9a-f]+:' "$INPUT_FILE" | wc -l)

# Count vector instructions (simple pattern)
# This catches most vector instructions that either:
# - start with 'v' (like vadd, vmul, vsetvl)
# - end with '.v' (like vle32.v, vse32.v)
VECTOR=$(grep -E '^\s*[0-9a-f]+:.*\s(v[a-z]+\.|[a-z]+\.v)' "$INPUT_FILE" | wc -l)

# Calculate percentage
PERCENT=$(awk "BEGIN {printf \"%.2f\", ($VECTOR / $TOTAL) * 100}")

echo "Total instructions: $TOTAL"
echo "Vector instructions: $VECTOR"
echo "Vector percentage: $PERCENT%"

# Show some examples of vector instructions found
echo ""
echo "First 20 vector instructions found:"
echo "-----------------------------------"
grep -E '^\s*[0-9a-f]+:.*\s(v[a-z]+\.|[a-z]+\.v)' "$INPUT_FILE" | head -20

# Count by instruction mnemonic
echo ""
echo "Vector instruction frequency:"
echo "----------------------------"
grep -E '^\s*[0-9a-f]+:.*\s(v[a-z]+\.|[a-z]+\.v)' "$INPUT_FILE" | \
    awk '{
        for(i=2; i<=NF; i++) {
            if($i ~ /^v[a-z]+\./ || $i ~ /\.[v]/) {
                # Extract just the mnemonic without operands
                split($i, parts, "(")
                inst = parts[1]
                # Remove any trailing commas
                gsub(/,$/, "", inst)
                print inst
                break
            }
        }
    }' | sort | uniq -c | sort -nr | head -20
echo ""
echo "Analysis complete."
echo "========================"
echo
