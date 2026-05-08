#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PHOTO_ID="${1:-}"

PHOTOS_TABLE="$(terraform -chdir=terraform output -raw dynamodb_photos_table)"
REVIEWS_TABLE="$(terraform -chdir=terraform output -raw dynamodb_reviews_table)"
ACTION_TABLE="$(terraform -chdir=terraform output -raw dynamodb_action_log_table)"

echo "Using region: $AWS_REGION"
echo "Photos table: $PHOTOS_TABLE"
echo "Reviews table: $REVIEWS_TABLE"
echo "Action log table: $ACTION_TABLE"

echo ""
echo "Photo Counts By State"
echo "====================="

for STATE in "Pending First Review" "Pending Second Review" "Approved to Publish" "Rejected" "Finalized"; do
  COUNT=$(aws dynamodb query \
    --table-name "$PHOTOS_TABLE" \
    --index-name current_state-index \
    --key-condition-expression "current_state = :s" \
    --expression-attribute-values "{\":s\":{\"S\":\"$STATE\"}}" \
    --select COUNT \
    --region "$AWS_REGION" \
    --query Count \
    --output text)
  echo "$STATE: $COUNT"
done

echo ""
echo "Reviewed Photos (non-initial states)"
echo "===================================="

for STATE in "Pending Second Review" "Approved to Publish" "Rejected" "Finalized"; do
  echo ""
  echo "$STATE"
  aws dynamodb query \
    --table-name "$PHOTOS_TABLE" \
    --index-name current_state-index \
    --key-condition-expression "current_state = :s" \
    --expression-attribute-values "{\":s\":{\"S\":\"$STATE\"}}" \
    --region "$AWS_REGION" \
    --query "Items[].{photo_id:photo_id.S,state:current_state.S,updated_at:updated_at.N}" \
    --output table
done

if [[ -n "$PHOTO_ID" ]]; then
  echo ""
  echo "Details For Photo: $PHOTO_ID"
  echo "============================"

  echo ""
  echo "Current Photo Item"
  aws dynamodb get-item \
    --table-name "$PHOTOS_TABLE" \
    --key "{\"photo_id\":{\"S\":\"$PHOTO_ID\"}}" \
    --region "$AWS_REGION"

  echo ""
  echo "Review Events"
  aws dynamodb query \
    --table-name "$REVIEWS_TABLE" \
    --index-name photo_id-created_at-index \
    --key-condition-expression "photo_id = :p" \
    --expression-attribute-values "{\":p\":{\"S\":\"$PHOTO_ID\"}}" \
    --region "$AWS_REGION"

  echo ""
  echo "Action Log Events"
  aws dynamodb query \
    --table-name "$ACTION_TABLE" \
    --index-name photo_id-created_at-index \
    --key-condition-expression "photo_id = :p" \
    --expression-attribute-values "{\":p\":{\"S\":\"$PHOTO_ID\"}}" \
    --region "$AWS_REGION"
else
  echo ""
  echo "Tip: pass a photo id to inspect detailed history:"
  echo "  scripts/check-photo-status.sh <PHOTO_ID>"
fi
