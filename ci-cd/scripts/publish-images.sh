#!/bin/sh
set -eu

: "${CI_REGISTRY:?CI_REGISTRY is required by the GitLab runner}"
: "${CI_REGISTRY_USER:?CI_REGISTRY_USER is required by the GitLab runner}"
: "${CI_JOB_TOKEN:?CI_JOB_TOKEN is required by the GitLab runner}"

umask 077
mkdir -p "$(dirname "$SKOPEO_AUTH_FILE")"
printf '%s' "$CI_JOB_TOKEN" | skopeo login \
  --username "$CI_REGISTRY_USER" \
  --password-stdin \
  --authfile "$SKOPEO_AUTH_FILE" \
  "$CI_REGISTRY"

cleanup() {
  rm -f "$SKOPEO_AUTH_FILE"
}
trap cleanup EXIT HUP INT TERM

tag=${CI_COMMIT_TAG:-$CI_COMMIT_SHORT_SHA}
for component in frontend backend; do
  archive=".oci/$component.tar"
  [ -f "$archive" ] || {
    printf 'Missing scanned image archive: %s\n' "$archive" >&2
    exit 1
  }
done

skopeo copy --authfile "$SKOPEO_AUTH_FILE" \
  oci-archive:.oci/frontend.tar \
  "docker://${FRONTEND_IMAGE:-$CI_REGISTRY_IMAGE/frontend}:$tag"
skopeo copy --authfile "$SKOPEO_AUTH_FILE" \
  oci-archive:.oci/backend.tar \
  "docker://${BACKEND_IMAGE:-$CI_REGISTRY_IMAGE/backend}:$tag"

if [ -n "${CI_DEFAULT_BRANCH:-}" ] && [ "${CI_COMMIT_BRANCH:-}" = "$CI_DEFAULT_BRANCH" ]; then
  skopeo copy --authfile "$SKOPEO_AUTH_FILE" \
    oci-archive:.oci/frontend.tar \
    "docker://${FRONTEND_IMAGE:-$CI_REGISTRY_IMAGE/frontend}:latest"
  skopeo copy --authfile "$SKOPEO_AUTH_FILE" \
    oci-archive:.oci/backend.tar \
    "docker://${BACKEND_IMAGE:-$CI_REGISTRY_IMAGE/backend}:latest"
fi
