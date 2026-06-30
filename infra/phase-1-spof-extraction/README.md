# Phase 1 — SPOF extraction

Redundancy at the infrastructure layer only. Two web VMs sit behind an Azure Load Balancer, spread across an availability set, and SQL Server moves onto its own dedicated VM. This removes the "one box does everything" capacity ceiling from Phase 0 -- but it deliberately does **not** fix anything in the app, so it exposes the app-level single points of failure that infra redundancy alone can't paper over.

## What this deploys

- `infra/modules/network` — a VNet with two subnets: `web` (10.0.1.0/24) and `db` (10.0.2.0/24).
- `infra/modules/linux-vm` x2 (`web_vm["1"]`, `web_vm["2"]`) — identical Ubuntu 22.04 VMs, no public IP of their own, placed in an availability set. `cloud-init-web.yaml.tftpl` installs the .NET 8 SDK, clones this repo at `var.git_tag`, publishes, and starts the app under systemd, pointed at the DB VM's private IP.
- `infra/modules/linux-vm` x1 (`db_vm`) — a dedicated VM running SQL Server 2022 (`cloud-init-db.yaml.tftpl`), with a public IP for troubleshooting access.
- `infra/modules/load-balancer` — a Standard SKU public load balancer fronting both web VMs, health-probing `/health` on port 80.
- `azurerm_network_security_rule` resources for: HTTP inbound to the web subnet (required for a Standard SKU LB — unlike Basic, it does not get an implicit `AzureLoadBalancer` allow), SQL (1433) inbound to the db subnet scoped to the web subnet's CIDR only, and SSH inbound to the db subnet.

## What's still broken (on purpose)

- **File attachments** still land on each web VM's local disk (`Storage:Provider=Local`). Upload via one instance, and a download routed to the *other* instance 404s. The load balancer has no session affinity configured, so this happens constantly under real traffic.
- **Session state** is still ASP.NET Core's default in-memory store, per-instance. "Recently viewed claims" will flicker depending on which instance serves a given request.

Both get fixed in later phases (blob storage in Phase 3, Redis-backed session in Phase 4) — this phase exists specifically to make those bugs visible and reproducible under load, which is what `consistency-check.js` does below.

## Deploying

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id, ssh key path, sql_admin_password
./deploy.sh
```

First boot takes 5-10 minutes (parallel: .NET SDK install + `dotnet publish` on both web VMs, SQL Server install on the db VM). `deploy.sh` polls `http://<lb-ip>/health` until it's green. Note: whichever web instance's app starts first wins `DbInitializer.Seed()`'s create-and-seed race — harmless here, but worth knowing about.

## Load testing

```bash
cd ../../loadtest/phase-1-spof-extraction
BASE_URL=http://<lb-ip> PHASE=phase-1-spof-extraction k6 run smoke.js
BASE_URL=http://<lb-ip> PHASE=phase-1-spof-extraction k6 run stress-to-failure.js
BASE_URL=http://<lb-ip> PHASE=phase-1-spof-extraction k6 run consistency-check.js
```

**Expect:** `stress-to-failure.js` should sustain meaningfully higher throughput than Phase 0 before error rates climb, since web capacity now scales independently of the DB and there are two instances sharing load. `consistency-check.js` is the one to watch closely here -- expect intermittent upload/download failures as soon as the load balancer spreads requests across both web instances, demonstrating that infra-level redundancy alone doesn't fix app-level state assumptions.

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```
