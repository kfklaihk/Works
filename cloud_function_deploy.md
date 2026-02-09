# Google Cloud Functions (GCS Trigger) Deployment

This guide deploys the SQL mapping analyzer as a GCS-triggered Cloud Function.

## Prerequisites
- `gcloud` CLI installed and authenticated
- A Google Cloud project

## Files in this repo
- `main.py` (Cloud Function entrypoint)
- `parse_mappings_colab_10.py` (logic)
- `requirements.txt` (dependencies)
- `deploy.sh` (automated deployment)

## 1) Create a bucket
```bash
gsutil mb -l us-central1 gs://YOUR_BUCKET_NAME
```

## 2) Prepare inputs
Upload a SQL ZIP and a mappings file:
```bash
gsutil cp mappings.json gs://YOUR_BUCKET_NAME/inputs/mappings.json
gsutil cp sql_files.zip gs://YOUR_BUCKET_NAME/inputs/sql_files.zip
```

## 3) Deploy
```bash
PROJECT_ID=your-project \
REGION=us-central1 \
BUCKET=YOUR_BUCKET_NAME \
MAPPINGS_BLOB=inputs/mappings.json \
OUTPUT_PREFIX=outputs \
MAX_PASSES=6 \
PATH_PATTERN=inputs/*.zip \
./deploy.sh
```

## 4) Trigger
Upload a ZIP to the bucket:
```bash
gsutil cp sql_files.zip gs://YOUR_BUCKET_NAME/inputs/sql_files.zip
```

## 5) Output
Results are written to:
```
gs://YOUR_BUCKET_NAME/outputs/<zip_basename>_mapping_results.csv
```

## Optional environment variables
- `MAPPINGS_BLOB`: path to mappings JSON in the bucket
- `OUTPUT_PREFIX`: prefix for output CSV objects (default `outputs`)
- `OUTPUT_BUCKET`: override output bucket
- `MAX_PASSES`: per-file parse passes (default `6`)
- `PATH_PATTERN`: GCS object name glob for triggers (default `inputs/*.zip`)
- `FORCE_RUN`: set to `true` to bypass idempotency checks

## Idempotency
The function skips processing if the output CSV already exists **for the same input
generation**. This avoids duplicate work when Eventarc delivers duplicate events.
To force reprocessing, set `FORCE_RUN=true` or delete the existing output file.
