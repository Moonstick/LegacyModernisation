#!/usr/bin/env bash
# Deploys Phase 0 (single VM, web + SQL Server co-located) and waits for the
# app's health check to go green. cloud-init does all the app deployment work
# on first boot -- this script just provisions the VM and polls.
set -euo pipefail
cd "$(dirname "$0")"

terraform init
terraform apply -auto-approve

VM_IP=$(terraform output -raw vm_public_ip)
echo "VM provisioned at ${VM_IP}. Waiting for cloud-init to install SQL Server, .NET, and publish the app..."
echo "This can take 5-10 minutes on first boot."

for i in $(seq 1 60); do
  if curl -sf "http://${VM_IP}/health" >/dev/null 2>&1; then
    echo "App is healthy: http://${VM_IP}/"
    exit 0
  fi
  sleep 15
done

echo "Timed out waiting for http://${VM_IP}/health to go green." >&2
echo "SSH in and check 'cloud-init status' / 'journalctl -u claims-app' for details." >&2
exit 1
