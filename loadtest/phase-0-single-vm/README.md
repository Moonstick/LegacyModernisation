# Phase 0 load tests

```bash
BASE_URL=http://<vm-ip> PHASE=phase-0-single-vm k6 run smoke.js
BASE_URL=http://<vm-ip> PHASE=phase-0-single-vm k6 run stress-to-failure.js
```

Results land in `results/phase-0-single-vm/summary.json`.

**Expect:** `stress-to-failure.js` should show a clear capacity ceiling well before phase 2's autoscaled App Service can sustain — this single VM is doing web serving and SQL Server query execution on the same CPU/memory budget. Watch `http_req_duration` p95/p99 climb and `http_req_failed` rise as VUs ramp past what the VM can absorb.

For a manual demonstration of the VM as a single point of failure, run `az vm stop` against the Phase 0 VM partway through a test run and confirm the app goes fully dark (100% error rate) until you start it again — there's no load balancer or second instance to fail over to at this phase.
