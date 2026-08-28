#!/usr/bin/env bash

set -u

preflight_exit=0
dc01_exit=0
srv01_exit=0
report_exit=0

echo "========================================"
echo "Windows Server Infrastructure QE"
echo "========================================"
echo

echo "[1/4] Running infrastructure preflight..."
echo

./scripts/run-preflight.sh
preflight_exit=$?

if [[ "$preflight_exit" -ne 0 ]]; then
    echo
    echo "========================================"
    echo "Infrastructure QE Workflow"
    echo "========================================"
    echo "ERROR: Preflight checks failed."
    echo "Validation suites were not executed."
    echo
    echo "Preflight exit: $preflight_exit"
    exit 2
fi

echo
echo "[2/4] Running DC01 validation workflow..."
echo

./scripts/run-qe-validation.sh
dc01_exit=$?

echo
echo "[3/4] Running SRV01 validation workflow..."
echo

./scripts/run-srv01-validation.sh
srv01_exit=$?

echo
echo "[4/4] Building infrastructure report..."
echo

python scripts/infrastructure_report.py
report_exit=$?

echo
echo "========================================"
echo "Workflow Exit Summary"
echo "========================================"

printf "Preflight:        %s\n" "$preflight_exit"
printf "DC01 workflow:    %s\n" "$dc01_exit"
printf "SRV01 workflow:   %s\n" "$srv01_exit"
printf "Infrastructure:   %s\n" "$report_exit"

echo

if [[ "$preflight_exit" -eq 0 &&
      "$dc01_exit" -eq 0 &&
      "$srv01_exit" -eq 0 &&
      "$report_exit" -eq 0 ]]; then
    echo "Infrastructure QE workflow completed successfully."
    exit 0
fi

echo "Infrastructure QE workflow failed."
exit 1
