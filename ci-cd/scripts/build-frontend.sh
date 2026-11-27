#!/bin/sh
set -eu

cd "${FRONTEND_DIR:-application/frontend}"
if [ -f package-lock.json ]; then
  npm ci --ignore-scripts --no-audit --no-fund
else
  npm install --ignore-scripts --no-audit --no-fund
fi
npm run build
