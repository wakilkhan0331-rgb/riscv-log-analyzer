#!/bin/bash

set -euo pipefail

REPORT="output/report.txt"

# Create the output directory if it does not exist.
mkdir -p output

echo "Generating RISC-V analysis report..."

{
    echo "RISC-V Log Analyzer Report"
    echo "=========================="
    echo ""

    # Analyze every sample log in the test_data directory.
    for log_file in test_data/*.log; do
        echo "Log: $log_file"
        echo "--------------------------"

        # The analyzer returns 1 for logs containing failures.
        # We temporarily disable exit-on-error for that expected result.
        set +e
        result=$(./scripts/analyze.sh "$log_file")
        status=$?
        set -e

        echo "$result"
        echo "Analyzer exit code: $status"
        echo ""
    done
} > "$REPORT"

echo "Report saved to: $REPORT"
