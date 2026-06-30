import http from 'k6/http';
import { sleep, check } from 'k6';
import { BASE_URL, PHASE, SEEDED_CLAIM_IDS } from '../common/config.js';
import { extractAntiForgeryToken, jsonReportPath } from '../common/helpers.js';

// Demonstrates the fix for the file-storage consistency bug: upload a file
// via one request, then immediately try to download it via a follow-up
// request. Storage:Provider has been AzureBlob since Phase 3, so every App
// Service instance reads and writes the same Blob container instead of its
// own local disk -- unchanged by this phase's database upgrade. This
// script should still pass cleanly here, same as Phase 3/4 -- if it
// doesn't, that points at a Storage Account/Key Vault wiring regression,
// not the SQL Managed Instance change this phase actually makes.
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
