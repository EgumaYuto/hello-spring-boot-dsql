#!/usr/bin/env bash
#
# Tear down the Aurora DSQL + Lambda sandbox to stop any charges.
#
# Usage: ./scripts/teardown.sh
#
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_aws

log "Destroying Terraform stack (DSQL cluster, Lambda, Function URL, IAM)"
tf init -input=false >/dev/null
tf destroy -auto-approve -input=false -var "region=$REGION"

log "Teardown complete. All billable resources removed."
