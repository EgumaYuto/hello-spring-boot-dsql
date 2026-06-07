#!/usr/bin/env bash
#
# Deploy the Aurora DSQL + Lambda sandbox in one command:
#   build Lambda zip -> terraform apply (DSQL cluster, Lambda, Function URL, IAM)
#
# Aurora DSQL is serverless (scales to zero) and Lambda is pay-per-request, so
# there is NO VPC / NAT / ALB and idle cost is ~$0.
#
# Prerequisites:
#   - AWS profile valid (override with AWS_PROFILE=...), region supports DSQL
#   - Java 17 (the Gradle build uses the wrapper)
#
# Usage: ./scripts/deploy.sh
#
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

require_aws

# 1. build the Lambda deployment package (classes at root, deps under lib/)
log "Building Lambda deployment package"
( cd "$ROOT" && ./gradlew lambdaZip --console=plain )

# 2. apply the infrastructure (DSQL cluster + Lambda + Function URL + IAM)
log "Applying Terraform (region: $REGION)"
tf init -input=false >/dev/null
tf apply -auto-approve -input=false -var "region=$REGION"

URL="$(tf output -raw function_url)"
log "Deployed."
echo "    curl ${URL}        # -> Hello World!"
echo "    curl ${URL}user    # -> [] (reads the Aurora DSQL users table)"
echo
echo "Note: the first request is a cold start (JVM + Spring Boot + Flyway migrate)"
echo "      and may take several seconds."
