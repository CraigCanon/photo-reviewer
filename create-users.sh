#!/usr/bin/env bash
set -euo pipefail

# Run from repo root. Requires: aws CLI, terraform, jq
# Usage:
#   ADMIN_EMAIL="admin@example.com" ADMIN_NAME="Admin User" \
#   REVIEWER1_EMAIL="rev1@example.com" REVIEWER1_NAME="Reviewer One" \
#   REVIEWER2_EMAIL="rev2@example.com" REVIEWER2_NAME="Reviewer Two" \
#   ./create-users.sh
#
# Optional:
#   SET_PERMANENT_PASSWORD=true PERMANENT_PASSWORD='StrongPassw0rd!' ./create-users.sh

AWS_REGION="${AWS_REGION:-us-east-1}"
SET_PERMANENT_PASSWORD="${SET_PERMANENT_PASSWORD:-false}"
PERMANENT_PASSWORD="${PERMANENT_PASSWORD:-}"

: "${ADMIN_EMAIL:?Set ADMIN_EMAIL}"
: "${ADMIN_NAME:?Set ADMIN_NAME}"
: "${REVIEWER1_EMAIL:?Set REVIEWER1_EMAIL}"
: "${REVIEWER1_NAME:?Set REVIEWER1_NAME}"
: "${REVIEWER2_EMAIL:?Set REVIEWER2_EMAIL}"
: "${REVIEWER2_NAME:?Set REVIEWER2_NAME}"

if [[ "$SET_PERMANENT_PASSWORD" == "true" && -z "$PERMANENT_PASSWORD" ]]; then
  echo "ERROR: SET_PERMANENT_PASSWORD=true requires PERMANENT_PASSWORD"
  exit 1
fi

USER_POOL_ID="$(terraform -chdir=terraform output -raw cognito_user_pool_id)"

echo "Using USER_POOL_ID: $USER_POOL_ID"
echo "Region: $AWS_REGION"

create_user() {
  local email="$1"
  local name="$2"
  local group="$3"

  echo ""
  echo "Creating user: $email ($group)"

  if aws cognito-idp admin-get-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$email" \
      --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "User already exists, skipping create: $email"
  else
    aws cognito-idp admin-create-user \
      --user-pool-id "$USER_POOL_ID" \
      --username "$email" \
      --user-attributes \
        Name=email,Value="$email" \
        Name=email_verified,Value=true \
        Name=name,Value="$name" \
      --desired-delivery-mediums EMAIL \
      --region "$AWS_REGION" >/dev/null
    echo "Created: $email"
  fi

  aws cognito-idp admin-add-user-to-group \
    --user-pool-id "$USER_POOL_ID" \
    --username "$email" \
    --group-name "$group" \
    --region "$AWS_REGION" >/dev/null || true
  echo "Ensured group membership: $email -> $group"

  if [[ "$SET_PERMANENT_PASSWORD" == "true" ]]; then
    aws cognito-idp admin-set-user-password \
      --user-pool-id "$USER_POOL_ID" \
      --username "$email" \
      --password "$PERMANENT_PASSWORD" \
      --permanent \
      --region "$AWS_REGION" >/dev/null
    echo "Set permanent password for: $email"
  fi

  echo "Groups for $email:"
  aws cognito-idp admin-list-groups-for-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$email" \
    --region "$AWS_REGION" \
    --query "Groups[].GroupName" \
    --output text
}

create_user "$ADMIN_EMAIL" "$ADMIN_NAME" "admins"
create_user "$REVIEWER1_EMAIL" "$REVIEWER1_NAME" "reviewers"
create_user "$REVIEWER2_EMAIL" "$REVIEWER2_NAME" "reviewers"

echo ""
echo "Done. Users created/updated:"
echo "  admin:     $ADMIN_EMAIL"
echo "  reviewer1: $REVIEWER1_EMAIL"
echo "  reviewer2: $REVIEWER2_EMAIL"
