#!/usr/bin/env bash

set -u

passed=0
failed=0

run_case() {
    name="$1"
    preflight_code="$2"
    dc01_code="$3"
    srv01_code="$4"
    report_code="$5"
    expected="$6"

    temp_dir="$(mktemp -d)"
    test_repo="$temp_dir/repo"

    mkdir -p "$test_repo/scripts"

    cp scripts/run-infrastructure-validation.sh \
       "$test_repo/scripts/run-infrastructure-validation.sh"

    cat > "$test_repo/scripts/run-preflight.sh" <<STUB
#!/usr/bin/env bash
exit $preflight_code
STUB

    cat > "$test_repo/scripts/run-qe-validation.sh" <<STUB
#!/usr/bin/env bash
exit $dc01_code
STUB

    cat > "$test_repo/scripts/run-srv01-validation.sh" <<STUB
#!/usr/bin/env bash
exit $srv01_code
STUB

    cat > "$test_repo/python" <<STUB
#!/usr/bin/env bash
exit $report_code
STUB

    chmod +x \
        "$test_repo/scripts/run-infrastructure-validation.sh" \
        "$test_repo/scripts/run-preflight.sh" \
        "$test_repo/scripts/run-qe-validation.sh" \
        "$test_repo/scripts/run-srv01-validation.sh" \
        "$test_repo/python"

    echo "TEST: $name"

    (
        cd "$test_repo" || exit 99
        PATH="$test_repo:$PATH" \
            ./scripts/run-infrastructure-validation.sh \
            > /dev/null 2>&1
    )
    actual=$?

    if [[ "$actual" -eq "$expected" ]]; then
        echo "PASS: expected exit $expected, got $actual"
        passed=$((passed + 1))
    else
        echo "FAIL: expected exit $expected, got $actual"
        failed=$((failed + 1))
    fi

    rm -rf "$temp_dir"
    echo
}

run_case \
    "All workflow components pass" \
    0 0 0 0 \
    0

run_case \
    "DC01 validation failure propagates as FAIL" \
    0 1 0 1 \
    1

run_case \
    "SRV01 validation failure propagates as FAIL" \
    0 0 1 1 \
    1

run_case \
    "DC01 workflow ERROR propagates as ERROR" \
    0 2 0 2 \
    2

run_case \
    "SRV01 workflow ERROR propagates as ERROR" \
    0 0 2 2 \
    2

run_case \
    "Infrastructure report ERROR propagates as ERROR" \
    0 0 0 2 \
    2

echo "Workflow Exit Contract Self-Test"
echo "--------------------------------"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi

exit 0
