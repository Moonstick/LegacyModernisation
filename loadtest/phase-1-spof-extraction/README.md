# Phase 1 load tests

```bash
BASE_URL=http://<lb-ip> PHASE=phase-1-spof-extraction k6 run smoke.js
BASE_URL=http://<lb-ip> PHASE=phase-1-spof-extraction k6 run stress-to-failure.js
BASE_URL=http://<lb-ip> PHASE=phase-1-spof-extraction k6 run consistency-check.js
```

Results land in `results/phase-1-spof-extraction/summary.json`.

**Expect:**
- `stress-to-failure.js` should sustain a higher ceiling than Phase 0 before error rates climb — web capacity no longer shares a CPU/memory budget with SQL Server, and two instances share the load. Still a hard wall, not a smooth curve: there's no autoscaling at this phase, just a fixed pair of VMs.
- `consistency-check.js` is the one that matters most here. With two web instances behind a load balancer and no session affinity, roughly half of all upload-then-download sequences should fail — the uploaded file lands on whichever instance handled the upload, but the follow-up download has even odds of being routed to the other one. This is the headline bug this phase exists to demonstrate; it carries through Phase 2 unchanged and gets fixed in Phase 3's blob storage swap.

For a manual demonstration of the remaining DB single point of failure, run `az vm stop` against the db VM partway through a test run and confirm the app goes fully dark even though both web VMs are still up — redundant web capacity doesn't help if the one thing behind it is still a single box.
