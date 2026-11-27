#!/bin/sh
set -eu

cd "${BACKEND_DIR:-application/backend}"
# shellcheck disable=SC2086
mvn ${MAVEN_CLI_OPTS:-} -DskipTests package
