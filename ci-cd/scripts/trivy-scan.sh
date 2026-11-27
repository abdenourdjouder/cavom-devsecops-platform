#!/bin/sh
set -eu

if [ "$#" -lt 3 ]; then
  printf 'Usage: %s fs|config|image TARGET REPORT_BASE [TRIVY_OPTIONS]\n' "$0" >&2
  exit 2
fi

scan_type=$1
target=$2
report_base=$3
shift 3

mkdir -p "$(dirname "$report_base")"

run() {
  format=$1
  output=$2
  gate=$3
  shift 3
  if [ "$target" = "__TRIVY_NO_TARGET__" ]; then
    trivy "$scan_type" "$@" \
      --format "$format" \
      --output "$output" \
      --exit-code "$gate"
  else
    trivy "$scan_type" "$@" \
      --format "$format" \
      --output "$output" \
      --exit-code "$gate" \
      "$target"
  fi
}

run json "${report_base}.json" 0 "$@"
run sarif "${report_base}.sarif" 0 "$@"
run table "${report_base}.txt" 1 "$@"
