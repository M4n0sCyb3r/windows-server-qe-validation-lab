#!/usr/bin/env bash

set -u

REPORT_FILE="reports/dc01-qe-results.json"

ansible_exit=0
report_exit=0

# Never allow evidence from an earlier run to be reused.
rm -f "$REPORT_FILE"

echo "========================================"
echo "DC01 Windows Server QE Validation"
echo "========================================"
echo

echo "[1/2] Running Ansible validation suite..."
echo

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/dc01-validation-suite.yml \
  --ask-vault-password

ansible_exit=$?

echo
echo "[2/2] Evaluating QE evidence..."
echo

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "ERROR: Expected report file was not created:"
    echo "  $REPORT_FILE"
    echo
    echo "Ansible exit: $ansible_exit"
    exit 2
fi

python scripts/qe_report.py "$REPORT_FILE"
report_exit=$?

echo
echo "========================================"
echo "DC01 Workflow Exit Summary"
echo "========================================"
printf "Ansible:   %s\n" "$ansible_exit"
printf "Evidence:  %s\n" "$report_exit"
echo

# Malformed, unreadable, or otherwise untrustworthy evidence
# always makes the workflow an ERROR.
if [[ "$report_exit" -eq 2 ]]; then
    echo "DC01 QE workflow ended with an evidence ERROR."
    exit 2
fi

# Valid structured failure evidence is authoritative for a
# configuration validation failure, even when Ansible returned
# nonzero because a validation assertion intentionally failed.
if [[ "$report_exit" -eq 1 ]]; then
    echo "DC01 QE workflow detected validation failure."
    exit 1
fi

# At this point the evidence says PASS. Ansible must also have
# completed successfully. A disagreement means the workflow
# cannot be trusted.
if [[ "$ansible_exit" -ne 0 ]]; then
    echo "ERROR: Ansible returned nonzero but QE evidence reports PASS."
    exit 2
fi

echo "DC01 QE validation workflow completed successfully."
exit 0
