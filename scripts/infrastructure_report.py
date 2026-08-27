#!/usr/bin/env python3

import json
import os
import sys


def load_report(host, report_file):
    if not os.path.exists(report_file):
        print(f"{host:<6} ERROR  report missing")
        return None, True

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

    return results, failed > 0


if len(sys.argv) == 3:
    reports = {
        "DC01": sys.argv[1],
        "SRV01": sys.argv[2],
    }
elif len(sys.argv) == 1:
    reports = {
        "DC01": "reports/dc01-qe-results.json",
        "SRV01": "reports/srv01-qe-results.json",
    }
else:
    print(
        "Usage: infrastructure_report.py "
        "[dc01-report.json srv01-report.json]"
    )
    sys.exit(2)


overall_failed = False

print("Infrastructure QE Summary")
print("-------------------------")

for host, report_file in reports.items():
    _, host_failed = load_report(host, report_file)

    if host_failed:
        overall_failed = True

print()
print("Overall Result")
print("--------------")

if overall_failed:
    print("FAIL")
    sys.exit(1)

print("PASS")
sys.exit(0)
