#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   PROJECT_ID=your-project \
#   REGION=us-central1 \
#   BUCKET=your-bucket \
#   MAPPINGS_BLOB=inputs/mappings.json \
#   OUTPUT_PREFIX=outputs \
#   MAX_PASSES=6 \
#   ./deploy.sh

PROJECT_ID="${PROJECT_ID:-}"
REGION="${REGION:-us-central1}"
BUCKET="${BUCKET:-}"
MAPPINGS_BLOB="${MAPPINGS_BLOB:-}"
OUTPUT_PREFIX="${OUTPUT_PREFIX:-outputs}"
MAX_PASSES="${MAX_PASSES:-6}"
PATH_PATTERN="${PATH_PATTERN:-inputs/*.zip}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "PROJECT_ID is required"
  exit 1
fi
if [[ -z "${BUCKET}" ]]; then
  echo "BUCKET is required"
  exit 1
fi
if [[ -z "${MAPPINGS_BLOB}" ]]; then
  echo "MAPPINGS_BLOB is required (e.g. inputs/mappings.json)"
  exit 1
fi

gcloud config set project "${PROJECT_ID}"

gcloud services enable \
  cloudfunctions.googleapis.com \
  cloudbuild.googleapis.com \
  eventarc.googleapis.com \
  storage.googleapis.com

gcloud functions deploy sql_mapping_runner \
  --gen2 \
  --runtime=python311 \
  --region="${REGION}" \
  --source=. \
  --entry-point=gcs_mapping_handler \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=${BUCKET}" \
  --trigger-event-filters-path-pattern="objectName=${PATH_PATTERN}" \
  --set-env-vars="MAPPINGS_BLOB=${MAPPINGS_BLOB},OUTPUT_PREFIX=${OUTPUT_PREFIX},MAX_PASSES=${MAX_PASSES}"

SA="${PROJECT_ID}@appspot.gserviceaccount.com"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SA}" \
  --role="roles/storage.objectAdmin"

echo "Deployed. Upload a SQL ZIP to gs://${BUCKET}/ to trigger."
