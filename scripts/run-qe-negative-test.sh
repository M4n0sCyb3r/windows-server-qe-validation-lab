#!/usr/bin/env bash

set -e

echo "Running controlled QE negative test..."
echo

python scripts/qe_report.py reports/dc01-qe-results-negative.json
