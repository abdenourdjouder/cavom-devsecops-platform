#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="${SCRIPT_DIR}/.."
CLUSTER_NAME="${KIND_CLUSTER_NAME:-cavom-devsecops}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-${CLUSTER_NAME}}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-registry.gitlab.com/cavom/platform/frontend:latest}"
BACKEND_IMAGE="${BACKEND_IMAGE:-registry.gitlab.com/cavom/platform/backend:latest}"
ROLLOUT_TIMEOUT="${ROLLOUT_TIMEOUT:-5m}"

command -v kubectl >/dev/null 2>&1 || {
  echo "kubectl is required" >&2
  exit 1
}

kubectl --context "${KUBE_CONTEXT}" apply -k "${MANIFEST_DIR}"
kubectl --context "${KUBE_CONTEXT}" -n cavom-frontend set image deployment/frontend "frontend=${FRONTEND_IMAGE}"
kubectl --context "${KUBE_CONTEXT}" -n cavom-backend set image deployment/backend "backend=${BACKEND_IMAGE}"

kubectl --context "${KUBE_CONTEXT}" -n cavom-database rollout status statefulset/mysql --timeout="${ROLLOUT_TIMEOUT}"
kubectl --context "${KUBE_CONTEXT}" -n cavom-backend rollout status deployment/backend --timeout="${ROLLOUT_TIMEOUT}"
kubectl --context "${KUBE_CONTEXT}" -n cavom-frontend rollout status deployment/frontend --timeout="${ROLLOUT_TIMEOUT}"

echo "Frontend: http://127.0.0.1:30080"
