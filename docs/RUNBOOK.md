# Runbook

How to deploy, load-test, and tear down any phase of the [modernization journey](./MODERNIZATION-JOURNEY.md). Everything here is **code you run against your own Azure subscription** — nothing in this repo deploys or runs anything automatically.

## Prerequisites

- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az login` against the subscription you want to use)
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) (to publish the app for App Service phases, or to run it locally)
- [k6](https://k6.io/docs/get-started/installation/) for load testing
- An SSH key pair for the VM-based phases (0 and 1): `ssh-keygen -t ed25519 -f ~/.ssh/claims_modernization`

## Cost warning

Every phase except 0/1 provisions real billable PaaS resources (App Service, Azure SQL, Redis, Storage). **Phase 5 (SQL Managed Instance) is the most expensive and slowest to provision** — expect 4-6 hours for the instance to come online, and a non-trivial hourly cost while it exists. Always run `teardown.sh` when you're done with a phase. Each phase deploys into its own resource group (`rg-claims-phase{N}-<suffix>`) specifically so you can tear one down without touching another.

## A note on how this repo was authored

The Terraform, app code, and load tests in this repo were written in a sandboxed environment without outbound access to `registry.terraform.io` or the .NET SDK download host, so `terraform validate` and `dotnet build` could not be run as part of authoring. Every module was formatted with `terraform fmt` and manually reviewed for internal consistency (variable/output names, resource references) instead. Run `terraform init && terraform validate` and `dotnet build` yourself as a first step in your own environment before deploying — that's the real verification this repo couldn't do for you. Relatedly, the app still calls `Database.EnsureCreated()` (see `DbInitializer.cs`) rather than EF Core migrations, for the same reason — `EnsureCreated()` works fine for every phase's fresh database, but if you extend the schema later you'll want to switch to migrations yourself.

## Deploying a phase

```bash
cd infra/phase-<N>-<name>
cp terraform.tfvars.example terraform.tfvars   # fill in your values (subscription, admin password, ssh key, etc.)
./deploy.sh
```

`deploy.sh` runs `terraform init && terraform apply`, then deploys the app to whatever compute that phase uses:
- **Phases 0-1 (VMs):** the VM's cloud-init clones this repo at the phase's git tag and runs `dotnet publish` + a systemd unit on first boot — `deploy.sh` just waits for the health check at `http://<vm-ip>/health` to go green.
- **Phases 2-6 (App Service):** `deploy.sh` runs `dotnet publish` locally and `az webapp deploy` (zip deploy) after `terraform apply` creates the Web App.

Each phase's own `README.md` documents the resource-specific config it expects (connection strings, storage provider, Redis connection string, etc.) — these are wired into the Web App's app settings / the VM's cloud-init by that phase's Terraform, you shouldn't need to set them by hand.

## Running the load tests

```bash
cd loadtest/phase-<N>-<name>
BASE_URL=http://<app-url> PHASE=phase-<N>-<name> k6 run smoke.js          # sanity check, low load
BASE_URL=http://<app-url> PHASE=phase-<N>-<name> k6 run stress-to-failure.js   # ramps until it breaks
```

Results land in `loadtest/phase-<N>-<name>/results/` as JSON (see `loadtest/common/helpers.js`). Each phase's `README.md` describes what failure mode to expect and, where relevant, a manual step to trigger during the test (e.g. stopping the Phase 0 VM, or killing one Phase 1 web VM) to demonstrate the SPOF.

To build a real before/after comparison across phases, run the same `stress-to-failure.js`-style scenario against each phase you've deployed and diff the JSON summaries — the numbers (max sustained RPS, p95 latency at saturation, error rate) are the proof.

## Tearing a phase down

```bash
cd infra/phase-<N>-<name>
./teardown.sh
```

This runs `terraform destroy` scoped to that phase's resource group. It does not touch any other phase's resources. Confirm the prompt (or pass `-auto-approve`, available as `./teardown.sh --yes`) — there's no recovery once it runs.

## Checking out a phase's exact state

```bash
git checkout phase-<N>-<name>   # see docs/MODERNIZATION-JOURNEY.md for the full tag list
```

This gives you the app code, infra, and load tests exactly as they were when that phase was completed — useful if you want to deploy an older phase after the repo has moved on to a later one.
