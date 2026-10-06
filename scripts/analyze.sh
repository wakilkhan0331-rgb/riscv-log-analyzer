#!/bin/bash

set -euo pipefail

# Display usage information.
show_help() {
    cat << EOF
Usage: $0 <log_file> [options]

Options:
  --format [text|csv]   Output format (default: text)
  --output <path>       Save output to a file
  --verbose              Show detailed processing information
  --compare <log_file>   Compare results with another log
  --help                 Show this help message

Examples:
  $0 test_data/sample_pass.log
  $0 test_data/sample_fail.log --format csv
  $0 test_data/sample_sim.log --output output/result.txt
  $0 test_data/sample_pass.log --compare test_data/sample_regression.log
EOF
}

# Print an error message and exit.
error_exit() {
    echo "Error: $1" >&2
    exit 2
}

# Find tests that passed before but fail in the comparison log.
show_regressions() {
    local old_log="$1"
    local new_log="$2"
    local regressions=0

    echo ""
    echo "--- Regressions ---"

    while read -r test_name; do
        if grep -q "TEST PASS: $test_name " "$old_log" &&
           grep -q "TEST FAIL: $test_name " "$new_log"; then
            echo "$test_name: PASS -> FAIL"
            regressions=$((regressions + 1))
        fi
    done < <(
        sed -n 's/.*TEST PASS: \([^ ]*\).*/\1/p' "$old_log" | sort -u
    )

    if [[ "$regressions" -eq 0 ]]; then
        echo "None"
    fi

    echo "Total regressions: $regressions"
}
FORMAT="text"
OUTPUT=""
VERBOSE=false
LOG_FILE=""
COMPARE_FILE=""

# Show help if requested alone.
if [[ $# -eq 1 && "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Log file is required.
if [[ $# -eq 0 ]]; then
    show_help
    error_exit "Log file is required."
fi

# First argument must be the log file.
LOG_FILE="$1"
shift

# Process remaining command-line arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            [[ $# -ge 2 ]] || error_exit "Missing value for --format."
            FORMAT="$2"
            shift 2
            ;;

        --output)
            [[ $# -ge 2 ]] || error_exit "Missing value for --output."
            OUTPUT="$2"
            shift 2
            ;;

        --verbose)
            VERBOSE=true
            shift
            ;;
        --compare)
            [[ $# -ge 2 ]] || error_exit "Missing value for --compare."
            COMPARE_FILE="$2"
            shift 2
            ;;

        --help)
            show_help
            exit 0
            ;;

        *)
            error_exit "Unknown option: $1"
            ;;
    esac
done

# Validate the requested output format.
if [[ "$FORMAT" != "text" && "$FORMAT" != "csv" ]]; then
    error_exit "Invalid format: $FORMAT. Use text or csv."
fi

# Check that the log file exists and is readable.
if [[ ! -f "$LOG_FILE" ]]; then
    error_exit "Log file not found: $LOG_FILE"
fi

if [[ ! -r "$LOG_FILE" ]]; then
    error_exit "Log file is not readable: $LOG_FILE"
fi
# Validate the comparison log when --compare is used.
if [[ -n "$COMPARE_FILE" ]]; then
    if [[ ! -f "$COMPARE_FILE" ]]; then
        error_exit "Comparison log not found: $COMPARE_FILE"
    fi

    if [[ ! -r "$COMPARE_FILE" ]]; then
        error_exit "Comparison log is not readable: $COMPARE_FILE"
    fi
fi
# Verbose information goes to stderr so it does not affect analysis output.
if [[ "$VERBOSE" == true ]]; then
    echo "Reading log file: $LOG_FILE" >&2
    echo "Output format: $FORMAT" >&2
fi
# Send analysis output to the requested destination.
if [[ -n "$OUTPUT" ]]; then
    mkdir -p "$(dirname "$OUTPUT")"
    exec > "$OUTPUT"
fi

# Print the normal header only for text output.
if [[ "$FORMAT" == "text" ]]; then
    echo "RISC-V Log Analyzer"
    echo "Log file: $LOG_FILE"
    echo ""
fi

# Count test results from TEST PASS, TEST FAIL, and TEST SKIP lines.
PASSED=$(grep -c "TEST PASS:" "$LOG_FILE" || true)
FAILED=$(grep -c "TEST FAIL:" "$LOG_FILE" || true)
SKIPPED=$(grep -c "TEST SKIP:" "$LOG_FILE" || true)

# Total tests are the sum of passed, failed, and skipped tests.
TOTAL=$((PASSED + FAILED + SKIPPED))
# Calculate the pass rate. Avoid division by zero if the log has no tests.
if [[ "$TOTAL" -gt 0 ]]; then
    PASS_RATE=$(awk -v passed="$PASSED" -v total="$TOTAL" \
        'BEGIN { printf "%.1f", (passed / total) * 100 }')
else
    PASS_RATE="0.0"
fi
# Generate CSV output when requested.
if [[ "$FORMAT" == "csv" ]]; then
    echo "metric,value"
    echo "log_file,$LOG_FILE"
    echo "total_tests,$TOTAL"
    echo "passed,$PASSED"
    echo "failed,$FAILED"
    echo "skipped,$SKIPPED"
    echo "pass_rate,$PASS_RATE%"

    # Add each failed test as a separate CSV record.
    if [[ "$FAILED" -gt 0 ]]; then
        grep "TEST FAIL:" "$LOG_FILE" | \
            sed -E 's/.*TEST FAIL: ([^ ]+).*/failed_test,\1/'
    else
        echo "failed_test,None"
    fi

    # Add execution time for every PASS and FAIL test.
    grep -E "TEST (PASS|FAIL):" "$LOG_FILE" | \
        sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([0-9.]+)s\).*/execution_time,\2,\3/'

    # Calculate timing statistics for CSV output.
    awk '
    /TEST (PASS|FAIL):/ {
        if (match($0, /\(([0-9.]+)s\)/, time)) {
            value = time[1]

            name = $0
            sub(/.*TEST (PASS|FAIL): /, "", name)
            sub(/ .*/, "", name)

            count++
            sum += value

            if (count == 1 || value < min) {
                min = value
                min_name = name
            }

            if (count == 1 || value > max) {
                max = value
                max_name = name
            }
        }
    }

    END {
        if (count > 0) {
            printf "min_time,%.2f,%s\n", min, min_name
            printf "max_time,%.2f,%s\n", max, max_name
            printf "avg_time,%.2f\n", sum / count
        }
    }
    ' "$LOG_FILE"

# Compare with another log when --compare is provided.
if [[ -n "$COMPARE_FILE" ]]; then
    show_regressions "$LOG_FILE" "$COMPARE_FILE"
fi
    # Return the required exit status in CSV mode.
    if [[ "$FAILED" -eq 0 ]]; then
        echo "verdict,PASS"
        echo "exit_code,0"
        exit 0
    else
        echo "verdict,FAIL"
        echo "exit_code,1"
        exit 1
    fi
fi

echo "--- Results Summary ---"
echo "Total tests: $TOTAL"
echo "Passed:      $PASSED"
echo "Failed:      $FAILED"
echo "Skipped:     $SKIPPED"
echo "Pass rate:   ${PASS_RATE}%"
# Extract and display the name of every failed test.
echo ""
echo "--- Failed Tests ---"

if [[ "$FAILED" -gt 0 ]]; then
    grep "TEST FAIL:" "$LOG_FILE" | \
        sed -E 's/.*TEST FAIL: ([^ ]+).*/\1/' | \
        nl -w2 -s'. '
else
    echo "None"
fi
echo ""
echo "--- Test Execution Times ---"

# Extract test name and execution time from PASS and FAIL entries.
grep -E "TEST (PASS|FAIL):" "$LOG_FILE" | \
    sed -E 's/.*TEST (PASS|FAIL): ([^ ]+) \(([0-9.]+s)\).*/\2: \3/'

echo ""
echo "--- Timing Statistics ---"

# Calculate minimum, maximum, and average execution time.
awk '
/TEST (PASS|FAIL):/ {
    if (match($0, /\(([0-9.]+)s\)/, time)) {
        value = time[1]

        # Extract test name from the TEST line.
        name = $0
        sub(/.*TEST (PASS|FAIL): /, "", name)
        sub(/ .*/, "", name)

        count++
        sum += value

        if (count == 1 || value < min) {
            min = value
            min_name = name
        }

        if (count == 1 || value > max) {
            max = value
            max_name = name
        }
    }
}

END {
    if (count > 0) {
        printf "Min time:  %.2fs (%s)\n", min, min_name
        printf "Max time:  %.2fs (%s)\n", max, max_name
        printf "Avg time:  %.2fs\n", sum / count
    } else {
        print "No execution timing data available."
    }
}
' "$LOG_FILE"

echo ""

# Return success only when no tests failed.
if [[ -n "$COMPARE_FILE" ]]; then
    show_regressions "$LOG_FILE" "$COMPARE_FILE"
fi

if [[ "$FAILED" -eq 0 ]]; then
    echo "--- Verdict: PASS ---"
    exit 0
else
    echo "--- Verdict: FAIL ---"
    exit 1
fi
if [[ "$FAILED" -eq 0 ]]; then
    echo "--- Verdict: PASS ---"
    echo "Exit code: 0"
    exit 0
else
    echo "--- Verdict: FAIL ---"
    echo "Exit code: 1"
    exit 1
fi
