#!/usr/bin/env bash

set -u

dc01_exit=0
srv01_exit=0
report_exit=0

echo "========================================"
echo "Windows Server Infrastructure QE"
echo "========================================"
echo

echo "[1/3] Running DC01 validation workflow..."
echo

./scripts/run-qe-validation.sh
dc01_exit=$?

echo
echo "[2/3] Running SRV01 validation workflow..."
echo

./scripts/run-srv01-validation.sh
srv01_exit=$?

echo
echo "[3/3] Building infrastructure report..."
echo

python scripts/infrastructure_report.py
report_exit=$?

echo
echo "========================================"
echo "Workflow Exit Summary"
echo "========================================"

printf "DC01 workflow:   %s\n" "$dc01_exit"
printf "SRV01 workflow:  %s\n" "$srv01_exit"
printf "Infrastructure:  %s\n" "$report_exit"

echo

if [[ "$dc01_exit" -eq 0 &&
      "$srv01_exit" -eq 0 &&
      "$report_exit" -eq 0 ]]; then
    echo "Infrastructure QE workflow completed successfully."
    exit 0
fi

echo "Infrastructure QE workflow failed."
exit 1
