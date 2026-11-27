#!/bin/sh
set -eu

ci-cd/scripts/trivy-scan.sh fs . security/reports/filesystem \
  --ignorefile security/trivy/.trivyignore \
  --scanners vuln,secret,misconfig \
  --config security/trivy/trivy.yaml \
  --severity HIGH,CRITICAL
