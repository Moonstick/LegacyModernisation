import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, PHASE, STRESS_THRESHOLDS, SEEDED_CLAIM_IDS } from '../common/config.js';
import { checkResponse, jsonReportPath } from '../common/helpers.js';

// Ramps well past a single App Service instance's capacity. App Service is
// unchanged since Phase 4 -- still single-region, still autoscaling
// 1->3 instances on CPU -- so expect a higher sustained ceiling and a
// smoother latency curve, not a hard wall. Phase 5's upgrade is the
// database tier (SQL Managed Instance + DR failover group), which doesn't
// change compute capacity, so this should look the same as Phase 4's run.
export const options = {
  stages: [
    { duration: '1m', target: 20 },
    { duration: '2m', target: 80 },
    { duration: '2m', target: 160 },
    { duration: '2m', target: 280 },
    { duration: '1m', target: 0 },
  ],
  thresholds: STRESS_THRESHOLDS,
};

export default function () {
  checkResponse(http.get(`${BASE_URL}/Claims`));

  const claimId = SEEDED_CLAIM_IDS[Math.floor(Math.random() * SEEDED_CLAIM_IDS.length)];
  checkResponse(http.get(`${BASE_URL}/Claims/Details/${claimId}`));

  sleep(Math.random());
}

export function handleSummary(data) {
  return { [jsonReportPath(PHASE)]: JSON.stringify(data) };
}
