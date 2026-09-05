#!/usr/bin/env python3

import json
import os
import sys


EXIT_PASS = 0
EXIT_FAIL = 1
EXIT_ERROR = 2

COVERAGE_SCHEMA_VERSION = 2

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


def validate_result_items(host, results):
    errors = []

    if not isinstance(results, list):
        errors.append(
            f"{host}: results structure must be a JSON list"
        )
        return errors

    if not results:
        errors.append(
            f"{host}: report contains zero test results"
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


def validate_scope_list(host, field_name, scopes):
    errors = []

    if not isinstance(scopes, list):
        errors.append(
            f"{host}: '{field_name}' must be a JSON list"
        )
        return errors

    valid_string_scopes = []

    for index, scope in enumerate(scopes):
        if not isinstance(scope, str) or not scope.strip():
            errors.append(
                f"{host}: '{field_name}' contains "
                f"an invalid scope at index {index}"
            )
            continue

        valid_string_scopes.append(scope)

    if len(valid_string_scopes) != len(set(valid_string_scopes)):
        errors.append(
            f"{host}: '{field_name}' contains duplicate scopes"
        )

    return errors


def parse_evidence(host, data):
    # Legacy list evidence remains supported for backward compatibility.
    if isinstance(data, list):
        errors = validate_result_items(host, data)

        if errors:
            return None, errors

        return {
            "format": "legacy",
            "schema_version": None,
            "requested_scopes": None,
            "completed_scopes": None,
            "results": data,
        }, []

    if not isinstance(data, dict):
        return None, [
            f"{host}: top-level report structure must be a JSON list "
            "or coverage evidence object"
        ]

    if "schema_version" not in data:
        return None, [
            f"{host}: Missing required field: schema_version"
        ]

    if data["schema_version"] != COVERAGE_SCHEMA_VERSION:
        return None, [
            f"{host}: Unsupported schema_version: "
            f"{data['schema_version']}"
        ]

    required_envelope_fields = {
        "requested_scopes",
        "completed_scopes",
        "results",
    }

    missing_fields = required_envelope_fields - set(data.keys())

    if missing_fields:
        missing = ", ".join(sorted(missing_fields))
        return None, [
            f"{host}: coverage evidence is missing "
            f"required field(s): {missing}"
        ]

    requested_scopes = data["requested_scopes"]
    completed_scopes = data["completed_scopes"]
    results = data["results"]

    errors = []

    errors.extend(
        validate_scope_list(
            host,
            "requested_scopes",
            requested_scopes,
        )
    )

    errors.extend(
        validate_scope_list(
            host,
            "completed_scopes",
            completed_scopes,
        )
    )

    if isinstance(requested_scopes, list) and not requested_scopes:
        errors.append(
            f"{host}: Coverage evidence contains zero requested scopes"
        )

    errors.extend(
        validate_result_items(
            host,
            results,
        )
    )

    if errors:
        return None, errors

    return {
        "format": "coverage",
        "schema_version": data["schema_version"],
        "requested_scopes": requested_scopes,
        "completed_scopes": completed_scopes,
        "results": results,
    }, []


def load_report(host, report_file):
    if not os.path.exists(report_file):
        print(f"{host:<6} ERROR  report missing")
        return None, "ERROR"

    try:
        with open(report_file, "r", encoding="utf-8") as file:
            data = json.load(file)
    except json.JSONDecodeError as error:
        print(f"{host:<6} ERROR  invalid JSON")
        print(f"       {error}")
        return None, "ERROR"
    except OSError as error:
        print(f"{host:<6} ERROR  report unreadable")
        print(f"       {error}")
        return None, "ERROR"

    evidence, validation_errors = parse_evidence(
        host,
        data,
    )

    if validation_errors:
        print(f"{host:<6} ERROR  invalid evidence")

        for error in validation_errors:
            print(f"       {error}")

        return None, "ERROR"

    results = evidence["results"]

    passed = sum(
        1
        for test in results
        if test["result"] == "PASS"
    )

    failed = sum(
        1
        for test in results
        if test["result"] == "FAIL"
    )

    total = len(results)

    # Coverage metadata integrity is checked before configuration FAIL
    # semantics. Unexpected completed scopes make evidence untrustworthy.
    if evidence["format"] == "coverage":
        requested = set(evidence["requested_scopes"])
        completed = set(evidence["completed_scopes"])

        unexpected = completed - requested

        if unexpected:
            print(f"{host:<6} ERROR  invalid coverage")
            print(
                "       Unexpected scopes: "
                + ", ".join(sorted(unexpected))
            )
            return evidence, "ERROR"

    # A trustworthy structured configuration failure remains FAIL even
    # when later requested scopes did not complete because of fail-fast.
    if failed > 0:
        print(
            f"{host:<6} FAIL  "
            f"tests={total} passed={passed} failed={failed}"
        )
        return evidence, "FAIL"

    # Without a configuration FAIL, complete requested coverage is
    # required before a host can be considered PASS.
    if evidence["format"] == "coverage":
        requested = set(evidence["requested_scopes"])
        completed = set(evidence["completed_scopes"])

        missing = requested - completed

        if missing:
            print(f"{host:<6} ERROR  incomplete coverage")
            print(
                "       Requested scopes: "
                + ", ".join(sorted(requested))
            )
            print(
                "       Completed scopes: "
                + (
                    ", ".join(sorted(completed))
                    if completed
                    else "(none)"
                )
            )
            print(
                "       Missing scopes: "
                + ", ".join(sorted(missing))
            )
            return evidence, "ERROR"

    print(
        f"{host:<6} PASS  "
        f"tests={total} passed={passed} failed={failed}"
    )

    return evidence, "PASS"


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
