# Phase 3 — Blob storage

Same compute/data tier as Phase 2 (Linux App Service autoscale, Azure SQL Database, Key Vault, monitoring), but file attachments move off App Service local disk onto an **Azure Storage Account (Blob)**. This is the architectural fix for the upload/download consistency bug Phases 0-2 deliberately demonstrate: every App Service instance now reads and writes the same Blob container instead of its own ephemeral disk.

**No app code changes are needed or wanted for this phase.** `Program.cs` already selects `AzureBlobFileStorageService` whenever `Storage:Provider` is `AzureBlob`, and that service already reads `Storage:AzureBlob:ConnectionString` (required) and `Storage:AzureBlob:ContainerName` (defaults to `attachments`) from configuration. Flipping the provider is purely a Terraform/config change.

## What this deploys

- `infra/modules/app-service` — a Linux Web App on an autoscaling App Service Plan (1-3 instances, scales on CPU). Same as Phase 2.
- `infra/modules/sql-database` — Azure SQL Database (PaaS), firewall-opened to other Azure services. Same as Phase 2.
- `infra/modules/storage-account` — a Storage Account with a private `attachments` blob container, used by every App Service instance for claim file attachments.
- `infra/modules/key-vault` — holds two secrets: the SQL connection string and the Storage Account connection string. Both are wired into the web app as [App Service Key Vault references](https://learn.microsoft.com/azure/app-service/app-service-key-vault-references) (`@Microsoft.KeyVault(SecretUri=...)`), resolved by the platform via the web app's system-assigned managed identity — **no code change was needed** to read either secret.
- `infra/modules/monitoring` — Log Analytics workspace + Application Insights; its connection string is wired into `APPLICATIONINSIGHTS_CONNECTION_STRING`.

`Storage__Provider` flips to `AzureBlob` (from `Local` in Phases 0-2). `Redis__ConnectionString` stays empty — session state is fixed in Phase 4.

## Deploying

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id, tenant_id, sql_admin_password
az login
./deploy.sh
```

`deploy.sh` runs `terraform apply`, then `dotnet publish` + `az webapp deploy` (zip deploy), then polls `/health`.

If the app's very first boot fails to resolve a Key Vault reference (the access policy can finish propagating slightly after the web app's first start), restart it once: `az webapp restart --resource-group <rg> --name <app>`.

## Load testing

```bash
cd ../../loadtest/phase-3-blob-storage
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-3-blob-storage k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-3-blob-storage k6 run stress-to-failure.js
```

**Expect:** `smoke.js` and `stress-to-failure.js` behave the same as Phase 2 — blob storage doesn't change compute capacity, so autoscaling still smooths the hard ceiling seen in Phase 0/1. The interesting result is `consistency-check.js`: it uploads a file via one request and immediately tries to download it via a follow-up request, which can land on a different App Service instance once autoscaling has more than one running. In Phases 0-2 this fails intermittently because uploads land on local disk; in Phase 3 every instance reads/writes the same Blob container, so **this should now pass cleanly** regardless of which instance serves which request.

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```

Everything this phase creates (resource group, App Service Plan/Web App, SQL logical server/database, Storage Account/container, Key Vault, Log Analytics workspace/Application Insights) lives in this phase's own Terraform state and resource group — `teardown.sh` removes all of it and nothing outside of it.
