#!/usr/bin/env bash
# Deploys Phase 1 (two web VMs behind a load balancer, SQL Server on its own
# VM) and waits for the load balancer's health probe path to go green.
# cloud-init does all the app/DB deployment work on first boot -- this
# script just provisions the infra and polls.
set -euo pipefail
cd "$(dirname "$0")"

terraform init
terraform apply -auto-approve

LB_IP=$(terraform output -raw lb_public_ip)
echo "Load balancer provisioned at ${LB_IP}. Waiting for both web VMs' cloud-init to finish (.NET SDK install, publish, app start) and for the DB VM to finish installing SQL Server..."
echo "This can take 5-10 minutes on first boot."

for i in $(seq 1 60); do
  if curl -sf "http://${LB_IP}/health" >/dev/null 2>&1; then
    echo "App is healthy: http://${LB_IP}/"
    exit 0
  fi
  sleep 15
done

echo "Timed out waiting for http://${LB_IP}/health to go green." >&2
echo "Web VMs have no public IP of their own (all traffic arrives via the load balancer); check the Azure Portal's 'Boot diagnostics' or temporarily attach a public IP to a web NIC to SSH in and check 'cloud-init status' / 'journalctl -u claims-app'." >&2
echo "The DB VM does have a public IP -- SSH there directly to check 'systemctl status mssql-server'." >&2
exit 1
