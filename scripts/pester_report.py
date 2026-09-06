#!/usr/bin/env python3

import json
import sys
from pathlib import Path


PASS = 0
FAIL = 1
ERROR = 2

SUPPORTED_SCHEMA_VERSION = 1


def evidence_error(message):
    print("ERROR: Pester evidence is invalid")
    print(message)
    return ERROR


def load_evidence(report_path):
    try:
        with report_path.open("r", encoding="utf-8") as report_file:
            return json.load(report_file)
    except FileNotFoundError:
        print(f"ERROR: Pester report does not exist: {report_path}")
        sys.exit(ERROR)
    except json.JSONDecodeError as exc:
        print("ERROR: Pester report contains invalid JSON")
        print(exc)
        sys.exit(ERROR)
    except OSError as exc:
        print("ERROR: Unable to read Pester report")
        print(exc)
        sys.exit(ERROR)


def validate_evidence(data):
    if not isinstance(data, dict):
        return "Top-level Pester evidence must be an object."

    required_fields = {
        "schema_version",
        "framework",
        "framework_version",
        "total",
        "passed",
        "failed",
        "skipped",
        "pending",
        "tests",
    }

    missing_fields = sorted(required_fields - data.keys())

    if missing_fields:
        return f"Missing required field(s): {', '.join(missing_fields)}"

    if data["schema_version"] != SUPPORTED_SCHEMA_VERSION:
        return (
            f"Unsupported schema_version: {data['schema_version']} "
            f"(expected {SUPPORTED_SCHEMA_VERSION})"
        )

    if data["framework"] != "Pester":
        return f"Unsupported framework: {data['framework']}"

    count_fields = ["total", "passed", "failed", "skipped", "pending"]

    for field in count_fields:
        value = data[field]

        if not isinstance(value, int) or isinstance(value, bool):
            return f"{field} must be an integer."

        if value < 0:
            return f"{field} cannot be negative."

    tests = data["tests"]

    if not isinstance(tests, list):
        return "tests must be a list."

    if not tests:
        return "Pester evidence contains zero tests."

    if data["total"] != len(tests):
        return (
            f"total count mismatch: evidence says {data['total']} "
            f"but tests contains {len(tests)} record(s)."
        )

    if (
        data["passed"]
        + data["failed"]
        + data["skipped"]
        + data["pending"]
        != data["total"]
    ):
        return "Pester summary counts do not equal total."

    required_test_fields = {
        "name",
        "describe",
        "context",
        "result",
        "passed",
        "duration_ms",
        "failure_message",
    }

    passed_records = 0
    failed_records = 0

    for index, test in enumerate(tests, start=1):
        if not isinstance(test, dict):
            return f"Test record {index} must be an object."

        missing_test_fields = sorted(required_test_fields - test.keys())

        if missing_test_fields:
            return (
                f"Test record {index} missing required field(s): "
                f"{', '.join(missing_test_fields)}"
            )

        if not isinstance(test["name"], str) or not test["name"].strip():
            return f"Test record {index} has an invalid name."

        if test["result"] not in {"Passed", "Failed", "Skipped", "Pending"}:
            return (
                f"Test record {index} has unsupported result: "
                f"{test['result']}"
            )

        if not isinstance(test["passed"], bool):
            return f"Test record {index} passed must be boolean."

        if test["result"] == "Passed":
            if test["passed"] is not True:
                return f"Test record {index} has inconsistent PASS state."
            passed_records += 1

        elif test["result"] == "Failed":
            if test["passed"] is not False:
                return f"Test record {index} has inconsistent FAIL state."
            failed_records += 1

    if passed_records != data["passed"]:
        return (
            f"passed count mismatch: summary says {data['passed']} "
            f"but records contain {passed_records}."
        )

    if failed_records != data["failed"]:
        return (
            f"failed count mismatch: summary says {data['failed']} "
            f"but records contain {failed_records}."
        )

    return None


def print_summary(data):
    print("Pester QE Summary")
    print("-----------------")
    print(f"Framework: {data['framework']} {data['framework_version']}")
    print(f"Schema:    {data['schema_version']}")
    print(f"Total:     {data['total']}")
    print(f"Passed:    {data['passed']}")
    print(f"Failed:    {data['failed']}")
    print(f"Skipped:   {data['skipped']}")
    print(f"Pending:   {data['pending']}")
    print()

    for test in data["tests"]:
        marker = "PASS" if test["result"] == "Passed" else test["result"].upper()
        print(f"[{marker}] {test['name']}")

        if test["result"] == "Failed" and test["failure_message"]:
            print(f"       {test['failure_message']}")


def main():
    if len(sys.argv) != 2:
        print("Usage: pester_report.py <pester-results.json>")
        return ERROR

    report_path = Path(sys.argv[1])

    data = load_evidence(report_path)

    validation_error = validate_evidence(data)

    if validation_error:
        return evidence_error(validation_error)

    print_summary(data)

    if data["failed"] > 0:
        print()
        print("Overall Result")
        print("FAIL")
        return FAIL

    print()
    print("Overall Result")
    print("PASS")
    return PASS


if __name__ == "__main__":
    sys.exit(main())
