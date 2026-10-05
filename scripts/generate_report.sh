#!/bin/bash

echo "Generating RISC-V analysis report..."

REPORT="output/report.txt"

{
    echo "RISC-V Log Analyzer Report"
    echo "=========================="
    echo ""
    echo "Report generated successfully."
} > "$REPORT"

echo "Report saved to: $REPORT"
