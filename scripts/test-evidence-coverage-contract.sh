#!/usr/bin/env bash

set -u

passed=0
failed=0

temp_dir="$(mktemp -d)"

cleanup() {
    rm -rf "$temp_dir"
}

trap cleanup EXIT


record_result() {
    name="$1"
    expected="$2"
    actual="$3"

    echo "TEST: $name"

    if [[ "$actual" -eq "$expected" ]]; then
        echo "PASS: expected exit $expected, got $actual"
        passed=$((passed + 1))
    else
        echo "FAIL: expected exit $expected, got $actual"
        failed=$((failed + 1))
    fi

    echo
}


run_model_case() {
    name="$1"
    requested="$2"
    completed="$3"
    has_failure="$4"
    expected="$5"

    python - "$requested" "$completed" "$has_failure" <<'PY'
import sys

EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_ERROR = 2

requested = {
    item
    for item in sys.argv[1].split(",")
    if item
}

completed = {
    item
    for item in sys.argv[2].split(",")
    if item
}

has_failure = sys.argv[3] == "1"

if has_failure:
    sys.exit(EXIT_FAIL)

if requested != completed:
    sys.exit(EXIT_ERROR)

sys.exit(EXIT_PASS)
PY

    actual=$?

    record_result \
        "$name" \
        "$expected" \
        "$actual"
}


check_diagnostic() {
    name="$1"
    output_file="$2"
    expected_exit="$3"
    actual_exit="$4"
    expected_message="$5"

    echo "TEST: $name"

    case_passed=1

    if [[ "$actual_exit" -eq "$expected_exit" ]]; then
        echo "PASS: expected exit $expected_exit, got $actual_exit"
    else
        echo "FAIL: expected exit $expected_exit, got $actual_exit"
        case_passed=0
    fi

    if grep -Fq "$expected_message" "$output_file"; then
        echo "PASS: expected diagnostic found"
    else
        echo "FAIL: expected diagnostic was not found"
        echo "Expected:"
        echo "  $expected_message"
        echo "Actual reporter output:"
        cat "$output_file"
        case_passed=0
    fi

    if [[ "$case_passed" -eq 1 ]]; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
    fi

    echo
}


cat > "$temp_dir/unsupported-version.json" <<'JSON'
{
  "schema_version": 999,
  "requested_scopes": [
    "network"
  ],
  "completed_scopes": [
    "network"
  ],
  "results": [
    {
      "test": "Network Configuration",
      "expected": "10.10.10.20",
      "actual": "10.10.10.20",
      "result": "PASS"
    }
  ]
}
JSON


cat > "$temp_dir/missing-version.json" <<'JSON'
{
  "requested_scopes": [
    "network"
  ],
  "completed_scopes": [
    "network"
  ],
  "results": [
    {
      "test": "Network Configuration",
      "expected": "10.10.10.20",
      "actual": "10.10.10.20",
      "result": "PASS"
    }
  ]
}
JSON


cat > "$temp_dir/zero-requested-scopes.json" <<'JSON'
{
  "schema_version": 2,
  "requested_scopes": [],
  "completed_scopes": [],
  "results": [
    {
      "test": "Synthetic PASS result",
      "expected": "expected",
      "actual": "expected",
      "result": "PASS"
    }
  ]
}
JSON


run_model_case \
    "Complete selective scope passes" \
    "network" \
    "network" \
    0 \
    0

run_model_case \
    "Incomplete selective scope is ERROR" \
    "network" \
    "" \
    0 \
    2

run_model_case \
    "Multiple complete scopes pass regardless of order" \
    "network,services" \
    "services,network" \
    0 \
    0

run_model_case \
    "One missing scope is ERROR" \
    "network,services" \
    "network" \
    0 \
    2

run_model_case \
    "Structured validation failure remains FAIL" \
    "network,services" \
    "network" \
    1 \
    1


single_host_output="$temp_dir/single-host.txt"

python scripts/qe_report.py \
    tests/fixtures/schema/incomplete-coverage.json \
    > "$single_host_output" 2>&1

single_host_exit=$?

check_diagnostic \
    "Single-host reporter detects incomplete coverage" \
    "$single_host_output" \
    2 \
    "$single_host_exit" \
    "Missing scopes: services"


infrastructure_output="$temp_dir/infrastructure.txt"

python scripts/infrastructure_report.py \
    tests/fixtures/infrastructure/dc01-pass.json \
    tests/fixtures/schema/incomplete-coverage.json \
    > "$infrastructure_output" 2>&1

infrastructure_exit=$?

check_diagnostic \
    "Infrastructure reporter detects incomplete coverage" \
    "$infrastructure_output" \
    2 \
    "$infrastructure_exit" \
    "Missing scopes: services"


unsupported_single_output="$temp_dir/unsupported-single.txt"

python scripts/qe_report.py \
    "$temp_dir/unsupported-version.json" \
    > "$unsupported_single_output" 2>&1

unsupported_single_exit=$?

check_diagnostic \
    "Single-host reporter rejects unsupported schema version" \
    "$unsupported_single_output" \
    2 \
    "$unsupported_single_exit" \
    "Unsupported schema_version: 999"


missing_single_output="$temp_dir/missing-single.txt"

python scripts/qe_report.py \
    "$temp_dir/missing-version.json" \
    > "$missing_single_output" 2>&1

missing_single_exit=$?

check_diagnostic \
    "Single-host reporter rejects missing schema version" \
    "$missing_single_output" \
    2 \
    "$missing_single_exit" \
    "Missing required field: schema_version"


unsupported_infrastructure_output="$temp_dir/unsupported-infrastructure.txt"

python scripts/infrastructure_report.py \
    tests/fixtures/infrastructure/dc01-pass.json \
    "$temp_dir/unsupported-version.json" \
    > "$unsupported_infrastructure_output" 2>&1

unsupported_infrastructure_exit=$?

check_diagnostic \
    "Infrastructure reporter rejects unsupported schema version" \
    "$unsupported_infrastructure_output" \
    2 \
    "$unsupported_infrastructure_exit" \
    "Unsupported schema_version: 999"


missing_infrastructure_output="$temp_dir/missing-infrastructure.txt"

python scripts/infrastructure_report.py \
    tests/fixtures/infrastructure/dc01-pass.json \
    "$temp_dir/missing-version.json" \
    > "$missing_infrastructure_output" 2>&1

missing_infrastructure_exit=$?

check_diagnostic \
    "Infrastructure reporter rejects missing schema version" \
    "$missing_infrastructure_output" \
    2 \
    "$missing_infrastructure_exit" \
    "Missing required field: schema_version"


zero_requested_single_output="$temp_dir/zero-requested-single.txt"

python scripts/qe_report.py \
    "$temp_dir/zero-requested-scopes.json" \
    > "$zero_requested_single_output" 2>&1

zero_requested_single_exit=$?

check_diagnostic \
    "Single-host reporter rejects zero requested scopes" \
    "$zero_requested_single_output" \
    2 \
    "$zero_requested_single_exit" \
    "Coverage evidence contains zero requested scopes"


zero_requested_infrastructure_output="$temp_dir/zero-requested-infrastructure.txt"

python scripts/infrastructure_report.py \
    tests/fixtures/infrastructure/dc01-pass.json \
    "$temp_dir/zero-requested-scopes.json" \
    > "$zero_requested_infrastructure_output" 2>&1

zero_requested_infrastructure_exit=$?

check_diagnostic \
    "Infrastructure reporter rejects zero requested scopes" \
    "$zero_requested_infrastructure_output" \
    2 \
    "$zero_requested_infrastructure_exit" \
    "Coverage evidence contains zero requested scopes"


echo "Evidence Coverage Contract Self-Test"
echo "------------------------------------"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi

exit 0
