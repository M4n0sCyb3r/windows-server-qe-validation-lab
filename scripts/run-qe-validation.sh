#!/usr/bin/env bash

set -euo pipefail

REPORT_FILE="reports/dc01-qe-results.json"

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

echo
echo "[2/2] Running Python QE report..."
echo

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "ERROR: Expected report file was not created:"
    echo "  $REPORT_FILE"
    exit 2
fi

python scripts/qe_report.py "$REPORT_FILE"

echo
echo "QE validation workflow completed successfully."
