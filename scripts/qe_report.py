#!/usr/bin/env python3

import json
import os
import sys


EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_ERROR = 2

REQUIRED_FIELDS = {
    "test",
    "expected",
    "actual",
    "result",
}

VALID_RESULTS = {
    "PASS",
    "FAIL",
}


def evidence_error(message):
    print("ERROR: QE evidence is invalid")
    print(f"  {message}")
    sys.exit(EXIT_ERROR)


def validate_results(results):
    if not isinstance(results, list):
        evidence_error(
            "Top-level report structure must be a JSON list"
        )

    for index, test in enumerate(results):
        if not isinstance(test, dict):
            evidence_error(
                f"Test result at index {index} must be a JSON object"
            )

        missing_fields = REQUIRED_FIELDS - set(test.keys())

        if missing_fields:
            missing = ", ".join(sorted(missing_fields))
            evidence_error(
                f"Test result at index {index} is missing required field(s): "
                f"{missing}"
            )

        if not isinstance(test["test"], str) or not test["test"].strip():
            evidence_error(
                f"Test result at index {index} has an invalid 'test' field"
            )

        if test["result"] not in VALID_RESULTS:
            evidence_error(
                f"Test result at index {index} has invalid result "
                f"{test['result']!r}; expected PASS or FAIL"
            )


default_report = "reports/dc01-qe-results.json"
report_file = sys.argv[1] if len(sys.argv) > 1 else default_report

if not os.path.exists(report_file):
    print("ERROR: Expected report file was not created:")
    print(f"  {report_file}")
    sys.exit(EXIT_ERROR)

try:
    with open(report_file, "r", encoding="utf-8") as file:
        results = json.load(file)
except json.JSONDecodeError as error:
    evidence_error(
        f"Report contains invalid JSON: {error}"
    )
except OSError as error:
    evidence_error(
        f"Report could not be read: {error}"
    )

validate_results(results)

failed_results = [
    test
    for test in results
    if test["result"] == "FAIL"
]

passed_results = [
    test
    for test in results
    if test["result"] == "PASS"
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
    sys.exit(EXIT_FAIL)

print("PASS")
sys.exit(EXIT_PASS)
