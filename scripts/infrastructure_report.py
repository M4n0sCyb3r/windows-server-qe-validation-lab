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


def validate_results(host, results):
    errors = []

    if not isinstance(results, list):
        errors.append(
            f"{host}: top-level report structure must be a JSON list"
        )
        return errors

    for index, test in enumerate(results):
        if not isinstance(test, dict):
            errors.append(
                f"{host}: test result at index {index} "
                "must be a JSON object"
            )
            continue

        missing_fields = REQUIRED_FIELDS - set(test.keys())

        if missing_fields:
            missing = ", ".join(sorted(missing_fields))
            errors.append(
                f"{host}: test result at index {index} "
                f"is missing required field(s): {missing}"
            )
            continue

        if not isinstance(test["test"], str) or not test["test"].strip():
            errors.append(
                f"{host}: test result at index {index} "
                "has an invalid 'test' field"
            )

        if test["result"] not in VALID_RESULTS:
            errors.append(
                f"{host}: test result at index {index} "
                f"has invalid result {test['result']!r}; "
                "expected PASS or FAIL"
            )

    return errors


def load_report(host, report_file):
    if not os.path.exists(report_file):
        print(f"{host:<6} ERROR  report missing")
        return None, "ERROR"

    try:
        with open(report_file, "r", encoding="utf-8") as file:
            results = json.load(file)
    except json.JSONDecodeError as error:
        print(f"{host:<6} ERROR  invalid JSON")
        print(f"       {error}")
        return None, "ERROR"
    except OSError as error:
        print(f"{host:<6} ERROR  report unreadable")
        print(f"       {error}")
        return None, "ERROR"

    validation_errors = validate_results(host, results)

    if validation_errors:
        print(f"{host:<6} ERROR  invalid evidence")

        for error in validation_errors:
            print(f"       {error}")

        return None, "ERROR"

    passed = sum(
        1 for test in results
        if test["result"] == "PASS"
    )

    failed = sum(
        1 for test in results
        if test["result"] == "FAIL"
    )

    total = len(results)

    status = "PASS" if failed == 0 else "FAIL"

    print(
        f"{host:<6} {status:<5} "
        f"tests={total} passed={passed} failed={failed}"
    )

    return results, status


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
    sys.exit(EXIT_ERROR)


statuses = []

print("Infrastructure QE Summary")
print("-------------------------")

for host, report_file in reports.items():
    _, status = load_report(host, report_file)
    statuses.append(status)

print()
print("Overall Result")
print("--------------")

if "ERROR" in statuses:
    print("ERROR")
    sys.exit(EXIT_ERROR)

if "FAIL" in statuses:
    print("FAIL")
    sys.exit(EXIT_FAIL)

print("PASS")
sys.exit(EXIT_PASS)
