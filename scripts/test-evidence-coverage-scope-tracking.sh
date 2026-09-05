#!/usr/bin/env bash

set -u

passed=0
failed=0

temp_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$temp_dir"
}

trap cleanup EXIT


run_case() {
    name="$1"
    expected_requested="$2"
    expected_completed="$3"
    shift 3

    report_file="$temp_dir/report.json"
    output_file="$temp_dir/ansible-output.txt"

    rm -f "$report_file" "$output_file"

    echo "TEST: $name"

    ansible-playbook \
        -i localhost, \
        -c local \
        tests/evidence-coverage-scope-regression.yml \
        -e "coverage_report=$report_file" \
        "$@" \
        > "$output_file" 2>&1

    ansible_exit=$?

    if [[ "$ansible_exit" -ne 0 ]]; then
        echo "FAIL: Ansible returned exit $ansible_exit"
        cat "$output_file"
        failed=$((failed + 1))
        echo
        return
    fi

    if [[ ! -s "$report_file" ]]; then
        echo "FAIL: coverage report was not created"
        cat "$output_file"
        failed=$((failed + 1))
        echo
        return
    fi

    python - \
        "$report_file" \
        "$expected_requested" \
        "$expected_completed" <<'PY'

import json
import sys

report_file = sys.argv[1]

expected_requested = {
    item
    for item in sys.argv[2].split(",")
    if item
}

expected_completed = {
    item
    for item in sys.argv[3].split(",")
    if item
}

with open(report_file, "r", encoding="utf-8") as file:
    data = json.load(file)

actual_requested = set(data["requested_scopes"])
actual_completed = set(data["completed_scopes"])

if actual_requested != expected_requested:
    print(
        "FAIL: requested scopes mismatch: "
        f"expected={sorted(expected_requested)} "
        f"actual={sorted(actual_requested)}"
    )
    sys.exit(1)

if actual_completed != expected_completed:
    print(
        "FAIL: completed scopes mismatch: "
        f"expected={sorted(expected_completed)} "
        f"actual={sorted(actual_completed)}"
    )
    sys.exit(1)

print(
    "PASS: "
    f"requested={sorted(actual_requested)} "
    f"completed={sorted(actual_completed)}"
)
PY

    check_exit=$?

    if [[ "$check_exit" -eq 0 ]]; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    echo
}


run_case \
    "Selective network scope" \
    "network" \
    "network" \
    --tags network


run_case \
    "Multiple selected scopes" \
    "network,services" \
    "network,services" \
    --tags network,services


run_case \
    "Skip services from full scope" \
    "network" \
    "network" \
    --skip-tags services


run_case \
    "Interrupted network scope is not completed" \
    "network" \
    "" \
    --tags network \
    -e "interrupt_network_completion=true"


echo "Evidence Coverage Scope Tracking Self-Test"
echo "------------------------------------------"
echo "Passed: $passed"
echo "Failed: $failed"


if [[ "$failed" -gt 0 ]]; then
    exit 1
fi

exit 0
