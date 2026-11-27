#!/bin/sh
set -eu

ci-cd/scripts/trivy-scan.sh config . security/reports/config \
  --ignorefile security/trivy/.trivyignore \
  --config security/trivy/trivy.yaml \
  --severity HIGH,CRITICAL
