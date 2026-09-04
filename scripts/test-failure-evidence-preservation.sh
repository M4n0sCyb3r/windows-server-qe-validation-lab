#!/usr/bin/env bash

set -u

report_file="$(mktemp)"
output_file="$(mktemp)"

cleanup() {
    rm -f "$report_file" "$output_file"
}

trap cleanup EXIT

rm -f "$report_file"

ansible-playbook \
    -i localhost, \
    -c local \
    tests/failure-evidence-regression.yml \
    -e "failure_evidence_report=$report_file" \
    > "$output_file" 2>&1

ansible_exit=$?

if [[ "$ansible_exit" -eq 0 ]]; then
    echo "FAIL: controlled Ansible regression unexpectedly returned exit 0"
    cat "$output_file"
    exit 1
fi

if [[ ! -s "$report_file" ]]; then
    echo "FAIL: expected preserved QE report was not created"
    cat "$output_file"
    exit 1
fi

python - "$report_file" <<'PY'
import json
import sys

report_file = sys.argv[1]

with open(report_file, "r", encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data, list):
    print("FAIL: preserved QE report is not a JSON list")
    sys.exit(1)

failures = [
    item
    for item in data
    if isinstance(item, dict) and item.get("result") == "FAIL"
]

if not failures:
    print("FAIL: preserved QE report contains no FAIL result")
    sys.exit(1)

expected_test = "Failure Evidence Regression"

if failures[0].get("test") != expected_test:
    print(
        "FAIL: preserved failure test name did not match "
        f"{expected_test!r}"
    )
    sys.exit(1)

print("PASS: validation returned nonzero")
print("PASS: QE evidence report was preserved")
print("PASS: preserved JSON contains structured FAIL evidence")
PY
