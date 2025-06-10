#!/usr/bin/env bash

# Script to count T-Head Vector Extension (XTHeadVector) instructions in assembly listing
# T-Head's TH1520 uses custom vector instructions with 'th.' prefix

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file>"
    echo "Example: $0 yolov5n_example"
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

echo "Analyzing T-Head Vector instructions in: $INPUT_FILE"
echo "=============================================="

# T-Head Vector Extension instruction patterns
# T-Head vector instructions use 'th.' prefix
VECTOR_PATTERNS=(
    # Configuration instructions
    "th\.vsetvl"
    
    # Load/Store instructions
    "th\.vl[bhwd]\.v"
    "th\.vl[bhwd]u\.v"
    "th\.vle\.v"
    "th\.vlse\.v"
    "th\.vlxe[0-9]+\.v"
    "th\.vs[bhwd]\.v"
    "th\.vse\.v"
    "th\.vsse\.v"
    "th\.vsxe[0-9]+\.v"
    "th\.vlseg[0-9]e[0-9]+\.v"
    "th\.vsseg[0-9]e[0-9]+\.v"
    
    # Arithmetic instructions
    "th\.vadd\."
    "th\.vsub\."
    "th\.vrsub\."
    "th\.vmul\."
    "th\.vmulh\."
    "th\.vmulhu\."
    "th\.vmulhsu\."
    "th\.vdiv\."
    "th\.vdivu\."
    "th\.vrem\."
    "th\.vremu\."
    
    # Widening arithmetic
    "th\.vwadd\."
    "th\.vwsub\."
    "th\.vwmul\."
    "th\.vwmulu\."
    "th\.vwmulsu\."
    "th\.vwmacc\."
    "th\.vwcvt\."
    
    # Narrowing arithmetic
    "th\.vnsra\."
    "th\.vnsrl\."
    "th\.vncvt\."
    "th\.vnclip\."
    
    # Fixed-point arithmetic
    "th\.vsadd\."
    "th\.vssub\."
    "th\.vsmul\."
    
    # Logical operations
    "th\.vand\."
    "th\.vor\."
    "th\.vxor\."
    "th\.vnot\."
    
    # Shift operations
    "th\.vsll\."
    "th\.vsrl\."
    "th\.vsra\."
    
    # Comparison operations
    "th\.vmseq\."
    "th\.vmsne\."
    "th\.vmslt\."
    "th\.vmsle\."
    "th\.vmsgt\."
    "th\.vmsge\."
    "th\.vmsltu\."
    "th\.vmsleu\."
    "th\.vmsgtu\."
    "th\.vmsgeu\."
    
    # Min/Max operations
    "th\.vmin\."
    "th\.vmax\."
    "th\.vminu\."
    "th\.vmaxu\."
    
    # Merge and move operations
    "th\.vmerge\."
    "th\.vmv\."
    
    # Reductions
    "th\.vredsum\."
    "th\.vredand\."
    "th\.vredor\."
    "th\.vredxor\."
    "th\.vredmin\."
    "th\.vredmax\."
    "th\.vredminu\."
    "th\.vredmaxu\."
    
    # Floating-point operations
    "th\.vfadd\."
    "th\.vfsub\."
    "th\.vfmul\."
    "th\.vfdiv\."
    "th\.vfsqrt\."
    "th\.vfmin\."
    "th\.vfmax\."
    "th\.vfneg\."
    "th\.vfabs\."
    "th\.vfsgnj\."
    "th\.vfsgnjn\."
    "th\.vfsgnjx\."
    "th\.vfmacc\."
    "th\.vfmv\."
    
    # Floating-point conversions
    "th\.vfcvt\."
    "th\.vfwcvt\."
    "th\.vfncvt\."
    
    # Floating-point comparisons
    "th\.vmfeq\."
    "th\.vmfne\."
    "th\.vmflt\."
    "th\.vmfle\."
    "th\.vmfgt\."
    "th\.vmfge\."
    
    # Mask operations
    "th\.vmand\."
    "th\.vmnand\."
    "th\.vmandnot\."
    "th\.vmor\."
    "th\.vmnor\."
    "th\.vmornot\."
    "th\.vmxor\."
    "th\.vmxnor\."
    
    # Permutation operations
    "th\.vrgather\."
    "th\.vslide"
    "th\.vcompress\."
    
    # Other vector instructions
    "th\.vzext\."
    "th\.vsext\."
    "th\.vpopc\."
    "th\.vfirst\."
    "th\.vmsbf\."
    "th\.vmsif\."
    "th\.vmsof\."
    "th\.viota\."
    "th\.vid\."
)

# Create pattern for grep
PATTERN=""
for p in "${VECTOR_PATTERNS[@]}"; do
    if [ -z "$PATTERN" ]; then
        PATTERN="$p"
    else
        PATTERN="$PATTERN|$p"
    fi
done

# Count total instructions (lines with hex addresses followed by instruction)
TOTAL_INSTRUCTIONS=$(grep -E '^\s*[0-9a-f]+:' "$INPUT_FILE" | wc -l)

# Count vector instructions
VECTOR_INSTRUCTIONS=$(grep -E '^\s*[0-9a-f]+:.*\s('"$PATTERN"')' "$INPUT_FILE" | wc -l)

# Calculate percentage
if [ $TOTAL_INSTRUCTIONS -eq 0 ]; then
    PERCENTAGE=0
else
    PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", ($VECTOR_INSTRUCTIONS / $TOTAL_INSTRUCTIONS) * 100}")
fi

echo ""
echo "Summary:"
echo "--------"
echo "Total instructions: $TOTAL_INSTRUCTIONS"
echo "Vector instructions: $VECTOR_INSTRUCTIONS"
echo "Vector instruction percentage: $PERCENTAGE%"

# Show breakdown by instruction type
echo ""
echo "Vector instruction breakdown:"
echo "----------------------------"

# Count each type of vector instruction
for pattern in "${VECTOR_PATTERNS[@]}"; do
    count=$(grep -E '^\s*[0-9a-f]+:.*\s'"$pattern" "$INPUT_FILE" | wc -l)
    if [ $count -gt 0 ]; then
        printf "%-20s: %6d\n" "$pattern" "$count"
    fi
done | sort -k2 -nr

# Show top 10 most used vector instructions
echo ""
echo "Top 10 most frequent vector instructions:"
echo "----------------------------------------"
grep -E '^\s*[0-9a-f]+:.*\s('"$PATTERN"')' "$INPUT_FILE" | \
    awk '{for(i=2;i<=NF;i++) if($i ~ /^v/) {print $i; break}}' | \
    sort | uniq -c | sort -nr | head -10

# Optional: Save all vector instructions to a separate file
OUTPUT_FILE="${INPUT_FILE%.S}_vector_instructions.txt"
echo ""
echo "Saving all vector instructions to: $OUTPUT_FILE"
grep -E '^\s*[0-9a-f]+:.*\s('"$PATTERN"')' "$INPUT_FILE" > "$OUTPUT_FILE"

echo ""
echo "Analysis complete!"
echo "You can view the detailed vector instructions in: $OUTPUT_FILE"
echo 
