#!/bin/sh
set -eu

if [ "$#" -ne 2 ]; then
  printf 'Usage: %s OCI_ARCHIVE REPORT_PREFIX\n' "$0" >&2
  exit 2
fi

archive=$1
prefix=$2

[ -f "$archive" ] || {
  printf 'Missing image archive: %s\n' "$archive" >&2
  exit 1
}

trivy image \
  --input "$archive" \
  --format cyclonedx \
  --output "security/reports/${prefix}-sbom.cdx.json" \
  --config security/trivy/trivy.yaml

ci-cd/scripts/trivy-scan.sh image "__TRIVY_NO_TARGET__" "security/reports/${prefix}-image" \
  --input "$archive" \
  --ignorefile security/trivy/.trivyignore \
  --scanners vuln,secret,misconfig \
  --config security/trivy/trivy.yaml \
  --severity HIGH,CRITICAL
