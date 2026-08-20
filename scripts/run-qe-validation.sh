#!/usr/bin/env bash

set -e

echo "Running DC01 Windows Server QE validation..."
echo

ansible-playbook \
  -i inventory/hosts.yml \
  playbooks/dc01-validation-suite.yml \
  --ask-vault-password

echo
echo "Generating QE report..."
echo

python scripts/qe_report.py
