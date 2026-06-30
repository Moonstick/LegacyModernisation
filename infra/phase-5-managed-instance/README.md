# Phase 5 — SQL Managed Instance HA/DR

The database moves from Azure SQL Database (PaaS, Phases 2-4) to **Azure SQL Managed Instance** with an **auto-failover group** pairing a primary instance (`var.location`, default `uksouth`) with a secondary instance (`var.secondary_location`, default `ukwest`) for disaster recovery. This phase is entirely about the database HA/DR story — it does not change app code at all, and nothing else in the architecture moves:

- App Service stays **single-region** (multi-region app tier is Phase 6's job, not this one).
- Blob storage and Redis session stay exactly as wired in Phases 3/4 — single region, unchanged.
- The only thing that changes is `ConnectionStrings__ClaimsDb`, which now points at the primary Managed Instance instead of the old SQL Database logical server.

## What this deploys

- `infra/modules/network` x2 — SQL Managed Instance is a regional resource and needs its own VNet in that region, so this phase creates two separate VNets: one in the primary region, one in the secondary region. Each has a single `mi` subnet delegated to `Microsoft.Sql/managedInstances`. Per Azure's rules, a subnet delegated to Managed Instance must otherwise be empty, so nothing else is placed in either VNet.
- `infra/modules/sql-managed-instance` x2 — the primary instance is created with `enable_failover_group = true` and `partner_managed_instance_id` pointing at the secondary; the secondary is created plain (`enable_failover_group = false`). The failover group uses the module's default automatic read-write failover policy.
- `infra/modules/storage-account`, `infra/modules/redis` — identical to Phase 4: blob storage for attachments, Redis for session state. Single region (primary), unchanged.
- `infra/modules/app-service` — same Linux Web App pattern as every PaaS phase. Still single-region.
- `infra/modules/key-vault` — holds all three connection strings (`ClaimsDb`, `Storage`, `Redis`), each exposed to the app via an App Service Key Vault reference, exactly as in Phases 2-4. No code change needed.
- `infra/modules/monitoring` — unchanged pattern.
- A single resource group (`rg-claims-phase5-<suffix>`) contains everything in **both** regions — resource groups aren't region-locked, only VNets/subnets are.

## Known limitations (read this before deploying)

### 1. Public data endpoint, not private VNet integration

A production-grade version of this architecture would put App Service on **regional VNet integration** so it could reach the Managed Instance privately over port 1433, inside the MI's own VNet (or a peered one). The shared `infra/modules/app-service` module in this repo **does not currently expose a VNet integration variable** (checked `variables.tf` — there is none), and per this phase's scope, the shared module must not be modified to add one.

As a documented simplification — in the same spirit as the Phase 0/1 "open to source `*`" NSG rules elsewhere in this repo — this phase instead has the app connect to the Managed Instance's **public data endpoint** on **port 3342**. The connection string is built in `main.tf`'s `locals` block from the primary instance's `fqdn` output, with a comment marking this choice and the limitation it implies.

**This means a real `terraform apply` of this phase will not actually let the app connect to the database out of the box.** `azurerm_mssql_managed_instance` defaults `public_data_endpoint_enabled` to `false`, and `infra/modules/sql-managed-instance` doesn't expose a toggle for it (it's a shared, frozen module — extending it is out of scope for this phase). A real deployment would need that endpoint enabled — by extending the shared module in a follow-up change — before the connection string above would resolve to anything reachable. This is named here explicitly rather than worked around silently.

### 2. MI subnet NSG rules are incomplete by design

The shared `network` module attaches a default-deny NSG to every subnet it creates, including the `mi` subnet. This phase adds exactly one rule to each MI subnet's NSG: inbound TCP/3342 from `*`, matching the public-endpoint simplification above. Azure SQL Managed Instance also requires several **management-plane** NSG rules (outbound/inbound access to Azure Active Directory, Azure Storage, and the Microsoft Sql Management endpoints, typically on ports 443 and 12000) for the platform's own control-plane health checks and operations — those are **not modeled here**. Getting them wrong would be worse than not guessing, so this is called out as a limitation rather than a best-effort set of rules. See [Microsoft's NSG traffic requirements for Managed Instance](https://learn.microsoft.com/azure/azure-sql/managed-instance/connectivity-architecture-overview) if you're deploying this for real.

### 3. Connection string targets the primary instance directly, not the failover group listener

The connection string in Key Vault is built from `module.sql_mi_primary.fqdn` (the primary instance's own DNS name), not from the failover group's listener endpoint. In a real failover, traffic to the failover group's own DNS name would redirect transparently to whichever instance is now primary; pointing directly at the primary instance's `fqdn` means a failover would require updating the Key Vault secret (or re-pointing DNS) by hand. This keeps the example's connection-string wiring symmetric with the `sql-database` module's pattern in earlier phases, but it's worth knowing this is not how you'd want it wired in production. The auto-failover group resource is still created and does its job for the instances themselves — only the app's *discovery* of the current primary is simplified.

## Provisioning time

**Azure SQL Managed Instance provisioning takes 4-6 hours per instance** (see the comment at the top of `infra/modules/sql-managed-instance/main.tf`). This phase creates two of them. `terraform apply` (and therefore `./deploy.sh`) will block for the whole window — do not expect this to finish quickly, and don't assume a hung-looking `apply` has failed.

## Deploying

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id, tenant_id, sql_admin_password
az login
./deploy.sh
```

`deploy.sh` runs `terraform apply` (expect 4-6+ hours for the two Managed Instances and the failover group to finish provisioning), then `dotnet publish` + `az webapp deploy` (zip deploy), then polls `/health`. Given the public-data-endpoint limitation above, expect `/health` to fail to go fully green against a real subscription unless you've separately enabled the public endpoint (or extended the module to do VNet integration) — `deploy.sh` prints a reminder of this if the health check times out.

If the app's very first boot fails to resolve a Key Vault reference (the access policy can finish propagating slightly after the web app's first start), restart it once: `az webapp restart --resource-group <rg> --name <app>`.

## Load testing

```bash
cd ../../loadtest/phase-5-managed-instance
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-5-managed-instance k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-5-managed-instance k6 run stress-to-failure.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-5-managed-instance k6 run consistency-check.js
```

**Expect:** the same throughput/latency/consistency story as Phase 4 under normal operation — App Service and the storage/session tiers are unchanged, so `smoke.js`, `stress-to-failure.js`, and `consistency-check.js` should all behave identically to Phase 4's runs. This phase's upgrade is about DR, not throughput, so the k6 scripts aren't expected to show anything new.

The interesting test for this phase is a **manual failover drill**, which is out of scope for k6 and is not scripted:

```bash
az sql instance-failover-group set-primary \
  --name <failover-group-name> \
  --resource-group <rg> \
  --server <secondary-instance-name>
```

Run this by hand to promote the secondary instance to primary and observe the app's behavior (and, given limitation #3 above, that the app keeps talking to the old primary's `fqdn` until the Key Vault secret/connection string is updated to point at the new primary — that's the practical consequence of the simplified connection-string wiring called out above).

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```

Tears down everything in this phase's single resource group, including both regions' VNets and both Managed Instances.
