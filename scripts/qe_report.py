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


def evidence_error(message):
    print("ERROR: QE evidence is invalid")
    print(f"  {message}")
    sys.exit(EXIT_ERROR)


def validate_results(results):
    if not isinstance(results, list):
        evidence_error(
            "Results structure must be a JSON list"
        )

    if not results:
        evidence_error(
            "Report contains zero test results"
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


def validate_scope_list(field_name, scopes):
    if not isinstance(scopes, list):
        evidence_error(
            f"'{field_name}' must be a JSON list"
        )

    for index, scope in enumerate(scopes):
        if not isinstance(scope, str) or not scope.strip():
            evidence_error(
                f"'{field_name}' contains an invalid scope at index {index}"
            )

    if len(scopes) != len(set(scopes)):
        evidence_error(
            f"'{field_name}' contains duplicate scopes"
        )


def parse_evidence(data):
    # Legacy list evidence remains supported for backward compatibility.
    if isinstance(data, list):
        validate_results(data)

        return {
            "format": "legacy",
            "schema_version": None,
            "requested_scopes": None,
            "completed_scopes": None,
            "results": data,
        }

    if not isinstance(data, dict):
        evidence_error(
            "Top-level report structure must be a JSON list "
            "or coverage evidence object"
        )

    if "schema_version" not in data:
        evidence_error(
            "Missing required field: schema_version"
        )

    if data["schema_version"] != COVERAGE_SCHEMA_VERSION:
        evidence_error(
            f"Unsupported schema_version: {data['schema_version']}"
        )

    required_envelope_fields = {
        "requested_scopes",
        "completed_scopes",
        "results",
    }

    missing_fields = required_envelope_fields - set(data.keys())

    if missing_fields:
        missing = ", ".join(sorted(missing_fields))
        evidence_error(
            f"Coverage evidence is missing required field(s): {missing}"
        )

    requested_scopes = data["requested_scopes"]
    completed_scopes = data["completed_scopes"]
    results = data["results"]

    validate_scope_list(
        "requested_scopes",
        requested_scopes,
    )

    validate_scope_list(
        "completed_scopes",
        completed_scopes,
    )

    if not requested_scopes:
        evidence_error(
            "Coverage evidence contains zero requested scopes"
        )

    validate_results(results)

    return {
        "format": "coverage",
        "schema_version": data["schema_version"],
        "requested_scopes": requested_scopes,
        "completed_scopes": completed_scopes,
        "results": results,
    }


default_report = "reports/dc01-qe-results.json"
report_file = sys.argv[1] if len(sys.argv) > 1 else default_report

if not os.path.exists(report_file):
    print("ERROR: Expected report file was not created:")
    print(f"  {report_file}")
    sys.exit(EXIT_ERROR)

try:
    with open(report_file, "r", encoding="utf-8") as file:
        data = json.load(file)
except json.JSONDecodeError as error:
    evidence_error(
        f"Report contains invalid JSON: {error}"
    )
except OSError as error:
    evidence_error(
        f"Report could not be read: {error}"
    )

evidence = parse_evidence(data)
results = evidence["results"]

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

if evidence["format"] == "coverage":
    requested = set(evidence["requested_scopes"])
    completed = set(evidence["completed_scopes"])

    print(f"Schema version: {evidence['schema_version']}")
    print(f"Requested scopes: {len(requested)}")
    print(f"Completed scopes: {len(completed)}")

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

# Coverage metadata integrity is checked before configuration FAIL
# semantics. Invalid coverage metadata makes the evidence untrustworthy.

if evidence["format"] == "coverage":
    requested = set(evidence["requested_scopes"])
    completed = set(evidence["completed_scopes"])

    unexpected = completed - requested

    if unexpected:
        print("ERROR")
        print(
            "Completed scopes were not part of the requested validation scope"
        )
        print(
            "Unexpected scopes: "
            + ", ".join(sorted(unexpected))
        )
        sys.exit(EXIT_ERROR)

# A trustworthy structured configuration failure remains FAIL even if
# later requested scopes did not complete because the suite is fail-fast.

if failed_results:
    print("FAIL")
    sys.exit(EXIT_FAIL)

# If there was no trustworthy configuration FAIL, every requested scope
# must have completed before the evidence can produce PASS.

if evidence["format"] == "coverage":
    requested = set(evidence["requested_scopes"])
    completed = set(evidence["completed_scopes"])

    missing = requested - completed

    if missing:
        print("ERROR")
        print("QE evidence coverage is incomplete")
        print(
            "Requested scopes: "
            + ", ".join(sorted(requested))
        )
        print(
            "Completed scopes: "
            + (
                ", ".join(sorted(completed))
                if completed
                else "(none)"
            )
        )
        print(
            "Missing scopes: "
            + ", ".join(sorted(missing))
        )
        sys.exit(EXIT_ERROR)

print("PASS")
sys.exit(EXIT_PASS)
