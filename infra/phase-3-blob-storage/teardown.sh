#!/usr/bin/env bash
# Tears down everything in this phase's resource group. Scoped entirely to
# this phase's Terraform state -- does not touch any other phase.
set -euo pipefail
cd "$(dirname "$0")"

AUTO_APPROVE=""
if [[ "${1:-}" == "--yes" ]]; then
  AUTO_APPROVE="-auto-approve"
fi

terraform destroy ${AUTO_APPROVE}
