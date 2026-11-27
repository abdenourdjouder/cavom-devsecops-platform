#!/bin/sh
set -eu

frontend_dir=${FRONTEND_DIR:-application/frontend}
backend_dir=${BACKEND_DIR:-application/backend}

for required in \
  "$frontend_dir/package.json" \
  "${FRONTEND_DOCKERFILE:-$frontend_dir/Dockerfile}" \
  "$backend_dir/pom.xml" \
  "${BACKEND_DOCKERFILE:-$backend_dir/Dockerfile}" \
  "${K8S_OVERLAY:-infrastructure/kubernetes}/kustomization.yaml"; do
  if [ ! -f "$required" ]; then
    printf 'Missing required project file: %s\n' "$required" >&2
    exit 1
  fi
done

case "${CI_COMMIT_REF_NAME:-}" in
  "")
    ;;
  *".."*|*"/"*"/.."*|*" "*) 
    printf 'Unsafe commit ref name: %s\n' "$CI_COMMIT_REF_NAME" >&2
    exit 1
    ;;
esac

printf 'Project structure validation passed.\n'
