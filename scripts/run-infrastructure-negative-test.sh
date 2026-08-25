#!/usr/bin/env bash

set -u

dc01_exit=0
srv01_exit=0
report_exit=0

echo "========================================"
echo "Windows Server Infrastructure Negative Test"
echo "========================================"
echo

echo "[1/3] Running DC01 validation workflow..."
echo

./scripts/run-qe-validation.sh
dc01_exit=$?

echo
echo "[2/3] Running SRV01 structured negative validation..."
echo

rm -f reports/srv01-qe-results-negative.json

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-negative-validation-suite.yml \
  --ask-vault-password

python scripts/qe_report.py reports/srv01-qe-results-negative.json
srv01_exit=$?

echo
echo "[3/3] Building infrastructure negative summary..."
echo

if [[ "$dc01_exit" -eq 0 && "$srv01_exit" -eq 1 ]]; then
    report_exit=1
else
    report_exit=0
fi

echo "========================================"
echo "Negative Test Exit Summary"
echo "========================================"

printf "DC01 workflow:   %s\n" "$dc01_exit"
printf "SRV01 negative:  %s\n" "$srv01_exit"
printf "Infrastructure:  %s\n" "$report_exit"

echo

if [[ "$dc01_exit" -eq 0 &&
      "$srv01_exit" -eq 1 &&
      "$report_exit" -eq 1 ]]; then
    echo "PASS: Structured multi-host failure detected correctly."
    exit 0
fi

echo "FAIL: Structured multi-host failure behavior was not as expected."
exit 1
