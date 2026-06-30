#!/usr/bin/env bash
# Provisions Phase 3's App Service + Azure SQL Database + Storage Account
# (Blob) + Key Vault + monitoring, then publishes and zip-deploys the app.
# Like Phase 2, App Service has no cloud-init -- Terraform only creates the
# empty Web App, so deploy.sh does the `dotnet publish` + `az webapp deploy`
# step itself. No app code changes are needed for this phase: the app
# already supports Storage:Provider=AzureBlob, it's just not selected until
# now.
set -euo pipefail
cd "$(dirname "$0")"

terraform init
terraform apply -auto-approve

APP_NAME=$(terraform output -raw app_service_name)
RG_NAME=$(terraform output -raw resource_group_name)
APP_URL=$(terraform output -raw app_url)

PUBLISH_DIR="$(mktemp -d)"
trap 'rm -rf "$PUBLISH_DIR"' EXIT

echo "Publishing the app..."
(cd ../../src/ClaimsCaseManagement && dotnet publish -c Release -o "$PUBLISH_DIR")

echo "Zipping and deploying to ${APP_NAME}..."
ZIP_PATH="$(mktemp -u).zip"
(cd "$PUBLISH_DIR" && zip -rq "$ZIP_PATH" .)
az webapp deploy --resource-group "$RG_NAME" --name "$APP_NAME" --src-path "$ZIP_PATH" --type zip
rm -f "$ZIP_PATH"

echo "Waiting for ${APP_URL}/health ..."
for i in $(seq 1 30); do
  if curl -sf "${APP_URL}/health" >/dev/null 2>&1; then
    echo "App is healthy: ${APP_URL}"
    exit 0
  fi
  sleep 10
done

echo "Timed out waiting for ${APP_URL}/health to go green." >&2
echo "Check 'az webapp log tail --resource-group ${RG_NAME} --name ${APP_NAME}' for details." >&2
echo "Note: the ConnectionStrings__ClaimsDb and Storage__AzureBlob__ConnectionString app" >&2
echo "settings are Key Vault references -- if the access policy hadn't propagated by the" >&2
echo "app's first boot, restart it once with" >&2
echo "'az webapp restart --resource-group ${RG_NAME} --name ${APP_NAME}'." >&2
exit 1
