# Phase 2 — PaaS foundations

The web tier moves off VMs onto Azure App Service (Linux, autoscaling, no OS patching), and the database moves to Azure SQL Database (PaaS). Secrets move to Key Vault; Application Insights/Log Analytics are wired in. File storage and session are still broken the same way as Phase 1 — App Service instances are ephemeral, so local-disk uploads are now *more* fragile, not less.

## What this deploys

- `infra/modules/app-service` — a Linux Web App on an autoscaling App Service Plan (1-3 instances, scales on CPU).
- `infra/modules/sql-database` — Azure SQL Database (PaaS), firewall-opened to other Azure services.
- `infra/modules/key-vault` — holds the SQL connection string. The web app's `ConnectionStrings__ClaimsDb` app setting is an [App Service Key Vault reference](https://learn.microsoft.com/azure/app-service/app-service-key-vault-references) (`@Microsoft.KeyVault(SecretUri=...)`), resolved by the platform via the web app's system-assigned managed identity — **no code change was needed** to read secrets from Key Vault.
- `infra/modules/monitoring` — Log Analytics workspace + Application Insights; its connection string is wired into `APPLICATIONINSIGHTS_CONNECTION_STRING`.

`Storage:Provider` stays `Local` and `Redis:ConnectionString` stays empty — both get fixed in Phases 3 and 4.

## Deploying

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id, tenant_id, sql_admin_password
az login
./deploy.sh
```

`deploy.sh` runs `terraform apply`, then `dotnet publish` + `az webapp deploy` (zip deploy), then polls `/health`.

If the app's very first boot fails to resolve the Key Vault reference (the access policy can finish propagating slightly after the web app's first start), restart it once: `az webapp restart --resource-group <rg> --name <app>`.

## Load testing

```bash
cd ../../loadtest/phase-2-paas-foundations
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-2-paas-foundations k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-2-paas-foundations k6 run stress-to-failure.js
```

**Expect:** autoscaling smooths out the hard capacity ceiling seen in Phase 0/1 — watch the App Service Plan scale from 1 to 3 instances under `stress-to-failure.js` and sustain meaningfully higher throughput at the same error rate. But also run `consistency-check.js`: it uploads a file via one request and immediately tries to download it on a follow-up request, which can land on a different instance once autoscaling has more than one running — this should still fail intermittently here, proving the fix has to be architectural (Phase 3), not just "more compute."

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```
