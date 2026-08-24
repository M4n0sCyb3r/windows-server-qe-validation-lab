#!/usr/bin/env bash

set -e

echo "Running SRV01 QE validation workflow..."
echo

echo "[1/2] Running Ansible validation..."
ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/srv01-validation-suite.yml \
  --ask-vault-password

echo
echo "[2/2] Running Python QE report..."
python scripts/qe_report.py reports/srv01-qe-results.json

echo
echo "SRV01 QE validation workflow completed successfully."
