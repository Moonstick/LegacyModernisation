# Phase 0 — Single VM monolith

One Azure VM running the ClaimsCaseManagement web app and SQL Server side by side, fronted by nginx as a reverse proxy on port 80. No redundancy anywhere — this is the deliberate "lift and shift" starting point.

## What this deploys

- `infra/modules/network` — a single VNet/subnet.
- `infra/modules/linux-vm` — one Ubuntu 22.04 VM with a public IP. `cloud-init.yaml.tftpl` installs the .NET 8 SDK and SQL Server 2022 on first boot, clones this repo at `var.git_tag`, runs `dotnet publish`, and starts the app under systemd (`claims-app.service`) behind nginx.

File attachments are written to the VM's local disk (`Storage:Provider=Local`, the default). Session state is ASP.NET Core's default in-memory store. Both are fine on a single instance — that's the point of this phase.

## Deploying

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in subscription_id, ssh key path, sql_admin_password
./deploy.sh
```

First boot takes 5-10 minutes (SQL Server + .NET SDK install + `dotnet publish`). `deploy.sh` polls `http://<vm-ip>/health` until it's green.

## Load testing

```bash
cd ../../loadtest/phase-0-single-vm
BASE_URL=http://<vm-ip> PHASE=phase-0-single-vm k6 run smoke.js
BASE_URL=http://<vm-ip> PHASE=phase-0-single-vm k6 run stress-to-failure.js
```

**Expect:** a hard capacity ceiling as load ramps — this one VM is doing web serving, file I/O, and SQL Server all at once, so it saturates CPU/connections well before any cloud-native phase would. As a manual demonstration of the SPOF, stop the VM (`az vm stop`) mid-test and confirm the app goes fully dark — there's no failover of any kind at this phase.

## Tearing down

```bash
./teardown.sh        # prompts for confirmation
./teardown.sh --yes   # skips the prompt
```
