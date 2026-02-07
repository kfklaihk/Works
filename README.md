# Works
Programs developed and used in real projects

## Cloud Function (Gen2) deployment

If you deploy the `sql_mapping_runner` with a Cloud Storage trigger, the event
type does not expose an `object` attribute. To filter by object name, use the
`subject` attribute (which is `objects/<objectName>` for GCS events) with the
path-pattern filter.

Example:

gcloud functions deploy sql_mapping_runner \
  --gen2 \
  --runtime=python311 \
  --region=us-central1 \
  --source=. \
  --entry-point=gcs_mapping_handler \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=kevinlaiproject" \
  --trigger-event-filters-path-pattern="subject=objects/inputs/*.zip" \
  --max-instances=1 \
  --timeout=540 \
  --memory=2Gi \
  --cpu=1 \
  --set-env-vars="MAPPINGS_BLOB=inputs/mappings_all.json,OUTPUT_PREFIX=outputs,MAX_PASSES=6"

If you want to trigger on all objects in the bucket, drop the
`--trigger-event-filters-path-pattern` flag entirely.
