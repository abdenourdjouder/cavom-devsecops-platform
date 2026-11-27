#!/bin/sh
set -eu

: "${KUBE_CONFIG_BASE64:?KUBE_CONFIG_BASE64 must be a protected environment variable}"
: "${K8S_OVERLAY:?K8S_OVERLAY must select a reviewed Kubernetes overlay}"

case "$K8S_OVERLAY" in
  infrastructure/kubernetes) ;;
  *)
    printf 'K8S_OVERLAY must be the reviewed infrastructure/kubernetes tree.\n' >&2
    exit 1
    ;;
esac

umask 077
mkdir -p "$(dirname "$KUBECONFIG")"
printf '%s' "$KUBE_CONFIG_BASE64" | base64 -d > "$KUBECONFIG"
chmod 600 "$KUBECONFIG"

cleanup() {
  rm -f "$KUBECONFIG"
  rmdir "$(dirname "$KUBECONFIG")" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

kubectl config current-context
kubectl apply -k "$K8S_OVERLAY"

tag=${CI_COMMIT_TAG:-$CI_COMMIT_SHORT_SHA}
: "${FRONTEND_DEPLOYMENT:?FRONTEND_DEPLOYMENT must be set}"
: "${FRONTEND_CONTAINER:?FRONTEND_CONTAINER must be set}"
: "${FRONTEND_NAMESPACE:?FRONTEND_NAMESPACE must be set}"
: "${BACKEND_DEPLOYMENT:?BACKEND_DEPLOYMENT must be set}"
: "${BACKEND_CONTAINER:?BACKEND_CONTAINER must be set}"
: "${BACKEND_NAMESPACE:?BACKEND_NAMESPACE must be set}"

kubectl -n "$FRONTEND_NAMESPACE" set image "deployment/$FRONTEND_DEPLOYMENT" \
  "$FRONTEND_CONTAINER=${FRONTEND_IMAGE:-$CI_REGISTRY_IMAGE/frontend}:$tag"
kubectl -n "$BACKEND_NAMESPACE" set image "deployment/$BACKEND_DEPLOYMENT" \
  "$BACKEND_CONTAINER=${BACKEND_IMAGE:-$CI_REGISTRY_IMAGE/backend}:$tag"
kubectl -n "$FRONTEND_NAMESPACE" rollout status \
  "deployment/$FRONTEND_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT:-5m}"
kubectl -n "$BACKEND_NAMESPACE" rollout status \
  "deployment/$BACKEND_DEPLOYMENT" --timeout="${ROLLOUT_TIMEOUT:-5m}"
