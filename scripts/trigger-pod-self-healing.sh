#!/usr/bin/env bash
set -euo pipefail

POD_NAME="$(kubectl -n incident-lab get pod -l app.kubernetes.io/name=podinfo -o jsonpath='{.items[0].metadata.name}')"

if [ -z "${POD_NAME}" ]; then
  echo "No podinfo pod found."
  exit 1
fi

kubectl -n incident-lab delete pod "${POD_NAME}"
echo "Deleted ${POD_NAME}. Watch recovery with: kubectl -n incident-lab get pods -w"
