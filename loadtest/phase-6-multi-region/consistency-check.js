import http from 'k6/http';
import { sleep, check } from 'k6';
import { BASE_URL, PHASE, SEEDED_CLAIM_IDS } from '../common/config.js';
import { extractAntiForgeryToken, jsonReportPath } from '../common/helpers.js';

// Demonstrates the fix for the file-storage consistency bug carries over
// cleanly into a multi-region deployment: upload a file via one request,
// then immediately try to download it via a follow-up request. BASE_URL
// here should be the Front Door hostname, so each request can land on
// either region's App Service (and either region's autoscaled instance
// within it) -- yet the storage account is a single shared RA-GRS account
// (Storage:Provider=AzureBlob, same fix as Phase 3/4), so both regions read
// and write the same backing store. This should still pass cleanly even
// when requests bounce between regions -- if it doesn't, that points at a
// Storage Account/Key Vault wiring problem in one of the two regions, not
// an architectural gap (RA-GRS's secondary endpoint being read-only doesn't
// matter here either, since both regions write through the same primary
// endpoint, not the geo-replicated secondary).
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

  // A fresh request -- Front Door and/or the load balancer/App Service get
  // a new chance to route to a different region/instance than the one that
  // handled the upload.
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
