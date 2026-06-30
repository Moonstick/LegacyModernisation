// Shared k6 helper utilities for the ClaimsCaseManagement load test suite.
// k6 does not support npm imports -- only local relative imports and the
// k6-blessed core modules (k6, k6/http, k6/metrics) -- so keep this file
// free of any node_modules dependencies.

import { check } from 'k6';

// Returns the path a phase script should write its HTML report to, e.g.
// "./results/phase-2/report.html". Phase scripts are responsible for
// actually generating HTML content (e.g. via a summary export tool);
// this helper only standardizes the destination path.
export function htmlReportPath(phase) {
  return `./results/${phase}/report.html`;
}

// Returns the path a phase script should write its raw JSON summary to,
// for use in a k6 handleSummary() implementation, e.g.:
//
//   import { jsonReportPath } from '../common/helpers.js';
//   export function handleSummary(data) {
//     return { [jsonReportPath(__ENV.PHASE)]: JSON.stringify(data) };
//   }
export function jsonReportPath(phase) {
  return `./results/${phase}/summary.json`;
}

// Field names match ClaimsController.Create's model binding (Models/Claim.cs).
// PolicyId/ClaimantId must reference rows seeded by DbInitializer.Seed() --
// use 1 for both, since every phase seeds the same first Policy/Claimant.
export function randomClaimPayload() {
  return {
    PolicyId: 1,
    ClaimantId: 1,
    Description: `Load test claim ${Date.now()}-${Math.random()}`,
    DateOfLoss: new Date().toISOString().slice(0, 10),
    EstimatedAmount: Math.floor(Math.random() * 5000) + 100,
  };
}

// All POST actions in ClaimsController require [ValidateAntiForgeryToken],
// so any script that submits a form (Create, Upload, AddNote, ChangeStatus)
// must first GET the page, pull the token out of the hidden input the
// asp-action tag helper renders, and send it back as a form field. The
// antiforgery cookie itself rides along automatically via k6's cookie jar.
export function extractAntiForgeryToken(html) {
  const match = html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/);
  return match ? match[1] : null;
}

// Thin wrapper around k6's check() that applies a consistent tag/name so
// results are easy to filter across phases and scripts, e.g.:
//
//   const res = http.get(`${BASE_URL}/Claims`);
//   checkResponse(res, 200);
export function checkResponse(res, expectedStatus = 200) {
  return check(res, {
    [`status is ${expectedStatus}`]: (r) => r.status === expectedStatus,
  });
}
