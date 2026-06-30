# The Modernization Journey

This repo is a worked example of taking a legacy ASP.NET Core app — [ClaimsCaseManagement](../src/ClaimsCaseManagement), an insurance claims case management system — from a single VM to a multi-region, horizontally scalable PaaS architecture on Azure, in seven checkpointed phases.

Every phase is independently deployable. Each one has its own:
- **Infrastructure as code** (`infra/phase-N-*`, Terraform) to stand the environment up.
- **Teardown script** (`infra/phase-N-*/teardown.sh`) to tear it back down.
- **Load tests** (`loadtest/phase-N-*`, k6) that push the deployed environment to the point of failure, so you can see — not just read — what each phase actually fixes.
- A **git tag** marking the exact commit where that phase's app code + infra + load tests are complete and consistent (see the checkpoint table below).

See [RUNBOOK.md](./RUNBOOK.md) for prerequisites and exact commands to deploy, test, and tear down any phase.

## Why these two app features exist

The app didn't originally have file uploads or session state — they're added in Phase 0 specifically because the rest of the journey needs something concrete to break and then fix:

- **File attachments** are saved by `IFileStorageService`. Phase 0's `LocalDiskFileStorageService` writes to the instance's local disk — the obvious, "it works on my machine" choice. Phase 3 swaps in `AzureBlobFileStorageService` with zero controller/view changes — just a config flip (`Storage:Provider=AzureBlob`).
- **"Recently viewed claims"** is a deliberately small feature that uses `HttpContext.Session`. Phase 0 uses ASP.NET Core's default in-memory session. Phase 4 swaps the session's backing distributed cache to Azure Cache for Redis (`Redis:ConnectionString` config) — again, no controller/view changes.

Both are textbook examples of state that's invisible to your capacity planning until you scale past one instance — which is exactly when Phase 1 exposes them.

## Phase by phase

### Phase 0 — Single VM monolith (`phase-0-single-vm`)
One Azure VM running the web app and SQL Server side by side. No redundancy: the VM is a single point of failure for compute, data, file storage, and session, all at once. This is the deliberate starting point — a faithful "lift and shift."

**Load test should show:** a hard capacity ceiling (CPU/connection-bound on one box), and a full outage the moment the VM is stopped.

### Phase 1 — Extract single points of failure (`phase-1-spof-extraction`)
Still IaaS, but redundant: SQL Server moves to its own VM, and two web VMs sit behind an Azure Load Balancer in an availability set. Infra-level SPOFs are gone — but the app-level ones aren't.

**Load test should show:** higher aggregate throughput than Phase 0, but uploads and "recently viewed" become unreliable — a file uploaded via one VM 404s when the load balancer routes the follow-up `Download` request to the other VM; the recently-viewed list resets depending on which VM serves you. This is the motivating evidence for Phases 3 and 4.

### Phase 2 — PaaS foundations (`phase-2-paas-foundations`)
The web tier moves off VMs entirely onto Azure App Service (autoscaling, no OS patching), and the database moves to Azure SQL Database (PaaS). Secrets move to Key Vault, and Application Insights/Log Analytics are wired in. File storage and session are still broken in the same way as Phase 1 (App Service instances are ephemeral, so local-disk uploads are now *more* fragile, not less).

**Load test should show:** autoscaling smooths out the capacity ceiling from Phase 1, but the file/session consistency failures persist — proving the fix has to be architectural, not just "more compute."

### Phase 3 — Extract file storage to a Storage Account (`phase-3-blob-storage`)
`Storage:Provider` flips to `AzureBlob`. Every App Service instance now reads and writes the same Blob container.

**Load test should show:** the upload→download consistency failures from Phase 1/2 are gone, even under the same autoscale-triggering load.

### Phase 4 — Move session to Redis (`phase-4-redis-session`)
`Redis:ConnectionString` is set, so ASP.NET Core's distributed session is backed by Azure Cache for Redis instead of in-memory.

**Load test should show:** the recently-viewed-list inconsistency from Phase 1/2 is gone, regardless of which instance serves each request.

### Phase 5 — Move the database to a Managed Instance (`phase-5-managed-instance`)
Azure SQL Database is upgraded to Azure SQL Managed Instance with an auto-failover group — full SQL Server surface area, zone redundancy, and automatic failover. This is the HA/DR upgrade that Phase 6's multi-region design depends on.

**Load test should show:** sustained throughput at higher concurrency than Phase 2-4's single-instance SQL Database, and a bounded recovery time during a simulated failover.

### Phase 6 — Multi-region for global scalability (`phase-6-multi-region`)
App Service deployed in two regions behind Azure Front Door, the Managed Instance failover group's secondary promoted to a second region, RA-GRS storage, and regional Redis caches (session is cache-aside per region — there's no cross-region session replication, which is itself a worked example of a tradeoff, not an oversight).

**Load test should show:** lower latency for geographically distributed load, and continued availability (after Front Door reroutes) during a simulated regional outage.

## Checkpoints

| Phase | Tag | What it proves |
|---|---|---|
| 0 | `phase-0-single-vm-baseline` | The starting point, and its single point of failure |
| 1 | `phase-1-spof-extraction` | Infra redundancy alone doesn't fix app-level state assumptions |
| 2 | `phase-2-paas-foundations` | PaaS compute/data without fixing storage/session is not enough |
| 3 | `phase-3-blob-storage` | File consistency fixed |
| 4 | `phase-4-redis-session` | Session consistency fixed |
| 5 | `phase-5-managed-instance` | Database HA/DR |
| 6 | `phase-6-multi-region` | Global scale + regional failover |

`git checkout <tag>` at any point gives you the exact app + infra + load test state for that phase.
