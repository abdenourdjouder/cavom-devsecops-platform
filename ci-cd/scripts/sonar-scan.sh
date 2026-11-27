#!/bin/sh
set -eu

: "${SONAR_HOST_URL:?SONAR_HOST_URL must be configured}"
: "${SONAR_TOKEN:?SONAR_TOKEN must be configured as a masked/protected variable}"

project_key=${SONAR_PROJECT_KEY:-"$CI_PROJECT_PATH_SLUG"}
mkdir -p .sonar

sonar-scanner \
  -Dsonar.host.url="$SONAR_HOST_URL" \
  -Dsonar.token="$SONAR_TOKEN" \
  -Dsonar.projectKey="$project_key" \
  -Dsonar.projectName="${SONAR_PROJECT_NAME:-$CI_PROJECT_TITLE}" \
  -Dsonar.projectVersion="${CI_COMMIT_TAG:-$CI_COMMIT_SHORT_SHA}" \
  -Dsonar.sources="${SONAR_SOURCES:-application/frontend/src,application/backend/src/main}" \
  -Dsonar.tests="${SONAR_TESTS:-application/frontend/src,application/backend/src/test}" \
  -Dsonar.test.inclusions="**/*.test.js,**/*.test.jsx,**/*Test.java" \
  -Dsonar.exclusions="**/*.test.js,**/*.test.jsx" \
  -Dsonar.java.binaries="application/backend/target/classes" \
  -Dsonar.junit.reportPaths="application/backend/target/surefire-reports" \
  -Dsonar.qualitygate.wait=true \
  -Dsonar.qualitygate.timeout="${SONAR_QUALITY_GATE_TIMEOUT_SECONDS:-600}"

printf 'Sonar Quality Gate passed for %s.\n' "$project_key" > .sonar/quality-gate.txt
