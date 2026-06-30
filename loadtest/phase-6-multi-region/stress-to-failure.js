import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, PHASE, STRESS_THRESHOLDS, SEEDED_CLAIM_IDS } from '../common/config.js';
import { checkResponse, jsonReportPath } from '../common/helpers.js';

// Hits the Front Door hostname, not a region directly -- Front Door
// active/active load-balances every request across both regions' App
// Service Plans, each of which still autoscales 1->3 instances on CPU the
// same as Phase 2 onward. Expect roughly double the sustained ceiling seen
// in a single-region phase at the same error rate, since there's now two
// independently-autoscaling regions sharing the load instead of one.
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
