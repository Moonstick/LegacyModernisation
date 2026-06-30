import http from 'k6/http';
import { sleep, check } from 'k6';
import { BASE_URL, PHASE, SEEDED_CLAIM_IDS } from '../common/config.js';
import { extractAntiForgeryToken, jsonReportPath } from '../common/helpers.js';

// Demonstrates the file-storage consistency bug -- carried over unchanged
// from Phase 2/3: upload a file via one request, then immediately try to
// download it via a follow-up request. Storage:Provider stays AzureBlob in
// this phase (same fix as Phase 3), so uploads land in the shared Storage
// Account rather than an instance's own local disk, and this should still
// pass cleanly here regardless of which instance serves each request.
// Redis (this phase's actual change) only affects session state, not file
// storage, so this script is unaffected by -- and still relevant as a
// regression check against -- the Phase 4 change.
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

  // A fresh request -- the load balancer/App Service gets a new chance to
  // route to a different instance than the one that handled the upload.
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
