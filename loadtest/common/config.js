// Shared k6 configuration helpers for the ClaimsCaseManagement load test suite.
// Every phase-specific script should import from this file rather than
// re-reading __ENV directly, so that defaults stay consistent across phases.

// Base URL of the system under test. Override per-run with:
//   k6 run -e BASE_URL=https://claims-phase2.azurewebsites.net script.js
export const BASE_URL = __ENV.BASE_URL || 'http://localhost:5000';

// Free-text label identifying which modernization phase is being tested.
// Used to namespace result file paths (see helpers.js) and to tag metrics.
export const PHASE = __ENV.PHASE || 'unknown';

// Returns the current config as a plain object, for scripts that prefer
// a single import over multiple named imports.
export function getConfig() {
  return {
    baseUrl: BASE_URL,
    phase: PHASE,
  };
}

// ClaimIds seeded by DbInitializer.Seed() on every phase (CLM-100001,
// CLM-100002). Load test scripts should read/write against these rather
// than creating new claims, since Create requires a valid PolicyId/
// ClaimantId pair as well as an anti-forgery token.
export const SEEDED_CLAIM_IDS = [1, 2];

// Strict thresholds for smoke tests: low load, fast feedback, should pass
// reliably on every phase. Wire these into a script's `options.thresholds`
// to fail the test run (and CI) when they are violated.
export const SMOKE_THRESHOLDS = {
  http_req_duration: ['p(95)<500'],
  http_req_failed: ['rate<0.01'],
};

// Looser thresholds for stress/soak tests. These are intentionally not
// meant to abort the test run on failure -- they exist so the summary
// report highlights degraded performance under load without treating it
// as a hard CI failure. Phase scripts can still add `abortOnFail: true`
// to individual thresholds if a phase wants stricter enforcement.
export const STRESS_THRESHOLDS = {
  http_req_duration: ['p(95)<3000', 'p(99)<8000'],
  http_req_failed: ['rate<0.25'],
};
