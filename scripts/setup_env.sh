#!/bin/bash

set -euo pipefail

# Check that required command-line tools are available.
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "[OK] $1"
    else
        echo "[MISSING] $1"
        return 1
    fi
}

echo "RISC-V Log Analyzer Environment Check"
echo "====================================="

# These tools are required by the project scripts.
REQUIRED_TOOLS=(bash grep awk sed nl make)

missing=0

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! check_command "$tool"; then
        missing=1
    fi
done

# Create the output directory used by generated reports.
mkdir -p output

if [[ "$missing" -eq 0 ]]; then
    echo ""
    echo "Environment check passed."
    exit 0
else
    echo ""
    echo "Environment check failed."
    exit 1
fi
