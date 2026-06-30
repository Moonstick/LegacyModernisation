# Phase 4 — Redis-backed session

Builds on Phase 3's App Service + Azure SQL Database + Blob Storage + Key Vault + monitoring stack and additionally swaps ASP.NET Core's session backing store from in-memory to **Azure Cache for Redis**. This is the fix for the "Recently Viewed" session-consistency bug that has been present (and demonstrable) since Phase 1: with in-memory session, each App Service instance keeps its own copy of session state, so a request that lands on a different instance than the one that set the session value sees a stale/empty list.

`Storage:Provider` stays `AzureBlob` (same as Phase 3 — this phase does not regress that fix).

## What this deploys

- `infra/modules/app-service` — same Linux Web App on an autoscaling App Service Plan as Phase 2/3.
- `infra/modules/sql-database` — same Azure SQL Database (PaaS) as Phase 2/3.
- `infra/modules/storage-account` — same Blob Storage account/container as Phase 3, for claim attachments.
- `infra/modules/redis` — **new**: Azure Cache for Redis (Standard SKU by default, for primary/replica HA — demonstrates the managed-HA story better than Basic). TLS-only (`enable_non_ssl_port = false`); its `connection_string` output is already formatted for `StackExchange.Redis` (`hostname:port,password=...,ssl=True,abortConnect=False`).
- `infra/modules/key-vault` — now holds three secrets: `ClaimsDb-ConnectionString`, `Storage-ConnectionString`, and `Redis-ConnectionString`. All three are wired into the web app as [App Service Key Vault references](https://learn.microsoft.com/azure/app-service/app-service-key-vault-references) (`@Microsoft.KeyVault(SecretUri=...)`), resolved by the platform via the web app's system-assigned managed identity — **no app code change was needed**.
- `infra/modules/monitoring` — Log Analytics workspace + Application Insights, same as Phase 2/3.

`Program.cs` already supports this: it reads `Redis:ConnectionString` from configuration, and calls `AddStackExchangeRedisCache` when it's non-empty, falling back to `AddDistributedMemoryCache` otherwise. Setting the `Redis__ConnectionString` app setting (App Service's double-underscore convention for `:` in config keys) to a Key Vault reference is the only change needed to flip that switch — this is infra-only.

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
cd ../../loadtest/phase-4-redis-session
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run stress-to-failure.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run consistency-check.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run session-consistency-check.js
```

**Expect:** `consistency-check.js` (file upload/download) should still pass cleanly here — storage stays on Blob, same as Phase 3. `session-consistency-check.js` is new for this phase: it visits Details for two seeded claims back-to-back and then asserts the "Recently Viewed" list reflects both across requests. That assertion is flaky/fails on Phases 0-3 (in-memory, per-instance session — autoscaling or the load balancer can route consecutive requests to different instances) and should pass reliably here, since every instance now reads/writes the same Redis cache.

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```
