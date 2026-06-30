import http from 'k6/http';
import { sleep, check } from 'k6';
import { BASE_URL, PHASE, SEEDED_CLAIM_IDS } from '../common/config.js';
import { jsonReportPath } from '../common/helpers.js';

// Demonstrates the session-storage consistency bug that this phase fixes.
//
// ClaimsController.Details() reads/writes a "RecentlyViewedClaims" list in
// HttpContext.Session (see Controllers/ClaimsController.cs) -- a
// comma-joined list of ClaimNumbers, most-recent first, capped at 5.
// Views/Claims/Details.cshtml renders that list as a "Recently Viewed"
// <ul> sidebar, but only once it holds more than one entry, so a real
// assertion needs at least two distinct claims visited in the same
// session.
//
// In Phase 0-3, session is backed by ASP.NET Core's in-memory distributed
// cache (Program.cs: AddDistributedMemoryCache()), which lives entirely on
// whichever instance handled the request. The moment more than one
// instance is in rotation (Phase 1's load balancer, or Phase 2/3's
// autoscaled App Service Plan), a later request can land on a *different*
// instance than the one that recorded an earlier "viewed claim 1" -- that
// instance's in-memory session never saw it, so the sidebar only shows
// claim 2 (or is missing entirely if the session cookie's instance-affinity
// assumption breaks down too). Expect this script to be flaky/fail
// intermittently on Phases 0-3.
//
// In Phase 4, Redis:ConnectionString is set, so Program.cs calls
// AddStackExchangeRedisCache() instead -- every instance reads/writes the
// same shared Redis cache, so the sidebar is consistent no matter which
// instance serves which request. Expect this script to pass reliably here.
export const options = {
  vus: 5,
  duration: '1m',
};

// Pulls "CLM-100001" out of the Details page's <h1>Claim CLM-100001</h1>.
function extractClaimNumber(html) {
  const match = html.match(/<h1>Claim ([^<]+)<\/h1>/);
  return match ? match[1] : null;
}

// Pulls every claim number listed in the "Recently Viewed" <ul>, in case
// other VUs are racing against the same shared session/cookie state.
function extractRecentlyViewed(html) {
  const sectionMatch = html.match(/Recently Viewed<\/h5>\s*<ul class="list-group">([\s\S]*?)<\/ul>/);
  if (!sectionMatch) {
    return [];
  }
  const items = [...sectionMatch[1].matchAll(/<li class="list-group-item[^"]*">([^<]+)<\/li>/g)];
  return items.map((m) => m[1]);
}

export default function () {
  if (SEEDED_CLAIM_IDS.length < 2) {
    check(null, { 'at least two seeded claims configured': () => false });
    return;
  }

  // Each VU/iteration gets its own k6 cookie jar by default, so the
  // session cookie set on the first request below rides along on the
  // second -- this isolates the check to "does session state round-trip
  // through whichever instance(s) serve this one VU's requests" rather
  // than depending on cross-VU sharing.
  const [firstId, secondId] = SEEDED_CLAIM_IDS;

  const firstRes = http.get(`${BASE_URL}/Claims/Details/${firstId}`);
  const firstClaimNumber = extractClaimNumber(firstRes.body);
  if (!check(firstClaimNumber, { 'first claim number found': (n) => !!n })) {
    sleep(1);
    return;
  }

  const secondRes = http.get(`${BASE_URL}/Claims/Details/${secondId}`);
  const secondClaimNumber = extractClaimNumber(secondRes.body);
  if (!check(secondClaimNumber, { 'second claim number found': (n) => !!n })) {
    sleep(1);
    return;
  }

  // A third, fresh request -- on Phase 0-3 this is another chance for the
  // load balancer/App Service to route to a different instance than either
  // of the two above, exposing the in-memory session split. Re-fetching
  // the second claim's Details page is enough: the "Recently Viewed"
  // sidebar it renders should include the *first* claim too if session
  // state is actually shared.
  const verifyRes = http.get(`${BASE_URL}/Claims/Details/${secondId}`);
  const recentlyViewed = extractRecentlyViewed(verifyRes.body);

  check(recentlyViewed, {
    'recently viewed list is non-empty': (list) => list.length > 0,
    'recently viewed includes both claims viewed this session': (list) =>
      list.includes(firstClaimNumber) && list.includes(secondClaimNumber),
  });

  sleep(1);
}

export function handleSummary(data) {
  return { [jsonReportPath(PHASE)]: JSON.stringify(data) };
}
