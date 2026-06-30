# LegacyModernisation

A worked example of how to modernise and scale a legacy .NET application: a single-VM ASP.NET Core + SQL Server app, taken through seven checkpointed phases to a multi-region, horizontally scalable Azure PaaS architecture — extracting single points of failure, moving into PaaS, extracting file storage to Blob Storage, moving session to Redis, upgrading the database to a Managed Instance, and finally going multi-region.

- [`src/ClaimsCaseManagement`](src/ClaimsCaseManagement) — the application
- [`docs/MODERNIZATION-JOURNEY.md`](docs/MODERNIZATION-JOURNEY.md) — the phase-by-phase narrative and checkpoint tags
- [`docs/RUNBOOK.md`](docs/RUNBOOK.md) — how to deploy, load-test, and tear down each phase
- `infra/phase-N-*` — Terraform for each phase's environment, plus `deploy.sh`/`teardown.sh`
- `loadtest/phase-N-*` — k6 load tests that push each phase to the point of failure
