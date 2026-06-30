import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, PHASE, STRESS_THRESHOLDS, SEEDED_CLAIM_IDS } from '../common/config.js';
import { checkResponse, jsonReportPath } from '../common/helpers.js';

// Ramps VUs well past what one VM running web + SQL Server side by side can
// sustain. Expect p95/p99 latency and error rate to climb sharply once CPU
// and SQL Server connections saturate -- there's no autoscaling or
// redundancy at this phase to absorb it.
export const options = {
  stages: [
    { duration: '1m', target: 20 },
    { duration: '2m', target: 60 },
    { duration: '2m', target: 120 },
    { duration: '2m', target: 200 },
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
