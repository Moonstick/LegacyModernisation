# Phase 5 load tests — SQL Managed Instance HA/DR

Same app tier as Phase 4 (App Service autoscale 1-3 instances, Blob storage, Redis session), so `smoke.js`, `stress-to-failure.js`, and `consistency-check.js` are unchanged in shape and thresholds and aren't expected to show anything different from Phase 4's results under normal operation. This phase's database upgrade (Azure SQL Managed Instance + auto-failover group) is about disaster recovery, not throughput.

## Running

```bash
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-5-managed-instance k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-5-managed-instance k6 run stress-to-failure.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-5-managed-instance k6 run consistency-check.js
```

## What to expect

- `smoke.js` — quick sanity pass at low concurrency. Should pass, same as every prior phase.
- `stress-to-failure.js` — ramps well past a single instance's capacity. Same story as Phase 4: App Service autoscales 1-3 instances. The database tier change in this phase doesn't affect compute capacity.
- `consistency-check.js` — uploads a file via one request and immediately tries to download it via a follow-up request. Storage has been Blob-backed since Phase 3, so this should still pass cleanly here.

## What's not scripted: the failover drill

The actual interesting exercise for this phase — promoting the secondary Managed Instance to primary and watching what happens — is a **manual** drill, not a k6 script:

```bash
az sql instance-failover-group set-primary \
  --name <failover-group-name> \
  --resource-group <rg> \
  --server <secondary-instance-name>
```

This is out of scope for k6 (it's a one-shot control-plane operation, not a repeatable load pattern) and is documented in `infra/phase-5-managed-instance/README.md` instead, including the practical wrinkle that the app's connection string targets the primary instance's own `fqdn` rather than the failover group's listener, so a real failover would need the Key Vault secret updated to point at the new primary.
