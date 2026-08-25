#!/usr/bin/env python3

import json
import os
import sys

reports = {
    "DC01": "reports/dc01-qe-results.json",
    "SRV01": "reports/srv01-qe-results.json",
}

overall_failed = False

print("Infrastructure QE Summary")
print("-------------------------")

for host, report_file in reports.items():
    if not os.path.exists(report_file):
        print(f"{host:<6} ERROR  report missing")
        overall_failed = True
        continue

    with open(report_file, "r", encoding="utf-8") as file:
        results = json.load(file)

    passed = sum(1 for test in results if test.get("result") == "PASS")
    failed = sum(1 for test in results if test.get("result") == "FAIL")
    total = len(results)

    status = "PASS" if failed == 0 else "FAIL"

    print(
        f"{host:<6} {status:<4}  "
        f"tests={total} passed={passed} failed={failed}"
    )

    if failed > 0:
        overall_failed = True

print()
print("Overall Result")
print("--------------")

if overall_failed:
    print("FAIL")
    sys.exit(1)

print("PASS")
sys.exit(0)
