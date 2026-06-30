#!/usr/bin/env bash
# Provisions Phase 6's full multi-region stack (two regional App
# Service/Key Vault/Monitoring/Redis stacks, a primary/secondary SQL
# Managed Instance failover group, one shared RA-GRS storage account, and
# Front Door fronting both regions), then publishes and zip-deploys the app
# to BOTH regional App Services, then polls the Front Door endpoint's
# /health. Unlike the VM phases, App Service has no cloud-init -- Terraform
# only creates the empty Web Apps, so deploy.sh does the `dotnet publish` +
# `az webapp deploy` step itself, once per region.
set -euo pipefail
cd "$(dirname "$0")"

terraform init
terraform apply -auto-approve

RG_NAME=$(terraform output -raw resource_group_name)
PRIMARY_APP_NAME=$(terraform output -raw primary_app_service_name)
SECONDARY_APP_NAME=$(terraform output -raw secondary_app_service_name)
PRIMARY_APP_URL=$(terraform output -raw primary_app_url)
SECONDARY_APP_URL=$(terraform output -raw secondary_app_url)
FRONT_DOOR_URL=$(terraform output -raw front_door_hostname)

PUBLISH_DIR="$(mktemp -d)"
trap 'rm -rf "$PUBLISH_DIR"' EXIT

echo "Publishing the app..."
(cd ../../src/ClaimsCaseManagement && dotnet publish -c Release -o "$PUBLISH_DIR")

ZIP_PATH="$(mktemp -u).zip"
(cd "$PUBLISH_DIR" && zip -rq "$ZIP_PATH" .)

echo "Zipping and deploying to primary region (${PRIMARY_APP_NAME})..."
az webapp deploy --resource-group "$RG_NAME" --name "$PRIMARY_APP_NAME" --src-path "$ZIP_PATH" --type zip

echo "Zipping and deploying to secondary region (${SECONDARY_APP_NAME})..."
az webapp deploy --resource-group "$RG_NAME" --name "$SECONDARY_APP_NAME" --src-path "$ZIP_PATH" --type zip

rm -f "$ZIP_PATH"

wait_for_health() {
  local label="$1"
  local url="$2"
  echo "Waiting for ${label} (${url}/health) ..."
  for i in $(seq 1 30); do
    if curl -sf "${url}/health" >/dev/null 2>&1; then
      echo "${label} is healthy: ${url}"
      return 0
    fi
    sleep 10
  done
  echo "Timed out waiting for ${label} (${url}/health) to go green." >&2
  return 1
}

PRIMARY_OK=0
SECONDARY_OK=0
wait_for_health "Primary region" "$PRIMARY_APP_URL" || PRIMARY_OK=1
wait_for_health "Secondary region" "$SECONDARY_APP_URL" || SECONDARY_OK=1

if [[ "$PRIMARY_OK" -ne 0 || "$SECONDARY_OK" -ne 0 ]]; then
  echo "One or both regional App Services did not report healthy. Check 'az webapp log tail" >&2
  echo "--resource-group ${RG_NAME} --name <app>' for details. Note: the *-ConnectionString" >&2
  echo "app settings are Key Vault references -- if an access policy hadn't finished" >&2
  echo "propagating by an app's first boot, restart it once with 'az webapp restart" >&2
  echo "--resource-group ${RG_NAME} --name <app>'." >&2
  exit 1
fi

# Front Door's endpoint is newly created by this same apply, and global
# propagation of a brand-new Front Door endpoint/route can take several
# minutes even after the control-plane operation completes -- so this loop
# is intentionally more patient than the per-region health checks above.
echo "Waiting for Front Door global endpoint (${FRONT_DOOR_URL}/health) -- first-time"
echo "propagation across Front Door's edge network can take a few minutes, this is normal..."
for i in $(seq 1 60); do
  if curl -sf "${FRONT_DOOR_URL}/health" >/dev/null 2>&1; then
    echo "Front Door is routing traffic and healthy: ${FRONT_DOOR_URL}"
    exit 0
  fi
  sleep 10
done

echo "Timed out waiting for ${FRONT_DOOR_URL}/health to go green." >&2
echo "Both regional App Services reported healthy directly, so this is most likely Front" >&2
echo "Door endpoint propagation still in progress rather than an app problem -- try again" >&2
echo "in a few minutes with: curl -sf ${FRONT_DOOR_URL}/health" >&2
exit 1
