import http from 'k6/http';
import { sleep, check } from 'k6';
import { BASE_URL, PHASE, SEEDED_CLAIM_IDS } from '../common/config.js';
import { extractAntiForgeryToken, jsonReportPath } from '../common/helpers.js';

// This is the script that motivates the rest of the journey: Phase 0 had
// only one web instance, so this consistency bug couldn't surface no matter
// how hard you hit it. Phase 1 adds a second web instance behind a load
// balancer with no session affinity, so uploads landing on local disk
// (Storage:Provider=Local) become invisible to roughly half of all
// downloads. Expect frequent failures here -- that's the point. It stays
// broken through Phase 2 (App Service disk is also per-instance and
// ephemeral) and gets fixed in Phase 3's blob storage swap.
export const options = {
  vus: 5,
  duration: '1m',
};

export default function () {
  const claimId = SEEDED_CLAIM_IDS[Math.floor(Math.random() * SEEDED_CLAIM_IDS.length)];

  const detailsRes = http.get(`${BASE_URL}/Claims/Details/${claimId}`);
  const token = extractAntiForgeryToken(detailsRes.body);
  if (!token) {
    check(null, { 'anti-forgery token found': () => false });
    sleep(1);
    return;
  }

  const fileName = `loadtest-${Date.now()}-${__VU}-${__ITER}.txt`;
  const uploadRes = http.post(
    `${BASE_URL}/Claims/Upload`,
    {
      claimId: String(claimId),
      __RequestVerificationToken: token,
      file: http.file('load test attachment contents', fileName, 'text/plain'),
    },
    { redirects: 0 }
  );
  check(uploadRes, { 'upload accepted (302)': (r) => r.status === 302 });

  // A fresh request -- the load balancer gets a new chance to route to a
  // different instance than the one that handled the upload.
  const afterUploadRes = http.get(`${BASE_URL}/Claims/Details/${claimId}`);
  const downloadLinkMatch = afterUploadRes.body.match(
    new RegExp(`Download/(\\d+)"[^>]*>${fileName.replace(/\./g, '\\.')}`)
  );

  if (!downloadLinkMatch) {
    check(null, { 'uploaded file visible in details page': () => false });
    sleep(1);
    return;
  }

  const downloadRes = http.get(`${BASE_URL}/Claims/Download/${downloadLinkMatch[1]}`);
  check(downloadRes, { 'download succeeds (200)': (r) => r.status === 200 });

  sleep(1);
}

export function handleSummary(data) {
  return { [jsonReportPath(PHASE)]: JSON.stringify(data) };
}
