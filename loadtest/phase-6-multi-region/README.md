# Phase 6 load tests — multi-region

Front Door now sits in front of two fully-provisioned regional App Service stacks, each still autoscaling 1-3 instances the same as every PaaS phase since Phase 2. `smoke.js` and `stress-to-failure.js` are the same shape as earlier phases but point at the **Front Door hostname**, not a region directly, so the load actually flows through Front Door's active/active load balancing. `consistency-check.js` is carried over unchanged from Phase 3/4 — storage is a single shared RA-GRS account, so it should still pass cleanly even with requests bouncing between regions.

## Running

```bash
BASE_URL=https://<front-door-endpoint>.azurefd.net PHASE=phase-6-multi-region k6 run smoke.js
BASE_URL=https://<front-door-endpoint>.azurefd.net PHASE=phase-6-multi-region k6 run stress-to-failure.js
BASE_URL=https://<front-door-endpoint>.azurefd.net PHASE=phase-6-multi-region k6 run consistency-check.js
```

Get the Front Door hostname from `terraform output front_door_hostname` in `infra/phase-6-multi-region/`.

## What to expect

- `smoke.js` — quick sanity pass at low concurrency through Front Door. Should pass, same as every prior phase.
- `stress-to-failure.js` — ramps well past what a single region's App Service Plan can absorb. Expect a noticeably higher sustained ceiling than any single-region phase at the same error rate, since Front Door is spreading load across two independently-autoscaling regions instead of one.
- `consistency-check.js` — uploads a file via one request, then immediately tries to download it via a follow-up request that may land on either region. Should pass cleanly: both regions share one RA-GRS storage account, so there's no per-region or per-instance local disk to be inconsistent about.

## Manual regional-failover drill (not a k6 script)

The headline capability this phase adds — Front Door automatically routing around a dead region — isn't something k6 can exercise on its own; k6 can generate HTTP load, but it can't take an Azure region offline. That has to be a human-run drill against the real deployed infrastructure. Steps:

1. **Deploy normally** (`./deploy.sh` from `infra/phase-6-multi-region/`) and confirm both regions are healthy: `curl -sf <primary_app_url>/health` and `curl -sf <secondary_app_url>/health` (both from `terraform output`).
2. **Start a baseline load** against the Front Door hostname, e.g. `k6 run smoke.js` in a loop, or just repeated `curl` against `<front_door_hostname>/Claims` — confirm responses are succeeding and (optionally) note response headers/timing to establish what "healthy" looks like.
3. **Take the primary region's App Service down.** Either:
   - `az webapp stop --resource-group <rg> --name <primary_app_service_name>`, or
   - scale its App Service Plan down to a SKU/instance count that can't serve traffic, or
   - block inbound traffic to it (e.g. an NSG deny rule on its outbound path, if you want to simulate a network-level regional outage rather than an app-level one).

   `az webapp stop` is the simplest and most reversible option for a drill.
4. **Keep watching the baseline load against the Front Door hostname.** Front Door's health probe (configured via the `front-door` module's `health_check_path`, default `/health`, probed every 100 seconds per the module's `health_probe.interval_in_seconds`) will start failing against the stopped primary origin. Once enough consecutive probe failures accumulate (`load_balancing.sample_size = 4`, `successful_samples_required = 3` in the module), Front Door stops routing new requests to the primary origin and serves 100% of traffic from the secondary region instead. Expect a short window (on the order of a few probe intervals, so potentially several minutes given the 100s interval) where some requests still get routed to the dead primary before Front Door fully cuts over — this is the real-world latency of health-probe-driven failover, not a bug in this setup.
5. **Confirm the cutover:** responses should keep succeeding throughout (after the brief failover window), and you can confirm they're being served by the secondary region specifically by checking `<secondary_app_url>/health` directly stays healthy throughout while `<primary_app_url>/health` stops responding.
6. **Expect lost sessions, not errors.** If you were logged in / mid-workflow when the primary went down, you'll be bounced to a fresh session in the secondary region and need to re-authenticate — this is the documented Redis-is-regional trade-off (see the phase README), not part of what this drill is testing for.
7. **Restore the primary** (`az webapp start ...`) and confirm Front Door resumes sending it traffic once its health probe goes green again — this validates fail-back, not just fail-over.

This drill is worth running at least once after any real deployment of this phase — it's the one piece of Phase 6's value proposition that no automated load test in this repo can verify for you.
