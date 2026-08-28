#!/usr/bin/env bash

set -u

vault_file="inventory/group_vars/windows.yml"
inventory_file="inventory/hosts.yml"
vault_password_file="$(mktemp)"

dc01_exit=0
srv01_exit=0
preflight_failed=0

cleanup() {
    rm -f "$vault_password_file"
}

trap cleanup EXIT

echo "========================================"
echo "Windows Server QE Preflight"
echo "========================================"
echo

echo "[1/4] Checking required local files..."

if [[ ! -f "$inventory_file" ]]; then
    echo "ERROR: Missing inventory file: $inventory_file"
    preflight_failed=1
else
    echo "PASS: Inventory file exists"
fi

if [[ ! -f "$vault_file" ]]; then
    echo "ERROR: Missing local vault file: $vault_file"
    preflight_failed=1
else
    echo "PASS: Local vault file exists"
fi

echo

if [[ "$preflight_failed" -ne 0 ]]; then
    echo "Preflight Result: ERROR"
    exit 2
fi

echo "Enter Ansible Vault password:"
read -r -s vault_password
echo

printf '%s\n' "$vault_password" > "$vault_password_file"
chmod 600 "$vault_password_file"
unset vault_password

echo "[2/4] Checking Ansible inventory..."

ansible-inventory \
  -i "$inventory_file" \
  --list \
  --vault-password-file "$vault_password_file" > /dev/null

inventory_exit=$?

if [[ "$inventory_exit" -eq 0 ]]; then
    echo "PASS: Inventory parses successfully"
else
    echo "ERROR: Inventory parsing failed"
    exit 2
fi

echo

echo "[3/4] Checking DC01 connectivity..."

ansible dc01 \
  -i "$inventory_file" \
  -m ansible.windows.win_ping \
  --vault-password-file "$vault_password_file"

dc01_exit=$?

echo

echo "[4/4] Checking SRV01 connectivity..."

ansible srv01 \
  -i "$inventory_file" \
  -m ansible.windows.win_ping \
  --vault-password-file "$vault_password_file"

srv01_exit=$?

echo
echo "========================================"
echo "Preflight Summary"
echo "========================================"

if [[ "$dc01_exit" -eq 0 ]]; then
    echo "DC01   PASS"
else
    echo "DC01   ERROR  exit=$dc01_exit"
fi

if [[ "$srv01_exit" -eq 0 ]]; then
    echo "SRV01  PASS"
else
    echo "SRV01  ERROR  exit=$srv01_exit"
fi

echo

if [[ "$dc01_exit" -eq 0 && "$srv01_exit" -eq 0 ]]; then
    echo "Preflight Result: PASS"
    exit 0
fi

echo "Preflight Result: ERROR"
exit 2

