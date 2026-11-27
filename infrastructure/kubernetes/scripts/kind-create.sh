#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-cavom-devsecops}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../kind-config.yaml"

command -v kind >/dev/null 2>&1 || {
  echo "kind is required" >&2
  exit 1
}

if kind get clusters | grep -Fxq "${CLUSTER_NAME}"; then
  echo "kind cluster '${CLUSTER_NAME}' already exists"
  exit 0
fi

kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG}"
