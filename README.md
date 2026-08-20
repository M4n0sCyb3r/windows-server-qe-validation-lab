# Windows Server QE Validation Lab

A hands-on Windows Server Quality Engineering lab for building repeatable, baseline-driven infrastructure validation using PowerShell, Ansible, JSON, Python, Bash, and Git.

## Project Overview

This project validates the configuration of a Windows Server domain controller against a defined baseline.

The current lab target is `DC01` in the `corp.lab` test environment.

The validation framework follows this QE workflow:

```text
Expected Configuration
        ↓
Collect Actual Windows State
        ↓
Compare Actual vs Expected
        ↓
PASS / FAIL Assertions
        ↓
Structured QE Results
        ↓
JSON Evidence
        ↓
Python Reporting
        ↓
Automation Exit Code
```

The validation tasks are designed to be read-only whenever possible so testing does not modify the system under test.

## Current Validation Coverage

The suite currently validates:

- Windows services
  - DNS
  - NTDS
  - WinRM
  - Service existence
  - Running state
  - Automatic startup mode
- DNS client configuration
- Required Windows features
  - Active Directory Domain Services
  - DNS
- SMB signing registry configuration
- Required file existence
- Required hosts file content

## Project Structure

```text
windows-qe-lab/
├── inventory/
├── playbooks/
│   ├── dc01-validation-suite.yml
│   └── tasks/
│       ├── validate-services.yml
│       ├── validate-dns.yml
│       ├── validate-features.yml
│       ├── validate-registry.yml
│       └── validate-files.yml
├── vars/
│   ├── dc01-baseline.yml
│   └── dc01-negative-baseline.yml
├── scripts/
│   ├── qe_report.py
│   ├── run-qe-validation.sh
│   ├── run-qe-negative-test.sh
│   └── run-qe-missing-report-test.sh
└── reports/
```

## Run the Validation Workflow

From the project root:

```bash
./scripts/run-qe-validation.sh
```

The workflow:

1. Runs the Ansible validation suite against DC01.
2. Collects structured expected-vs-actual results.
3. Exports the results to JSON.
4. Processes the JSON with Python.
5. Displays a concise QE validation report.
6. Returns an automation-friendly exit code.

Example successful result:

```text
Total tests:  9
Passed:       9
Failed:       0
```

## Exit Codes

The test harness uses exit codes to distinguish different outcomes:

| Exit Code | Meaning |
|---|---|
| `0` | Validation completed successfully |
| `1` | One or more validation tests failed |
| `2` | Workflow or report-generation failure |

This allows the framework to integrate with future CI/CD or automated test systems.

## Controlled Negative Testing

The project includes controlled negative tests to verify that the reporting system detects failures correctly.

Run:

```bash
./scripts/run-qe-negative-test.sh
```

The current controlled negative test produces an intentional SMB signing mismatch and verifies that the Python reporter:

- detects the failure;
- reports expected vs actual values;
- returns exit code `1`.

A separate workflow-error test verifies missing-report handling:

```bash
./scripts/run-qe-missing-report-test.sh
```

This returns exit code `2`.

## Structured Test Results

Validation results use a consistent structure:

```json
{
    "test": "SMB Signing",
    "expected": 1,
    "actual": 1,
    "result": "PASS"
}
```

These records are collected by Ansible into `qe_results`, exported as JSON, and processed by Python.

Generated runtime reports are stored under `reports/` and excluded from Git.

## Technologies Practiced

- Windows Server
- PowerShell
- Ansible
- YAML
- JSON
- Python
- Bash
- Git
- Infrastructure validation
- Configuration baselines
- Automated testing
- Negative testing
- Expected-vs-actual comparison
- Failure propagation and exit codes
- QE troubleshooting

## Quality Engineering Principles

This lab emphasizes:

- establish the expected baseline first;
- independently collect actual system state;
- compare actual state against requirements;
- use explicit PASS/FAIL assertions;
- keep validation read-only where possible;
- distinguish system failures from test-framework failures;
- use controlled negative tests to prove failure detection;
- produce repeatable machine-readable evidence;
- preserve known-good checkpoints with Git.
