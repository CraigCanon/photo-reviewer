#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash ./scripts/reset-photo-states.sh
#
# Optional:
#   RESET_HISTORY=false bash ./scripts/reset-photo-states.sh
#     (keeps review/action history, only resets photo state)

AWS_REGION="${AWS_REGION:-us-east-1}"
RESET_HISTORY="${RESET_HISTORY:-true}"

PHOTOS_TABLE="$(terraform -chdir=terraform output -raw dynamodb_photos_table)"
REVIEWS_TABLE="$(terraform -chdir=terraform output -raw dynamodb_reviews_table)"
ACTION_TABLE="$(terraform -chdir=terraform output -raw dynamodb_action_log_table)"

echo "Region: $AWS_REGION"
echo "Photos table: $PHOTOS_TABLE"
echo "Reviews table: $REVIEWS_TABLE"
echo "Action table: $ACTION_TABLE"
echo "RESET_HISTORY=$RESET_HISTORY"
echo ""
read -r -p "Type RESET to continue: " CONFIRM
if [[ "$CONFIRM" != "RESET" ]]; then
  echo "Aborted."
  exit 1
fi

export AWS_REGION PHOTOS_TABLE REVIEWS_TABLE ACTION_TABLE RESET_HISTORY

python3 - <<'PY'
import os
import time
import boto3

region = os.environ.get("AWS_REGION", "us-east-1")
photos_table_name = os.environ["PHOTOS_TABLE"]
reviews_table_name = os.environ["REVIEWS_TABLE"]
action_table_name = os.environ["ACTION_TABLE"]
reset_history = os.environ.get("RESET_HISTORY", "true").lower() == "true"

dynamodb = boto3.resource("dynamodb", region_name=region)
photos_table = dynamodb.Table(photos_table_name)
reviews_table = dynamodb.Table(reviews_table_name)
action_table = dynamodb.Table(action_table_name)

now_ms = int(time.time() * 1000)


def scan_all_keys(table, key_name):
    items = []
    kwargs = {"ProjectionExpression": key_name}
    while True:
        resp = table.scan(**kwargs)
        items.extend(resp.get("Items", []))
        lek = resp.get("LastEvaluatedKey")
        if not lek:
            break
        kwargs["ExclusiveStartKey"] = lek
    return items


def reset_photos():
    photo_keys = scan_all_keys(photos_table, "photo_id")
    count = 0
    for item in photo_keys:
        photo_id = item["photo_id"]
        photos_table.update_item(
            Key={"photo_id": photo_id},
            UpdateExpression=(
                "SET current_state = :state, "
                "orientation_degrees = :orientation, "
                "updated_at = :updated_at "
                "REMOVE finalized_at, finalized_by_user_id"
            ),
            ExpressionAttributeValues={
                ":state": "Pending First Review",
                ":orientation": 0,
                ":updated_at": now_ms,
            },
        )
        count += 1
    return count


def clear_table(table, key_name):
    keys = scan_all_keys(table, key_name)
    with table.batch_writer() as batch:
        for item in keys:
            batch.delete_item(Key={key_name: item[key_name]})
    return len(keys)


photos_reset = reset_photos()
print(f"Reset photos: {photos_reset}")

if reset_history:
    reviews_deleted = clear_table(reviews_table, "review_id")
    actions_deleted = clear_table(action_table, "action_id")
    print(f"Deleted reviews: {reviews_deleted}")
    print(f"Deleted action logs: {actions_deleted}")
else:
    print("Kept review/action history (RESET_HISTORY=false).")

print("Done.")
PY
