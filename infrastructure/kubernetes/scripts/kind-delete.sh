#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-cavom-devsecops}"

command -v kind >/dev/null 2>&1 || {
  echo "kind is required" >&2
  exit 1
}

if ! kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' does not exist"
  exit 0
fi

kind delete cluster --name "${CLUSTER_NAME}"
