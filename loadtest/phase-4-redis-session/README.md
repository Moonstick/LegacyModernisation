# Phase 4 load tests — Redis-backed session

```bash
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run smoke.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run stress-to-failure.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run consistency-check.js
BASE_URL=https://<app>.azurewebsites.net PHASE=phase-4-redis-session k6 run session-consistency-check.js
```

## smoke.js / stress-to-failure.js

Same shape as every other phase: light steady-state traffic for fast feedback, then a ramp well past a single instance's capacity to watch the App Service Plan autoscale. No behavioural change expected versus Phase 2/3 — Redis adds a small, roughly constant amount of per-request session read/write latency, but shouldn't change the overall shape of the latency/error curve.

## consistency-check.js

Unchanged from Phase 2/3: uploads a file via one request, then immediately tries to download it via a follow-up request. `Storage:Provider` stays `AzureBlob` in this phase (same fix as Phase 3), so this should still pass cleanly — included here as a regression check that Phase 4's Redis change didn't disturb the storage fix.

## session-consistency-check.js (new this phase)

Demonstrates the session-storage consistency bug that **this phase specifically fixes**.

`ClaimsController.Details()` reads/writes a `RecentlyViewedClaims` list in `HttpContext.Session` — a comma-joined list of `ClaimNumber`s, most-recent first, capped at 5. `Views/Claims/Details.cshtml` renders that as a "Recently Viewed" sidebar, but only once it holds more than one entry.

The script:
1. Visits `/Claims/Details/{firstSeededClaimId}` and extracts its `ClaimNumber` from the page `<h1>`.
2. Visits `/Claims/Details/{secondSeededClaimId}` and extracts its `ClaimNumber` the same way.
3. Re-visits `/Claims/Details/{secondSeededClaimId}` and asserts (via `check()`) that the rendered "Recently Viewed" sidebar contains **both** claim numbers.

Each k6 VU/iteration keeps its own cookie jar, so the session cookie set on request 1 rides along on requests 2 and 3 — the assertion is purely "does this one client's session state round-trip consistently," which is exactly what breaks when session is in-memory and per-instance.

**Expected outcome:**
- **Phases 0-3**: flaky/failing. Session is backed by ASP.NET Core's in-memory distributed cache (`AddDistributedMemoryCache()` in `Program.cs`), which lives only on the instance that handled a given request. Once more than one instance is in rotation (Phase 1's load balancer, or Phase 2/3's autoscaled App Service Plan), a later request in the same script can land on a different instance than an earlier one, which never saw the earlier session write — so the sidebar is missing one or both claim numbers.
- **Phase 4**: reliably passing. `Redis__ConnectionString` is now set, so `Program.cs` calls `AddStackExchangeRedisCache()` instead — every instance reads/writes the same shared Redis cache, so the sidebar is consistent regardless of which instance serves which request.
