#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-cavom-devsecops}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-registry.gitlab.com/cavom/platform/frontend:1.0.0}"
BACKEND_IMAGE="${BACKEND_IMAGE:-registry.gitlab.com/cavom/platform/backend:1.0.0}"

command -v kind >/dev/null 2>&1 || {
  echo "kind is required" >&2
  exit 1
}
command -v docker >/dev/null 2>&1 || {
  echo "docker is required" >&2
  exit 1
}

kind get clusters | grep -Fxq "${CLUSTER_NAME}" || {
  echo "kind cluster '${CLUSTER_NAME}' does not exist" >&2
  exit 1
}

docker image inspect "${FRONTEND_IMAGE}" >/dev/null
docker image inspect "${BACKEND_IMAGE}" >/dev/null
kind load docker-image --name "${CLUSTER_NAME}" "${FRONTEND_IMAGE}" "${BACKEND_IMAGE}"
