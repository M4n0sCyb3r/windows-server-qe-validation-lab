#!/usr/bin/env bash

set -u

PASS=0
FAIL=1

passed_tests=0
failed_tests=0


run_test() {
    local name="$1"
    local expected_exit="$2"
    shift 2

    echo
    echo "TEST: $name"
    echo "Expected exit: $expected_exit"

    "$@"
    actual_exit=$?

    echo "Actual exit:   $actual_exit"

    if [[ "$actual_exit" -eq "$expected_exit" ]]; then
        echo "RESULT: PASS"
        passed_tests=$((passed_tests + 1))
    else
        echo "RESULT: FAIL"
        failed_tests=$((failed_tests + 1))
    fi
}


run_test \
    "Valid Pester PASS evidence returns 0" \
    0 \
    python scripts/pester_report.py tests/fixtures/pester/valid-pass.json

run_test \
    "Valid Pester FAIL evidence returns 1" \
    1 \
    python scripts/pester_report.py tests/fixtures/pester/valid-fail.json

run_test \
    "Empty Pester evidence returns 2" \
    2 \
    python scripts/pester_report.py tests/fixtures/pester/empty-tests.json

run_test \
    "Missing Pester evidence returns 2" \
    2 \
    python scripts/pester_report.py tests/fixtures/pester/does-not-exist.json

run_test \
    "Pester evidence missing required field returns 2" \
    2 \
    python scripts/pester_report.py tests/fixtures/pester/missing-field.json


echo
echo "Pester Reporter Regression Summary"
echo "----------------------------------"
echo "Passed: $passed_tests"
echo "Failed: $failed_tests"

if [[ "$failed_tests" -gt 0 ]]; then
    exit "$FAIL"
fi

exit "$PASS"
