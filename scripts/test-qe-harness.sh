#!/usr/bin/env bash

set -u

passed=0
failed=0

check_exit_code() {
    name="$1"
    expected="$2"
    shift 2

    echo "TEST: $name"

    "$@" > /dev/null 2>&1
    actual=$?

    if [[ "$actual" -eq "$expected" ]]; then
        echo "PASS: expected exit $expected, got $actual"
        passed=$((passed + 1))
    else
        echo "FAIL: expected exit $expected, got $actual"
        failed=$((failed + 1))
    fi

    echo
}

check_exit_code \
    "Good QE report" \
    0 \
    python scripts/qe_report.py

check_exit_code \
    "Negative QE report" \
    1 \
    python scripts/qe_report.py reports/dc01-qe-results-negative.json

check_exit_code \
    "Missing report workflow" \
    2 \
    ./scripts/run-qe-missing-report-test.sh

echo "QE Harness Self-Test"
echo "--------------------"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi

exit 0
