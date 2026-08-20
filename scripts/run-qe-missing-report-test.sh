#!/usr/bin/env bash

set -euo pipefail

REPORT_FILE="reports/this-report-does-not-exist.json"

if [[ ! -f "$REPORT_FILE" ]]; then
    echo "ERROR: Expected report file was not created:"
    echo "  $REPORT_FILE"
    exit 2
fi

python scripts/qe_report.py "$REPORT_FILE"
