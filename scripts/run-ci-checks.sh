#!/usr/bin/env bash

set -euo pipefail

echo "========================================"
echo "Windows Server QE CI Checks"
echo "========================================"
echo

echo "[1/4] Checking Python syntax..."
python -m py_compile \
  scripts/qe_report.py \
  scripts/infrastructure_report.py
echo "PASS: Python syntax"
echo

echo "[2/4] Checking Bash syntax..."
bash -n scripts/run-qe-validation.sh
bash -n scripts/run-srv01-validation.sh
bash -n scripts/run-preflight.sh
bash -n scripts/run-infrastructure-validation.sh
bash -n scripts/run-infrastructure-negative-test.sh
bash -n scripts/run-qe-negative-test.sh
bash -n scripts/run-qe-missing-report-test.sh
bash -n scripts/test-qe-harness.sh
bash -n scripts/run-ci-checks.sh
echo "PASS: Bash syntax"
echo

echo "[3/4] Checking Ansible playbook syntax..."

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/dc01-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-negative-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-identity-negative-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-time-negative-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-network-negative-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-defender-negative-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-event-health-negative-validation-suite.yml \
  --syntax-check \
  --ask-vault-password

echo "PASS: Ansible syntax"
echo

echo "[4/4] Running QE harness self-tests..."
./scripts/test-qe-harness.sh
echo

echo "========================================"
echo "ALL CI CHECKS PASSED"
echo "========================================"
