# Phase 6 — multi-region

The final phase in the modernization journey. Everything earlier in this series scaled *within* one Azure region; this phase adds a second, fully-provisioned region (`var.secondary_location`, default `ukwest`, alongside the primary `var.location`, default `uksouth`) and a global front door so the application keeps serving even if an entire region becomes unavailable.

## What this deploys

One resource group (`rg-claims-phase6-<suffix>`) containing the whole multi-region footprint, so `deploy.sh`/`teardown.sh` manage it atomically and independently of every other phase:

- `infra/modules/network` x2 — one VNet per region, each with a subnet delegated to `Microsoft.Sql/managedInstances` for that region's Managed Instance (same delegated-subnet pattern as Phase 5).
- `infra/modules/sql-managed-instance` x2 — a primary/secondary Managed Instance pair joined by a failover group (same pattern as Phase 5, here spanning two regions instead of two instances in one region).
- `infra/modules/storage-account` x1 (shared) — one storage account with `account_replication_type = "RAGRS"` (Terraform's value for what the Azure portal calls "RA-GRS": geo-redundant storage with a readable secondary endpoint). One account, not two — RA-GRS already gives both regions a readable copy without standing up separate storage per region.
- `infra/modules/redis` x2 — one cache per region. **Not replicated** — see "Why Redis is regional" below.
- `infra/modules/monitoring` x2 — one Log Analytics workspace + Application Insights per region, so each region's telemetry (and any failover investigation) can be inspected independently.
- `infra/modules/key-vault` x2 — one per region (`kv-claims-p6pri-<suffix>` / `kv-claims-p6sec-<suffix>`), each holding that region's own copy of the secrets.
- `infra/modules/app-service` x2 — one Linux Web App per region, each wired to its own region's Key Vault and Redis cache.
- `infra/modules/front-door` x1 — the single global entry point, load-balancing across both regions' App Service hostnames as origins.

Plus the same public-data-endpoint NSG rule pattern Phase 5 uses, applied per region (port 3342 on each region's MI subnet).

## Global routing: why active/active

The `front-door` module's `origins` input lets each origin set its own `priority` (lower wins) — a `1`/`2` split would give classic active/passive failover, with the secondary only receiving traffic once the primary's health probe fails. This phase instead gives **both regions priority 1** (active/active): both App Services are fully provisioned and serving real traffic all the time, not sitting cold as standby capacity. Front Door load-balances across both by its `load_balancing` weights, and its health probe (`/health`, see the `front-door` module's `health_probe` block) simply stops sending traffic to whichever origin fails its probe. Regional failover therefore isn't a special "failover mode" Front Door switches into — it's a side effect of ordinary health-probed load balancing: lose a region, and Front Door is already configured to route 100% of traffic to the survivor.

This trades a small amount of cost/idle-capacity-when-healthy (you're paying for two regions at "full" scale instead of one warm + one cold) for a simpler model and zero failover latency beyond the probe interval.

## Database: one MI pair, both regions point at the primary

Both regions' App Service read the **same** `ClaimsDb-ConnectionString` secret, pointing at the **primary** Managed Instance's connection string — not "each region talks to its own same-region MI." This was a deliberate call, not an oversight, made for a concrete reason: the failover group only ever has **one** read-write endpoint active at a time (that's the whole point of a failover group — it's not a multi-master setup), so having the secondary region's App Service write to the secondary MI directly isn't actually possible while the secondary is in its normal (replica) role.

**Known limitation — read this before treating the connection string as production-ready.** The connection string is built in `main.tf`'s `locals` block directly from the primary MI's `fqdn` output on port 3342:

```
Server=tcp:<primary-mi-fqdn>,3342;Initial Catalog=claimsdb;...
```

This was checked against the module, not assumed: `infra/modules/sql-managed-instance/outputs.tf` exposes only `mi_id`, `fqdn`, and `failover_group_id` — there is **no** output for the failover group's own read-write **listener** endpoint (the stable DNS name that would keep working transparently across a real failover without anyone updating a connection string by hand). The module's `main.tf` resource block (`azurerm_mssql_managed_instance_failover_group`) doesn't surface one either. Since the shared `infra/modules/*` are frozen for this phase, the honest options were: (a) use the raw primary `fqdn` and document the gap, or (b) modify the shared module. We took (a). **In a real failover, you would need to either update this connection string by hand after the secondary is promoted, or extend the module to expose the failover group's listener endpoint** (Azure SQL MI failover groups do have a stable read-write listener DNS name in the actual service — it just isn't wired up as a Terraform output here).

Also note: connecting via the MI's **public data endpoint at all** (port 3342, rather than private VNet integration) is itself a simplification carried over from Phase 5 — the shared module doesn't expose `public_data_endpoint_enabled`, so this assumes it's enabled on both Managed Instances. Production wiring would have each region's App Service reach its MI over private VNet integration instead of the public endpoint.

## Why Redis is regional (not a bug)

Each region gets its **own** Redis cache, and there is no cross-region replication between them. This is the cache-aside session pattern from Phase 4, just not pinned or synced across regions: Standard-tier Redis doesn't support geo-replication at all, and Premium-tier geo-replication (which does exist in real Azure) is out of scope for this example.

**What this means in practice:** if the primary region goes down and Front Door shifts traffic to the secondary, any session state or cached data that only existed in the primary region's Redis is gone. A logged-in user fails over to a fresh session in the secondary region and has to re-authenticate / start their workflow over. This is a **deliberate, documented trade-off** for this phase, not an oversight — building true cross-region session continuity would mean either Premium Redis geo-replication or moving session state into the (already cross-region-consistent) database/storage tier, both of which are legitimate next steps beyond what this example phase covers.

## Deploying

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id, tenant_id, sql_admin_password
az login
./deploy.sh
```

`deploy.sh` runs `terraform apply` (provisioning both regions plus Front Door), then `dotnet publish` once and `az webapp deploy` (zip deploy) **twice** — once per regional App Service — then polls each region's `/health` directly, then polls the Front Door endpoint's `/health`. Front Door endpoint propagation across its edge network can take a few minutes after first creation, so the Front Door poll is more patient (up to ~10 minutes) than the per-region polls; a timeout there with both regions already healthy directly almost always just means "give it a few more minutes," not a broken deployment.

If an app's very first boot fails to resolve a Key Vault reference (the access policy can finish propagating slightly after the web app's first start), restart it once: `az webapp restart --resource-group <rg> --name <app>`.

**SQL Managed Instance provisioning takes 4-6 hours in real Azure** (per the module's own comment) — this phase is fine as a code-only scaffold for the example, but don't expect `terraform apply` to complete quickly against a real subscription.

## Load testing

```bash
cd ../../loadtest/phase-6-multi-region
BASE_URL=https://<front-door-endpoint>.azurefd.net PHASE=phase-6-multi-region k6 run smoke.js
BASE_URL=https://<front-door-endpoint>.azurefd.net PHASE=phase-6-multi-region k6 run stress-to-failure.js
BASE_URL=https://<front-door-endpoint>.azurefd.net PHASE=phase-6-multi-region k6 run consistency-check.js
```

Point load tests at the **Front Door hostname** (`terraform output front_door_hostname`), not a region directly — that's the actual production entry point this phase adds, and it's also what proves Front Door's routing/load-balancing is in the loop. `consistency-check.js` (carried over unchanged from Phase 3/4) should still pass cleanly: storage is shared RA-GRS, so an upload/download pair lands on the same backing store regardless of which region or which App Service instance within a region serves each request.

See `loadtest/phase-6-multi-region/README.md` for a manual regional-failover drill — k6 can generate load against Front Door, but it can't itself simulate "an entire Azure region goes down," so that drill is a separate, human-run set of steps.

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```

Tears down both regions' full stacks, the failover group, the shared storage account, and Front Door in one `terraform destroy`, since everything lives in the single `rg-claims-phase6-<suffix>` resource group.

## This is the last phase

Phase 0 started as a single VM with every SPOF imaginable; Phase 6 ends as two fully independent regional stacks behind a global load balancer, with geo-redundant storage and a cross-region database failover group. The deliberate gaps documented above (the MI connection string not following a real failover, Redis not being session-sticky across regions) are exactly the kind of thing a real production rollout would close next — they're left visible here on purpose, as the natural "what's still not done" list for a reader working through all seven phases.
