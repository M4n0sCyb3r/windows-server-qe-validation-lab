#!/usr/bin/env python3

import json
import os
import sys

default_report = "reports/dc01-qe-results.json"
report_file = sys.argv[1] if len(sys.argv) > 1 else default_report

if not os.path.exists(report_file):
    print("ERROR: Expected report file was not created:")
    print(f"  {report_file}")
    sys.exit(2)

with open(report_file, "r", encoding="utf-8") as file:
    results = json.load(file)

failed_results = [
    test for test in results
    if test.get("result") == "FAIL"
]

passed_results = [
    test for test in results
    if test.get("result") == "PASS"
]

report_name = os.path.basename(report_file)

if report_name.startswith("dc01"):
    system_name = "DC01"
elif report_name.startswith("srv01"):
    system_name = "SRV01"
else:
    system_name = "Windows Server"

print(f"{system_name} QE Validation Report")
print("-------------------------")
print(f"Report file:  {report_file}")
print(f"Total tests:  {len(results)}")
print(f"Passed:       {len(passed_results)}")
print(f"Failed:       {len(failed_results)}")

print()
print("Test Results")
print("------------")

for test in results:
    print(f"{test['result']}: {test['test']}")

if failed_results:
    print()
    print("Failures")
    print("--------")

    for test in failed_results:
        print(f"FAIL: {test['test']}")
        print(f"  Expected: {test['expected']}")
        print(f"  Actual:   {test['actual']}")

print()
print("Overall Result")
print("--------------")

if failed_results:
    print("FAIL")
    sys.exit(1)

print("PASS")
sys.exit(0)
