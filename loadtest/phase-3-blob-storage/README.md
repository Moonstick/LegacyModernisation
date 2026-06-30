# Phase 3 load tests — Blob storage

Same compute tier as Phase 2 (App Service autoscale 1-3 instances), so `smoke.js` and `stress-to-failure.js` are unchanged in shape and thresholds. The interesting result in this phase is `consistency-check.js`.

## Running

```bash
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-3-blob-storage k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-3-blob-storage k6 run stress-to-failure.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-3-blob-storage k6 run consistency-check.js
```

## What to expect

- `smoke.js` — quick sanity pass at low concurrency. Should pass, same as every prior phase.
- `stress-to-failure.js` — ramps well past a single instance's capacity. Same story as Phase 2: the App Service Plan autoscales from 1 to 3 instances, smoothing out the hard ceiling seen in Phase 0/1.
- `consistency-check.js` — uploads a file via one request and immediately tries to download it via a follow-up request, which can land on a different App Service instance once autoscaling has more than one running. In Phases 0-2 this fails intermittently because uploads land on each instance's own local disk (`Storage:Provider=Local`). In Phase 3, `Storage:Provider=AzureBlob` means every instance reads and writes the same Blob container, so **this should now pass cleanly** -- proving the consistency bug needed an architectural fix (shared storage), not just more compute.
