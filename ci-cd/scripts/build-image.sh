#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  printf 'Usage: %s CONTEXT DOCKERFILE IMAGE_NAME OUTPUT\n' "$0" >&2
  exit 2
fi

context=$1
dockerfile=$2
image=$3
output=$4

mkdir -p "$(dirname "$output")"
umask 022

buildctl-daemonless.sh build \
  --frontend dockerfile.v0 \
  --local "context=$context" \
  --local "dockerfile=$(dirname "$dockerfile")" \
  --opt "filename=$(basename "$dockerfile")" \
  --opt "build-arg=APP_VERSION=${CI_COMMIT_TAG:-$CI_COMMIT_SHORT_SHA}" \
  --opt "build-arg=VCS_REF=$CI_COMMIT_SHA" \
  --output "type=oci,name=$image,dest=$output" \
  --export-cache "type=inline"
