import http from 'k6/http';
import { sleep } from 'k6';
import { BASE_URL, PHASE, SMOKE_THRESHOLDS, SEEDED_CLAIM_IDS } from '../common/config.js';
import { checkResponse, jsonReportPath } from '../common/helpers.js';

// BASE_URL should be the Front Door endpoint (terraform output
// front_door_hostname), not either region's App Service directly -- that's
// the actual entry point this phase adds, and routing requests through it
// is what exercises Front Door's load balancing across both regions.
export const options = {
  vus: 2,
  duration: '30s',
  thresholds: SMOKE_THRESHOLDS,
};

export default function () {
  checkResponse(http.get(`${BASE_URL}/`));
  checkResponse(http.get(`${BASE_URL}/Claims`));

  const claimId = SEEDED_CLAIM_IDS[Math.floor(Math.random() * SEEDED_CLAIM_IDS.length)];
  checkResponse(http.get(`${BASE_URL}/Claims/Details/${claimId}`));

  sleep(1);
}

export function handleSummary(data) {
  return { [jsonReportPath(PHASE)]: JSON.stringify(data) };
}
