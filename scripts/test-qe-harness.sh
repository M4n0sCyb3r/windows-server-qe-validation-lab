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
    "Passing QE fixture" \
    0 \
    python scripts/qe_report.py tests/fixtures/qe-results-pass.json

check_exit_code \
    "Failing QE fixture" \
    1 \
    python scripts/qe_report.py tests/fixtures/qe-results-fail.json

check_exit_code \
    "Missing report workflow" \
    2 \
    ./scripts/run-qe-missing-report-test.sh

check_exit_code \
    "Infrastructure both hosts pass" \
    0 \
    python scripts/infrastructure_report.py \
        tests/fixtures/infrastructure/dc01-pass.json \
        tests/fixtures/infrastructure/srv01-pass.json

check_exit_code \
    "Infrastructure one host fails" \
    1 \
    python scripts/infrastructure_report.py \
        tests/fixtures/infrastructure/dc01-pass.json \
        tests/fixtures/infrastructure/srv01-fail.json

check_exit_code \
    "Infrastructure report missing" \
    1 \
    python scripts/infrastructure_report.py \
        tests/fixtures/infrastructure/dc01-pass.json \
        tests/fixtures/infrastructure/does-not-exist.json

echo "QE Harness Self-Test"
echo "--------------------"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi

exit 0
