import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, PHASE, STRESS_THRESHOLDS, SEEDED_CLAIM_IDS } from '../common/config.js';
import { checkResponse, jsonReportPath } from '../common/helpers.js';

// Two web VMs behind a load balancer should sustain noticeably more load
// than Phase 0's single co-located VM before error rates climb -- web
// capacity is no longer competing with SQL Server for the same CPU/memory,
// and there are two instances sharing the traffic. There's still no
// autoscaling at this phase (fixed at 2 instances), so expect a higher but
// still hard ceiling, not a smooth curve.
export const options = {
  stages: [
    { duration: '1m', target: 30 },
    { duration: '2m', target: 90 },
    { duration: '2m', target: 150 },
    { duration: '2m', target: 240 },
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
