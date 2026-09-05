#!/usr/bin/env bash

set -u

passed=0
failed=0

run_case() {
    name="$1"
    wrapper="$2"
    ansible_code="$3"
    report_exists="$4"
    reporter_code="$5"
    expected="$6"

    temp_dir="$(mktemp -d)"
    test_repo="$temp_dir/repo"

    mkdir -p \
        "$test_repo/scripts" \
        "$test_repo/inventory" \
        "$test_repo/playbooks" \
        "$test_repo/reports"

    cp "$wrapper" "$test_repo/scripts/$(basename "$wrapper")"

    cat > "$test_repo/ansible-playbook" <<STUB
#!/usr/bin/env bash

if [[ "$report_exists" -eq 1 ]]; then
    case "$(basename "$wrapper")" in
        run-qe-validation.sh)
            touch reports/dc01-qe-results.json
            ;;
        run-srv01-validation.sh)
            touch reports/srv01-qe-results.json
            ;;
    esac
fi

exit $ansible_code
STUB

    cat > "$test_repo/python" <<STUB
#!/usr/bin/env bash
exit $reporter_code
STUB

    chmod +x \
        "$test_repo/scripts/$(basename "$wrapper")" \
        "$test_repo/ansible-playbook" \
        "$test_repo/python"

    echo "TEST: $name"

    (
        cd "$test_repo" || exit 99
        PATH="$test_repo:$PATH" \
            ./scripts/$(basename "$wrapper") \
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

for wrapper in \
    scripts/run-qe-validation.sh \
    scripts/run-srv01-validation.sh
do
    host_name="$(basename "$wrapper")"

    run_case \
        "$host_name - Ansible PASS + evidence PASS" \
        "$wrapper" \
        0 1 0 \
        0

    run_case \
        "$host_name - Ansible nonzero + evidence FAIL" \
        "$wrapper" \
        1 1 1 \
        1

    run_case \
        "$host_name - Ansible nonzero + missing evidence" \
        "$wrapper" \
        1 0 0 \
        2

    run_case \
        "$host_name - Ansible PASS + malformed evidence" \
        "$wrapper" \
        0 1 2 \
        2

    run_case \
        "$host_name - Ansible nonzero + evidence says PASS" \
        "$wrapper" \
        1 1 0 \
        2
done

echo "Host Workflow Evidence Contract Self-Test"
echo "-----------------------------------------"
echo "Passed: $passed"
echo "Failed: $failed"

if [[ "$failed" -gt 0 ]]; then
    exit 1
fi

exit 0
