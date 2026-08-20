import json
import sys

DEFAULT_REPORT_FILE = "reports/dc01-qe-results.json"

if len(sys.argv) > 1:
    report_file = sys.argv[1]
else:
    report_file = DEFAULT_REPORT_FILE

with open(report_file, "r", encoding="utf-8") as file:
    results = json.load(file)

total_tests = len(results)

passed_results = [
    test for test in results
    if test["result"] == "PASS"
]

failed_results = [
    test for test in results
    if test["result"] == "FAIL"
]

print("DC01 QE Validation Report")
print("-------------------------")
print(f"Report file:  {report_file}")
print(f"Total tests:  {total_tests}")
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

if failed_results:
    sys.exit(1)

sys.exit(0)
